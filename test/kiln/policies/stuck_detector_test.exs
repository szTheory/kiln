defmodule Kiln.Policies.StuckDetectorTest do
  # Uses Kiln.StuckDetectorCase (Plan 02-00) to centralise the
  # singleton-reuse dance (checker issue #6 mitigation). The case
  # template guarantees StuckDetector is alive for the test without
  # inline Process.whereis/start_link logic.
  use Kiln.StuckDetectorCase, async: false
  alias Kiln.Policies.StuckDetector

  test "check/1 returns :ok for any map (no-op body P2)" do
    assert :ok == StuckDetector.check(%{run: :fake, to: :planning, meta: %{}})
    assert :ok == StuckDetector.check(%{})
  end

  test "check/1 accepts a full transition context shape without raising" do
    ctx = %{
      run: %{id: Ecto.UUID.generate(), state: :planning},
      to: :coding,
      meta: %{reason: :planner_done}
    }

    assert :ok == StuckDetector.check(ctx)
  end
end
