defmodule Kiln.Integration.WorkflowEndToEndTest do
  @moduledoc """
  End-to-end integration test that drives a run through the full queued
  job chain of `priv/workflows/elixir_phoenix_feature.yaml`.

  Phase 3 replaces the old explicit test-level for-loop with
  `Kiln.Stages.NextStageDispatcher`, so this test now seeds only the
  first planning stage and then drains the `:stages` queue until the
  workflow advances itself to `:merged`.

  ## Requirements exercised

  * ORCH-01 — run state machine reaches terminal `:merged`
  * ORCH-07 — audit ledger records every state transition

  (ORCH-03/ORCH-04 — BEAM-kill-and-reboot + exactly-once idempotency —
  are exercised in `test/integration/rehydration_test.exs`.)
  """

  use Kiln.ObanCase, async: false
  use Kiln.StuckDetectorCase, async: false

  require Logger

  alias Kiln.{Audit, Repo, Workflows}
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Runs.Run
  alias Kiln.Runs.Transitions
  alias Kiln.Stages.{StageRun, StageWorker}

  @moduletag :integration

  setup do
    cid = Ecto.UUID.generate()
    Logger.metadata(correlation_id: cid)
    on_exit(fn -> Logger.metadata(correlation_id: nil) end)
    {:ok, correlation_id: cid}
  end

  test "seed planning stage and drain queue to drive run queued → merged", %{correlation_id: cid} do
    {:ok, cg} = Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run =
      RunFactory.insert(:run,
        state: :queued,
        workflow_id: cg.id,
        workflow_version: cg.version,
        workflow_checksum: cg.checksum,
        model_profile_snapshot: %{"role" => "planner"},
        caps_snapshot: cg.caps
      )

    # Kick the run from queued -> planning, then seed only the entry stage.
    {:ok, _} = Transitions.transition(run.id, :planning)

    planning_stage = Enum.find(cg.stages, &(&1.id == cg.entry_node))

    sr =
      StageRunFactory.insert(:stage_run,
        run_id: run.id,
        workflow_stage_id: planning_stage.id,
        kind: planning_stage.kind,
        agent_role: planning_stage.agent_role,
        state: :pending,
        timeout_seconds: planning_stage.timeout_seconds,
        sandbox: planning_stage.sandbox
      )

    args = %{
      "idempotency_key" => "run:#{run.id}:stage:#{sr.id}",
      "run_id" => run.id,
      "stage_run_id" => sr.id,
      "stage_kind" => Atom.to_string(planning_stage.kind),
      "stage_input" => build_stage_input(run, sr, planning_stage.kind)
    }

    assert :ok = perform_job(StageWorker, args)
    assert_enqueued(worker: StageWorker, args: %{"stage_kind" => "coding"})

    assert %{success: success_count, failure: 0} = Oban.drain_queue(queue: :stages)
    assert success_count >= 3

    final = Repo.get!(Run, run.id)

    assert final.state == :merged,
           "After queue drain, run MUST be in :merged"

    # Phase 3 auto-enqueue creates the remaining stage_run rows.
    sr_count =
      StageRun
      |> where([s], s.run_id == ^run.id)
      |> Repo.aggregate(:count)

    assert sr_count == 5,
           "Phase 3 auto-enqueue should materialize all 5 workflow stages; got #{sr_count}"

    # Assert audit events for state transitions: queued->planning, then the
    # StageWorker chain reaches merged by way of the locked progression.
    events = Audit.replay(correlation_id: cid)
    transition_events = Enum.filter(events, &(&1.event_kind == :run_state_transitioned))

    assert length(transition_events) >= 5,
           "Expected ≥5 run_state_transitioned events from the auto-enqueued flow; got #{length(transition_events)}"
  end

  defp build_stage_input(run, sr, kind) do
    ref = %{
      "sha256" => String.duplicate("f", 64),
      "size_bytes" => 100,
      "content_type" => "text/markdown"
    }

    base = %{
      "run_id" => run.id,
      "stage_run_id" => sr.id,
      "attempt" => 1,
      "spec_ref" => ref,
      "budget_remaining" => %{
        "tokens_usd" => 1.0,
        "tokens" => 1000,
        "elapsed_seconds" => 300
      },
      "model_profile_snapshot" => %{
        "role" => "planner",
        "requested_model" => "sonnet-class",
        "fallback_chain" => []
      }
    }

    case kind do
      :planning ->
        Map.merge(base, %{"holdout_excluded" => true, "last_diagnostic_ref" => nil})

      :coding ->
        Map.merge(base, %{"holdout_excluded" => true, "plan_ref" => ref})

      :testing ->
        Map.merge(base, %{"holdout_excluded" => true, "code_ref" => ref})

      :verifying ->
        # `holdout_excluded` is required (type boolean) in the verifying
        # contract — schema relaxes the `const: true` constraint for this
        # stage because verifier runs may legitimately target the
        # holdout set. The field itself is still required (D-74).
        Map.merge(base, %{"holdout_excluded" => true, "test_output_ref" => ref})

        # :merge not driven in Phase 2 — omitted from case per LOCKED decision
    end
  end
end
