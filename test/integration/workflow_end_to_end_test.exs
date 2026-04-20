defmodule Kiln.Integration.WorkflowEndToEndTest do
  @moduledoc """
  End-to-end integration test that drives a run through the 4 non-merge
  stages of `priv/workflows/elixir_phoenix_feature.yaml` — plan, code,
  test, verify — and asserts the run reaches `:merged` via the LOCKED
  `:verifying → :merged` transition in `Kiln.Stages.StageWorker`
  (Plan 02-08 Task 2).

  The 5th `:merge` stage in the workflow is NOT driven here: it is
  Phase-3 territory per Plan 02-08's locked decision (the `:merge` kind
  stage performs no StageWorker-level transition because the terminal
  `:merged` state is already reached via `:verifying`, and the actual
  git-merge operation + the correct transition owner for the `:merge`
  kind ship in Phase 3).

  Per Plan 02-08 CONTEXT.md `<deferred>` entry, next-stage auto-enqueue
  is deferred to Phase 3. Phase 2's test drives dispatch with an
  explicit test-level for-loop, simulating the future dispatcher. This
  is intentional: Phase 2 demonstrates rehydration + per-stage
  idempotency under externally-driven stage dispatch; auto-dispatch
  depends on stage-output → next-stage-input wiring (diff_ref,
  test_output_ref) that Phase 3's real agents produce.

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

  # Drives 4 stages (plan, code, test, verify) via the LOCKED StageWorker
  # transition mapping. verifying → :merged takes the run to terminal.
  # The 5th :merge stage is NOT driven in Phase 2 — see CONTEXT.md
  # <deferred> entry for "Auto-enqueue of next stage's Oban job..."
  # (Phase 3).
  test "4 stages (plan→code→test→verify) drive a run queued → merged", %{correlation_id: cid} do
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

    # Drive: first transition to :planning (normally the Intents kickoff does this)
    {:ok, _} = Transitions.transition(run.id, :planning)

    # Drive 4 stages (skip :merge — Phase 3 territory per LOCKED decision)
    stages_to_drive =
      Enum.filter(cg.stages, fn s -> s.kind in [:planning, :coding, :testing, :verifying] end)

    assert length(stages_to_drive) == 4,
           "elixir_phoenix_feature.yaml MUST have exactly 4 non-merge stages; got #{length(stages_to_drive)}"

    for stage <- stages_to_drive do
      sr =
        StageRunFactory.insert(:stage_run,
          run_id: run.id,
          workflow_stage_id: stage.id,
          kind: stage.kind,
          agent_role: stage.agent_role,
          state: :pending,
          timeout_seconds: stage.timeout_seconds,
          sandbox: stage.sandbox
        )

      args = %{
        "idempotency_key" => "run:#{run.id}:stage:#{sr.id}",
        "run_id" => run.id,
        "stage_run_id" => sr.id,
        "stage_kind" => Atom.to_string(stage.kind),
        "stage_input" => build_stage_input(run, sr, stage.kind)
      }

      assert :ok = perform_job(StageWorker, args),
             "StageWorker for kind=#{stage.kind} MUST complete successfully"
    end

    # After verifying stage, run reaches :merged via LOCKED mapping
    # :verifying → :merged.
    final = Repo.get!(Run, run.id)

    assert final.state == :merged,
           "After 4 stages driven (plan→code→test→verify), run MUST be in :merged (verifying→merged per LOCKED StageWorker mapping)"

    # Assert stage_runs count = 4 (the four driven stages)
    sr_count =
      StageRun
      |> where([s], s.run_id == ^run.id)
      |> Repo.aggregate(:count)

    assert sr_count == 4,
           "Phase 2 drives exactly 4 stages (merge deferred to Phase 3); got #{sr_count}"

    # Assert audit events for state transitions: 1 (queued→planning) + 4 (stage-driven) = 5
    events = Audit.replay(correlation_id: cid)
    transition_events = Enum.filter(events, &(&1.event_kind == :run_state_transitioned))

    assert length(transition_events) >= 5,
           "Expected ≥5 run_state_transitioned events (queued→planning + 4 stage-driven transitions); got #{length(transition_events)}"
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
