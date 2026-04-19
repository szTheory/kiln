defmodule Kiln.BootChecks do
  @moduledoc """
  Boot-time invariant assertions (D-32, D-33 — CONTEXT.md). Raises
  `Kiln.BootChecks.Error` on any violation, terminating the BEAM with a
  readable, operator-friendly message. Invoked from
  `Kiln.Application.start/2` AFTER `Repo` + `Oban` come up but BEFORE
  `KilnWeb.Endpoint` starts so a failing invariant never results in a
  half-up factory (the endpoint never binds — the probe URL simply
  refuses connection, which is the correct signal for "dead factory").

  Invariants asserted (each has a dedicated `check_*!/0` private fn):

    * `:contexts_compiled`    — all 12 `Kiln.*` context modules load
      via `Code.ensure_compiled?/1`. Catches a rename/typo that passed
      `mix compile` because a broken module was never referenced.
    * `:audit_revoke_active`  — `kiln_app` role cannot UPDATE
      `audit_events` (attempted UPDATE raises SQLSTATE 42501 —
      `:insufficient_privilege`). Proves Layer 1 of D-12.
    * `:audit_trigger_active` — UPDATE `audit_events` as `kiln_owner`
      raises with the literal message `"audit_events is append-only"`.
      Proves Layer 2 of D-12 (role-bypass-resistant).
    * `:required_secrets`     — `SECRET_KEY_BASE` + `DATABASE_URL`
      present in `:prod`; `DATABASE_URL` present in `:dev`. No-op in
      `:test` (sandboxed config provides stand-ins).

  Escape hatch: `KILN_SKIP_BOOTCHECKS=1` returns `:ok` immediately AND
  emits a loud error-level log line naming the env var (D-33). Use only
  for emergency debugging — never in production.
  """

  require Logger
  alias Kiln.BootChecks.Error
  alias Kiln.Repo

  # SSOT for the 12 bounded contexts (ARCHITECTURE.md §4). Must match the
  # `:contexts` count in `Kiln.HealthPlug.status/0`. `ExternalOperations`
  # is the 12th — a P1 artifact per CONTEXT.md `<domain>`; downstream
  # phases will add `Scope` usage but not expand this list.
  @context_modules [
    Kiln.Specs,
    Kiln.Intents,
    Kiln.Workflows,
    Kiln.Runs,
    Kiln.Stages,
    Kiln.Agents,
    Kiln.Sandboxes,
    Kiln.GitHub,
    Kiln.Audit,
    Kiln.Telemetry,
    Kiln.Policies,
    Kiln.ExternalOperations
  ]

  @doc """
  Returns the expected P1 count of bounded-context modules (12 per
  ARCHITECTURE.md §4 / D-42). `Kiln.HealthPlug` calls this so
  `/health`'s `"contexts"` field stays in sync with the invariant list
  automatically.
  """
  @spec context_count() :: non_neg_integer()
  def context_count, do: length(@context_modules)

  @typedoc "The 12 bounded-context modules pinned by D-42."
  @type context_module ::
          Kiln.Specs
          | Kiln.Intents
          | Kiln.Workflows
          | Kiln.Runs
          | Kiln.Stages
          | Kiln.Agents
          | Kiln.Sandboxes
          | Kiln.GitHub
          | Kiln.Audit
          | Kiln.Telemetry
          | Kiln.Policies
          | Kiln.ExternalOperations

  @doc """
  Returns the P1 context module list. Exposed for
  `test/kiln/boot_checks_test.exs` behavior-18 assertion; prefer
  `context_count/0` in production code.
  """
  @spec context_modules() :: [context_module(), ...]
  def context_modules, do: @context_modules

  @doc """
  Runs every boot-time invariant. Returns `:ok` on full success;
  raises `Kiln.BootChecks.Error` on any violation so
  `Kiln.Application.start/2` returns `{:error, _}` and the BEAM exits
  with the message printed.

  `KILN_SKIP_BOOTCHECKS=1` bypasses all checks (D-33). This should
  never be set in production — the log line emitted when it IS set is
  meant to be grep-able so operators notice immediately.
  """
  @spec run!() :: :ok | no_return()
  def run! do
    if System.get_env("KILN_SKIP_BOOTCHECKS") == "1" do
      Logger.error(
        "KILN_SKIP_BOOTCHECKS=1 — boot checks BYPASSED. Only use for emergency debugging. See D-33."
      )

      :ok
    else
      check_contexts_compiled!()
      check_audit_revoke_active!()
      check_audit_trigger_active!()
      check_required_secrets!()
      :ok
    end
  end

  # -----------------------------------------------------------------
  # Invariant: :contexts_compiled
  # -----------------------------------------------------------------
  defp check_contexts_compiled! do
    # `Code.ensure_compiled/1` returns `{:module, mod}` on success and an
    # `{:error, reason}` tuple (`:nofile`, `:unavailable`, etc.) on
    # failure; anything not matching `{:module, _}` is a missing context.
    missing =
      @context_modules
      |> Enum.reject(&match?({:module, _}, Code.ensure_compiled(&1)))

    case missing do
      [] ->
        :ok

      mods ->
        raise Error,
          invariant: :contexts_compiled,
          details: %{missing_modules: mods, expected_count: length(@context_modules)},
          remediation_hint:
            "One or more Kiln.* context modules did not compile. Run `mix compile` and " <>
              "confirm each appears under lib/kiln/. Missing: #{inspect(mods)}."
    end
  end

  # -----------------------------------------------------------------
  # Invariant: :audit_revoke_active (Layer 1 of D-12)
  # -----------------------------------------------------------------
  #
  # Attempts `UPDATE audit_events ... WHERE FALSE` as kiln_app and
  # expects Postgrex.Error{postgres: %{code: :insufficient_privilege}}
  # (SQLSTATE 42501). `WHERE FALSE` means zero rows match — the
  # privilege check runs before predicate evaluation, so the error
  # fires regardless of table contents.
  defp check_audit_revoke_active! do
    # Use a session-level `SET ROLE` (not `SET LOCAL` — that needs an
    # explicit transaction) inside a `Repo.checkout/1` block so the
    # probe uses a single pinned connection. The failing UPDATE is
    # OUTSIDE any transaction, so Postgres returns the permission
    # error as a single-statement failure without poisoning a tx.
    # `RESET ROLE` in the `after` clause guarantees the pool connection
    # isn't returned with a non-default role set (would leak into the
    # next checkout).
    outcome = probe_audit_mutation("kiln_app", :revoke_classifier)

    case outcome do
      :revoke_active ->
        :ok

      :no_error_raised ->
        raise Error,
          invariant: :audit_revoke_active,
          details: %{hint: "kiln_app role has UPDATE privilege on audit_events"},
          remediation_hint:
            "Run: KILN_DB_ROLE=kiln_owner mix ecto.migrate ; or execute: " <>
              "REVOKE UPDATE, DELETE, TRUNCATE ON audit_events FROM kiln_app;"

      {:unexpected_postgres_code, code} ->
        raise Error,
          invariant: :audit_revoke_active,
          details: %{unexpected_code: code},
          remediation_hint:
            "Probe raised unexpected SQLSTATE #{inspect(code)} (expected :insufficient_privilege). " <>
              "Inspect role grants with: \\dp audit_events in psql."

      {:probe_failed, reason} ->
        raise Error,
          invariant: :audit_revoke_active,
          details: %{probe_error: reason},
          remediation_hint: "Unable to open probe connection. Check Repo connectivity."
    end
  end

  # -----------------------------------------------------------------
  # Invariant: :audit_trigger_active (Layer 2 of D-12)
  # -----------------------------------------------------------------
  #
  # Attempts UPDATE as kiln_owner (which has the privilege) — the
  # BEFORE-UPDATE trigger must still fire with the literal
  # "audit_events is append-only" message. This catches the drift case
  # where a future migration accidentally drops/renames the trigger
  # while leaving the REVOKE intact.
  defp check_audit_trigger_active! do
    # Same non-transactional pattern as :audit_revoke_active. See
    # `probe_audit_mutation/2` for the RESET-ROLE + connection-pinning
    # details.
    outcome = probe_audit_mutation("kiln_owner", :trigger_classifier)

    case outcome do
      :trigger_active ->
        :ok

      :no_error_raised ->
        raise Error,
          invariant: :audit_trigger_active,
          details: %{hint: "BEFORE UPDATE trigger audit_events_no_update did not fire"},
          remediation_hint:
            "Run: KILN_DB_ROLE=kiln_owner mix ecto.migrate (re-applies migration 20260418000004); " <>
              "or manually: CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON " <>
              "audit_events FOR EACH ROW EXECUTE FUNCTION audit_events_immutable();"

      {:unexpected_message, msg} ->
        raise Error,
          invariant: :audit_trigger_active,
          details: %{unexpected_message: msg},
          remediation_hint:
            "Trigger fired with an unexpected message. Check pg_trigger + function " <>
              "audit_events_immutable() body — expected substring 'audit_events is append-only'."

      {:probe_failed, reason} ->
        raise Error,
          invariant: :audit_trigger_active,
          details: %{probe_error: reason},
          remediation_hint: "Unable to open probe connection."
    end
  end

  # Shared probe for the two Layer-1/Layer-2 audit invariants.
  #
  # Why the SAVEPOINT-and-rollback pattern: A BEFORE UPDATE trigger only
  # fires when at least one row matches, so the probe MUST operate on a
  # real row (not `WHERE FALSE`). The rollback chain guarantees zero
  # trace in audit_events:
  #
  #   * UPDATE raising (the success case) leaves the subtxn in ABORT
  #     state — the inner `ROLLBACK TO SAVEPOINT probe` restores the
  #     txn to a runnable state so we can exit the outer
  #     `Repo.transaction` cleanly.
  #   * UPDATE succeeding (the invariant-broken case) means the D-12
  #     layers leaked a mutation. We roll back the outer txn too via
  #     `Repo.rollback(outcome)` so the spurious row never lands.
  #
  # The OUTER `Repo.transaction` is required because `SET LOCAL ROLE`
  # only takes effect inside a transaction; nesting it as a SAVEPOINT
  # inside the test sandbox's existing txn is how the same code path
  # works both in boot (fresh connection) and in tests (sandboxed).
  @spec probe_audit_mutation(String.t(), :revoke_classifier | :trigger_classifier) ::
          :revoke_active
          | :trigger_active
          | :no_error_raised
          | {:unexpected_postgres_code, term()}
          | {:unexpected_message, String.t()}
          | {:probe_failed, term()}
  defp probe_audit_mutation(role, classifier) do
    result =
      Repo.transaction(fn ->
        Repo.query!("SET LOCAL ROLE #{role}")
        Repo.query!("SAVEPOINT probe")

        outcome =
          try do
            Repo.query!(
              """
              INSERT INTO audit_events
                (event_kind, correlation_id, schema_version, payload, actor_id, inserted_at)
              VALUES
                ('stage_started', $1::uuid, 1,
                 '{"stage_kind":"coding","attempt":1}'::jsonb,
                 'probe', now())
              """,
              [Ecto.UUID.dump!(Ecto.UUID.generate())]
            )

            Repo.query!(
              "UPDATE audit_events SET actor_id = 'probe-update' WHERE actor_id = 'probe'",
              []
            )

            # UPDATE succeeded ⇒ invariant is broken. Release the
            # savepoint so the outer txn can still clean up, but
            # before that record that the INSERT+UPDATE pair leaked
            # a row — we'll roll back the outer txn via rollback/1.
            Repo.query!("ROLLBACK TO SAVEPOINT probe")
            :no_error_raised
          rescue
            e in Postgrex.Error ->
              # The UPDATE (or INSERT — shouldn't happen, kiln_app has
              # INSERT) raised and Postgres put the current subtxn in
              # ABORT state. ROLLBACK TO SAVEPOINT undoes that and
              # restores the txn to a runnable state so we can exit
              # the outer Repo.transaction cleanly via rollback/1.
              Repo.query!("ROLLBACK TO SAVEPOINT probe")
              classify(classifier, e)
          end

        # Always roll back the outer txn too — the probe is idempotent
        # by design and must leave zero trace in audit_events even
        # when Layer 1/Layer 2 allowed the UPDATE to succeed.
        Repo.rollback(outcome)
      end)

    case result do
      {:error, outcome} -> outcome
      other -> {:probe_failed, other}
    end
  rescue
    e -> {:probe_failed, Exception.message(e)}
  end

  defp classify(:revoke_classifier, %Postgrex.Error{postgres: %{code: code}}) do
    case code do
      :insufficient_privilege -> :revoke_active
      other -> {:unexpected_postgres_code, other}
    end
  end

  defp classify(:trigger_classifier, %Postgrex.Error{postgres: %{message: msg}}) do
    if msg =~ "audit_events is append-only" do
      :trigger_active
    else
      {:unexpected_message, msg}
    end
  end

  # -----------------------------------------------------------------
  # Invariant: :required_secrets
  # -----------------------------------------------------------------
  #
  # In :prod: SECRET_KEY_BASE + DATABASE_URL must be set. In :dev: only
  # DATABASE_URL (SECRET_KEY_BASE is baked into config/dev.exs for the
  # dev loop). In :test: no-op (sandboxed config provides stand-ins).
  defp check_required_secrets! do
    env = Application.get_env(:kiln, :env, :prod)

    required =
      case env do
        :prod -> [{"SECRET_KEY_BASE", :secret_key_base}, {"DATABASE_URL", :database_url}]
        :dev -> [{"DATABASE_URL", :database_url}]
        _ -> []
      end

    missing =
      required
      |> Enum.reject(fn {var, _k} -> System.get_env(var) not in [nil, ""] end)
      |> Enum.map(&elem(&1, 0))

    case missing do
      [] ->
        :ok

      vars ->
        raise Error,
          invariant: :required_secrets,
          details: %{missing_env_vars: vars, env: env},
          remediation_hint:
            "Set #{Enum.join(vars, ", ")} before booting " <>
              "(cp .env.sample .env and edit; direnv allow; re-run mix phx.server)."
    end
  end
end
