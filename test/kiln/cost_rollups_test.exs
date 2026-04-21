defmodule Kiln.CostRollupsTest do
  use Kiln.DataCase, async: true

  alias Kiln.CostRollups
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory

  test "by_run sums cost_usd for the same run" do
    run = RunFactory.insert(:run)

    StageRunFactory.insert(:stage_run,
      run_id: run.id,
      cost_usd: Decimal.new("0.10")
    )

    StageRunFactory.insert(:stage_run,
      run_id: run.id,
      attempt: 2,
      workflow_stage_id: "other_stage",
      cost_usd: Decimal.new("0.20")
    )

    rows = CostRollups.by_run(%{})
    row = Enum.find(rows, &(&1.key == run.id))
    assert row.calls == 2
    assert Decimal.compare(row.usd, Decimal.new("0.30")) == :eq
  end
end
