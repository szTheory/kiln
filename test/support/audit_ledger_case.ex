defmodule Kiln.AuditLedgerCase do
  @moduledoc """
  ExUnit case template for tests that exercise the three-layer
  `audit_events` immutability invariant (D-12).

  Each assertion needs a specific role context:

    * AUD-01 (REVOKE, Layer 1) — execute UPDATE/DELETE as kiln_app; expect
      SQLSTATE 42501 (`:insufficient_privilege`).
    * AUD-02 (trigger, Layer 2) — execute UPDATE as kiln_owner (privileged);
      expect the trigger to `RAISE EXCEPTION` with message containing
      `"audit_events is append-only"`.
    * AUD-03 (RULE, Layer 3) — disable the trigger, execute UPDATE as
      kiln_owner; expect `%Postgrex.Result{num_rows: 0}` (the RULE
      rewrites to DO INSTEAD NOTHING) and the row unchanged.

  Because Ecto's sandbox may share connections across tests, role
  switching uses `SET LOCAL ROLE <role>` inside the sandbox transaction
  (Postgres automatically resets the role at transaction end). The
  connecting user (default `kiln` superuser in dev/test) was granted
  membership in both roles by migration 20260418000002, so
  `SET LOCAL ROLE` succeeds without re-authentication.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Kiln.Repo

  using do
    quote do
      alias Kiln.Repo

      import Kiln.AuditLedgerCase
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(Kiln.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  Runs `fun` with the DB session role set to `role`, then resets.

  `SET LOCAL ROLE` is confined to the enclosing transaction — the sandbox
  wraps every test in a transaction, so the role automatically resets at
  test end even if `fun` raises.
  """
  @spec with_role(String.t(), (-> term())) :: term()
  def with_role(role, fun) when role in ["kiln_app", "kiln_owner", "kiln_verifier"] do
    Repo.query!("SET LOCAL ROLE #{role}")

    try do
      fun.()
    after
      Repo.query!("RESET ROLE")
    end
  end

  @doc """
  Inserts a minimal valid audit_event via `Kiln.Audit.append/1` and
  returns the inserted `Kiln.Audit.Event` for tests that need a target
  row for UPDATE/DELETE attempts.
  """
  @spec insert_event!(map()) :: Kiln.Audit.Event.t()
  def insert_event!(overrides \\ %{}) do
    defaults = %{
      event_kind: :stage_started,
      payload: %{"stage_kind" => "coding", "attempt" => 1},
      correlation_id: Ecto.UUID.generate(),
      actor_id: "test:setup"
    }

    {:ok, event} = Kiln.Audit.append(Map.merge(defaults, overrides))
    event
  end
end
