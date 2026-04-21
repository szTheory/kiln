defmodule Kiln.Runs.TransitionsStuckTest do
  @moduledoc "OBS-04 — stuck detector halts inside the same transaction as transitions."

  use Kiln.DataCase, async: false
  use Kiln.StuckDetectorCase, async: false

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Runs.Transitions
  alias Kiln.Factory.Run, as: RunFactory

  test "three identical failure signals escalate with stuck reason" do
    run =
      RunFactory.insert(:run,
        state: :verifying,
        stuck_signal_window: [
          %{"stage" => "verifying", "failure_class" => "test_failure"},
          %{"stage" => "verifying", "failure_class" => "test_failure"}
        ]
      )

    meta = %{failure_class: :test_failure, stage_kind: :verifying}

    assert {:ok, esc} = Transitions.transition(run.id, :planning, meta)
    assert esc.state == :escalated
    assert esc.escalation_reason == "stuck"

    stuck =
      Repo.one(
        from(e in Kiln.Audit.Event,
          where: e.run_id == ^run.id and e.event_kind == :stuck_detector_alarmed,
          select: e
        )
      )

    assert stuck
  end

  test "normal transition clears window update path (no halt)" do
    run = RunFactory.insert(:run, state: :verifying, stuck_signal_window: [])

    meta = %{failure_class: :test_failure, stage_kind: :verifying}

    assert {:ok, updated} = Transitions.transition(run.id, :planning, meta)
    assert updated.state == :planning
    assert is_list(updated.stuck_signal_window)
    assert length(updated.stuck_signal_window) == 1
  end
end
