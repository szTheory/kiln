defmodule Kiln.Runs.TransitionsCapsTest do
  @moduledoc "ORCH-06 — governed-attempt + wall-clock caps escalate inside `Transitions`."

  use Kiln.DataCase, async: false
  use Kiln.StuckDetectorCase, async: false

  alias Kiln.{ExternalOperations, Repo}
  alias Kiln.ExternalOperations.Operation
  alias Kiln.Runs.Transitions
  alias Kiln.Factory.Run, as: RunFactory

  test "governed attempt cap exceeded escalates before replanning" do
    caps = %{
      "max_retries" => 3,
      "max_tokens_usd" => 1.0,
      "max_elapsed_seconds" => 86_400,
      "max_governed_attempts" => 1
    }

    run =
      RunFactory.insert(:run,
        state: :coding,
        governed_attempt_count: 1,
        caps_snapshot: caps
      )

    assert {:ok, esc} = Transitions.transition(run.id, :planning)
    assert esc.state == :escalated
    assert esc.escalation_reason == "governed_attempt_cap"
  end

  test "wall clock cap exceeded escalates" do
    caps = %{
      "max_retries" => 3,
      "max_tokens_usd" => 1.0,
      "max_elapsed_seconds" => 1,
      "max_governed_attempts" => 99
    }

    run =
      RunFactory.insert(:run,
        state: :planning,
        inserted_at: ~U[2020-01-01 00:00:00.000000Z],
        caps_snapshot: caps
      )

    assert {:ok, esc} = Transitions.transition(run.id, :coding)
    assert esc.state == :escalated
    assert esc.escalation_reason == "wall_clock_exceeded"
  end

  test "terminal failed abandons open external operations" do
    run = RunFactory.insert(:run, state: :planning)

    key = "cap-abandon-#{run.id}"

    assert {:inserted_new, op} =
             ExternalOperations.fetch_or_record_intent(key, %{
               op_kind: "llm_completion",
               run_id: run.id,
               intent_payload: %{}
             })

    assert op.state == :intent_recorded

    assert {:ok, failed} = Transitions.transition(run.id, :failed, %{reason: :test_failure})
    assert failed.state == :failed

    assert %Operation{state: :abandoned} = Repo.get!(Operation, op.id)
  end
end
