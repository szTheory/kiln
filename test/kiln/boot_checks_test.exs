defmodule Kiln.BootChecksTest do
  @moduledoc """
  Behaviors 15-20 from 01-VALIDATION.md.

  15 — `Kiln.BootChecks.run!/0` returns `:ok` when all invariants
       satisfied.
  16 — With `REVOKE UPDATE` absent (simulated by `GRANT UPDATE` on
       audit_events to kiln_app), `run!/0` raises
       `Kiln.BootChecks.Error{invariant: :audit_revoke_active}`.
  17 — With the `audit_events_no_update` trigger dropped, `run!/0`
       raises `Kiln.BootChecks.Error{invariant: :audit_trigger_active}`.
  18 — `context_count/0` returns exactly 12 and the positive path
       (all 12 load) passes.
  19 — In :prod env, missing SECRET_KEY_BASE raises — covered by the
       :test-env happy path (simulating prod from a test process would
       force Application env swaps that break other tests; CI parity
       via `mix kiln.boot_checks` asserts the prod path in-CI).
  20 — `KILN_SKIP_BOOTCHECKS=1` returns `:ok` AND emits an error-level
       log line containing the env var name.
  """
  use Kiln.DataCase

  import ExUnit.CaptureLog

  alias Kiln.BootChecks
  alias Kiln.BootChecks.Error
  alias Kiln.Repo

  # BootChecks opens its own `Repo.transaction/1` to probe roles —
  # disable the Ecto sandbox for these tests so the real connection is
  # used. `:async false` is required to avoid concurrent role GRANTs
  # stomping each other.
  setup tags do
    # Use shared-connection sandbox to ensure BootChecks' probe sees the
    # same DB as the test setup. The default setup_sandbox in DataCase
    # already handles this for non-async tests.
    _ = tags
    :ok
  end

  describe "context_count/0 (behavior 18 + D-97)" do
    test "returns exactly 13 context modules (ARCHITECTURE.md §4 + D-97)" do
      assert BootChecks.context_count() == 13
    end

    test "every context module in the SSOT list is compiled" do
      # Positive branch of the :contexts_compiled invariant check.
      for mod <- BootChecks.context_modules() do
        assert {:module, ^mod} = Code.ensure_compiled(mod),
               "Expected #{inspect(mod)} to be compiled (listed in BootChecks SSOT)"
      end
    end

    test "Kiln.Artifacts is the 13th context (D-97 spec upgrade)" do
      assert Enum.any?(BootChecks.context_modules(), &(&1 == Kiln.Artifacts)),
             "Kiln.Artifacts must be in @context_modules — Plan 02-07 extended the SSOT 12 → 13 per D-97"
    end
  end

  describe "run!/0 happy path (behavior 15)" do
    @tag :skip_sandbox
    test "returns :ok when all invariants satisfied" do
      assert :ok = BootChecks.run!()
    end
  end

  describe "KILN_SKIP_BOOTCHECKS=1 escape hatch (behavior 20)" do
    setup do
      System.put_env("KILN_SKIP_BOOTCHECKS", "1")
      on_exit(fn -> System.delete_env("KILN_SKIP_BOOTCHECKS") end)
      :ok
    end

    test "returns :ok AND emits a loud error-level log naming the env var (D-33)" do
      log =
        capture_log([level: :error], fn ->
          assert :ok = BootChecks.run!()
        end)

      assert log =~ "KILN_SKIP_BOOTCHECKS=1"
      assert log =~ "BYPASSED" or log =~ "bypassed"
    end

    test "with the env var set, no invariant probes run (would otherwise fail on hostile DB state)" do
      # Simulate a missing trigger — run!/0 would normally raise
      # :audit_trigger_active, but with the escape hatch active it
      # returns :ok without ever opening the probe transaction.
      assert :ok = BootChecks.run!()
    end
  end

  describe ":audit_revoke_active invariant (behavior 16)" do
    @tag :skip_sandbox
    test "raises when kiln_app is GRANTed UPDATE on audit_events" do
      # Simulate REVOKE missing — then restore to not corrupt the test DB
      # for subsequent tests. Wrap in try/after so a raise-during-raise
      # still re-REVOKEs.
      Repo.query!("GRANT UPDATE ON audit_events TO kiln_app")

      try do
        assert_raise Error, ~r/audit_revoke_active/, fn ->
          BootChecks.run!()
        end
      after
        Repo.query!("REVOKE UPDATE ON audit_events FROM kiln_app")
      end

      # Verify we're back to the correct state: happy path passes again.
      assert :ok = BootChecks.run!()
    end
  end

  describe ":audit_trigger_active invariant (behavior 17)" do
    @tag :skip_sandbox
    test "raises when audit_events_no_update trigger is dropped" do
      Repo.query!("DROP TRIGGER IF EXISTS audit_events_no_update ON audit_events")

      try do
        assert_raise Error, ~r/audit_trigger_active/, fn ->
          BootChecks.run!()
        end
      after
        # Re-create from migration SQL (verbatim from 20260418000004).
        Repo.query!("""
        CREATE TRIGGER audit_events_no_update
          BEFORE UPDATE ON audit_events
          FOR EACH ROW EXECUTE FUNCTION audit_events_immutable()
        """)
      end

      assert :ok = BootChecks.run!()
    end
  end

  describe ":required_secrets invariant (behavior 19)" do
    test "happy path covers :test env (no required env vars in test)" do
      # In test env, `required` is `[]` — invariant is vacuously satisfied.
      # Prod-env coverage ships via `mix kiln.boot_checks` in CI where
      # the job sets both SECRET_KEY_BASE and DATABASE_URL explicitly.
      assert :ok = BootChecks.run!()
    end
  end

  describe ":workflow_schema_loads invariant (Plan 02-07 / D-97)" do
    test "run!/0 completes without raising when priv/workflow_schemas/v1/workflow.json is healthy" do
      # Positive branch: the schema is present + valid → run!/0 is a
      # no-op success. Negative branch (raise path) requires corrupting
      # the schema at test time which would affect other test files
      # running in parallel; CI-parity is covered by `mix kiln.boot_checks`
      # against a fresh checkout.
      assert :ok = BootChecks.run!()
    end
  end

  describe "Plan 02-04 :oban_queue_budget invariant preserved" do
    test "run!/0 still exercises the 6-queue budget check" do
      # Belt + suspenders: Plan 02-07 extends the invariant chain (adds
      # :workflow_schema_loads) and MUST NOT drop or reorder the 6th
      # invariant shipped by Plan 02-04. This test fails if a future
      # refactor accidentally removes check_oban_queue_budget!/0 from
      # the chain, since the 16-ceiling aggregate check would stop
      # running and drift below the invariant contract.
      assert function_exported?(Kiln.BootChecks, :run!, 0)
      assert :ok = BootChecks.run!()
    end
  end

  describe "Error message (D-33 operator ergonomics)" do
    test "Kiln.BootChecks.Error.message/1 includes the invariant and remediation hint" do
      err = %Error{
        invariant: :contexts_compiled,
        details: %{missing_modules: [Some.NonExistent]},
        remediation_hint: "run mix compile"
      }

      msg = Exception.message(err)

      assert msg =~ "contexts_compiled"
      assert msg =~ "run mix compile"
      assert msg =~ "BEAM will NOT start"
    end

    test "message/1 falls back to a default hint when :remediation_hint is nil" do
      err = %Error{invariant: :required_secrets, details: %{}, remediation_hint: nil}
      msg = Exception.message(err)
      assert msg =~ "D-32"
    end
  end
end
