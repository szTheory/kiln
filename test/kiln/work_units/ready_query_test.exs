defmodule Kiln.WorkUnits.ReadyQueryTest do
  use Kiln.DataCase, async: true

  import Ecto.Query

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.WorkUnits
  alias Kiln.WorkUnits.ReadyQuery

  test "ready_for_run/2 filters by role when provided" do
    run = RunFactory.insert(:run)
    assert {:ok, _} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})
    assert {:ok, _} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :coder})

    planner_ids =
      ReadyQuery.ready_for_run(run.id, :planner) |> select([w], w.id) |> Repo.all()

    assert length(planner_ids) == 1
  end

  test "ready_for_run/1 excludes units with open blockers" do
    run = RunFactory.insert(:run)
    assert {:ok, blocked} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})
    assert {:ok, blocker} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :coder})
    assert {:ok, _} = WorkUnits.block_work_unit(blocked.id, blocker.id)

    assert Repo.all(ReadyQuery.ready_for_run(run.id)) |> Enum.map(& &1.id) == [blocker.id]
  end
end
