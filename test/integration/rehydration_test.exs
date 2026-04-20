defmodule Kiln.Integration.RehydrationTest do
  @moduledoc """
  The signature ORCH-03 / ORCH-04 test (Plan 02-08 Task 2): the engine
  MUST survive a BEAM-kill mid-stage and continue from the last
  checkpoint with exactly-one completion on retry.

  Phase 2 simulates the "BEAM kill" by re-sending `:boot_scan` to the
  live `Kiln.Runs.RunDirector` singleton; this exercises the same
  code path a fresh boot would run. `Kiln.RehydrationCase.reset_run_director_for_test/0`
  forces the director's DB connection into the test's Ecto sandbox
  BEFORE the scan fires, resolving threat-model T6 (pre-sandbox-allow
  race).

  Two scenarios:

  1. **Intent retry after restart** — a run is seeded in `:coding`
     with an `external_operations` intent row already present. After
     the simulated restart, a retry of the same `idempotency_key`
     MUST return `{:found_existing, op}` (exactly one row in the DB
     for the key). The run state is preserved across the scan.

  2. **Workflow-checksum mismatch → typed escalation** — a run seeded
     with a `workflow_checksum` that does NOT match the current on-disk
     `priv/workflows/<id>.yaml` (or with `workflow_id` pointing at a
     non-existent file) is transitioned to `:escalated` with
     `escalation_reason: "workflow_changed"` by
     `Kiln.Runs.RunDirector.assert_workflow_unchanged/1` on the boot
     scan (D-94). Operator gets a typed, audit-visible signal rather
     than a subtree silently running against a mutated graph.
  """

  use Kiln.DataCase, async: false
  use Kiln.RehydrationCase

  require Logger

  alias Kiln.ExternalOperations
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.{Repo, Workflows}
  alias Kiln.Runs.{Run, RunDirector, RunSupervisor}

  @moduletag :integration
  @moduletag :rehydration

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    # Checker issue #7 T6 mitigation — forces the live singleton's Repo
    # connection into the test's sandbox BEFORE the fresh :boot_scan.
    reset_run_director_for_test()

    # Clean out subtrees a prior test left behind (director is a
    # :permanent singleton; per-test RunSupervisor cleanup is required
    # for deterministic assertions).
    for {_id, pid, _type, _mods} <- DynamicSupervisor.which_children(RunSupervisor) do
      _ = DynamicSupervisor.terminate_child(RunSupervisor, pid)
    end

    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  test "run in :coding state survives RunDirector restart; intent retry stays exactly-once",
       %{correlation_id: cid} do
    {:ok, cg} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    # Seed a run in :coding with matching checksum so the boot scan's
    # D-94 assertion passes.
    run =
      RunFactory.insert(:run,
        state: :coding,
        workflow_id: cg.id,
        workflow_version: cg.version,
        workflow_checksum: cg.checksum,
        correlation_id: cid
      )

    # Seed an external_operations intent row (simulates a Phase-3 real
    # LLM call that recorded intent + was killed before completion).
    idempotency_key = "run:#{run.id}:stage:fake_stage_id:llm_complete"
    stage_uuid = Ecto.UUID.generate()

    {status, _op} =
      ExternalOperations.fetch_or_record_intent(idempotency_key, %{
        op_kind: "llm_complete",
        intent_payload: %{"dummy" => true},
        run_id: run.id,
        stage_id: stage_uuid,
        correlation_id: cid
      })

    assert status in [:inserted_new, :found_existing]

    # --- SIMULATE BEAM KILL + REBOOT via explicit boot_scan resend ---
    # reset_run_director_for_test/0 in setup already sandbox-allowed the
    # director's DB connection and sent one :boot_scan. Send another
    # explicitly here to re-exercise the scan code path.
    _ = DynamicSupervisor.which_children(RunSupervisor)

    if pid = Process.whereis(RunDirector) do
      send(pid, :boot_scan)
      Process.sleep(300)
    end

    # --- ASSERT EXACTLY-ONCE on idempotency retry ---
    # A retry of the same key returns :found_existing (never a second
    # INSERT). This is the D-14 two-phase intent contract: the row is
    # the authoritative dedupe boundary regardless of how many callers
    # race on the same key across a simulated restart.
    {second_status, _op} =
      ExternalOperations.fetch_or_record_intent(idempotency_key, %{
        op_kind: "llm_complete",
        intent_payload: %{"dummy" => true},
        run_id: run.id,
        stage_id: stage_uuid,
        correlation_id: cid
      })

    assert second_status == :found_existing,
           "Retry of the same idempotency_key after a RunDirector :boot_scan MUST return :found_existing — got #{inspect(second_status)}"

    # Exactly one row for the key in the DB.
    row_count =
      from(o in Kiln.ExternalOperations.Operation,
        where: o.idempotency_key == ^idempotency_key
      )
      |> Repo.aggregate(:count)

    assert row_count == 1,
           "external_operations MUST have exactly one row per idempotency_key across a restart; got #{row_count}"

    # Run state preserved (the scan does not disturb :coding).
    reloaded = Repo.get!(Run, run.id)

    assert reloaded.state == :coding,
           "run state MUST be preserved across director restart; got #{reloaded.state}"
  end

  test "workflow file modified between run-start + rehydration causes :escalated with reason :workflow_changed" do
    # Seed run with a MISMATCHED workflow_checksum (simulates post-hoc
    # modification of the on-disk workflow YAML between run start and
    # the rehydration scan).
    {:ok, cg} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run =
      RunFactory.insert(:run,
        state: :coding,
        workflow_id: cg.id,
        # deliberately wrong
        workflow_checksum: String.duplicate("0", 64)
      )

    # Trigger a rehydration scan
    if pid = Process.whereis(RunDirector) do
      send(pid, :boot_scan)
      Process.sleep(300)
    end

    reloaded = Repo.get!(Run, run.id)

    assert reloaded.state == :escalated,
           "D-94 workflow-checksum mismatch MUST transition the run to :escalated; got #{reloaded.state}"

    assert reloaded.escalation_reason == "workflow_changed",
           "D-94 escalation MUST record reason 'workflow_changed'; got #{inspect(reloaded.escalation_reason)}"
  end
end
