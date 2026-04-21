defmodule Kiln.WorkUnitsTest do
  use Kiln.DataCase, async: false

  import Ecto.Query

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.WorkUnits
  alias Kiln.WorkUnits.ReadyQuery
  alias Kiln.WorkUnits.WorkUnit
  alias Kiln.WorkUnits.WorkUnitEvent

  defp run!, do: RunFactory.insert(:run)

  test "create_work_unit/1 inserts row and exactly one :created event" do
    run = run!()

    assert {:ok, wu} =
             WorkUnits.create_work_unit(%{
               run_id: run.id,
               agent_role: :coder,
               input_payload: %{},
               result_payload: %{}
             })

    events =
      from(e in WorkUnitEvent,
        where: e.work_unit_id == ^wu.id,
        select: e.event_kind
      )
      |> Repo.all()

    assert events == [:created]
  end

  test "claim_next_ready/2 allows only the first successful claim (optimistic row version)" do
    run = run!()
    assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)

    assert {:ok, %WorkUnit{}} = WorkUnits.claim_next_ready(run.id, :planner)

    for _ <- 1..7 do
      assert {:error, :none_ready} = WorkUnits.claim_next_ready(run.id, :planner)
    end
  end

  test "block_work_unit/2 bumps blockers and removes unit from ready query" do
    run = run!()
    assert {:ok, blocked} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})
    assert {:ok, blocker} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :coder})

    assert {:ok, bumped} = WorkUnits.block_work_unit(blocked.id, blocker.id)
    assert bumped.blockers_open_count == 1

    ready_ids = ReadyQuery.ready_for_run(run.id) |> select([w], w.id) |> Repo.all()
    refute blocked.id in ready_ids
    assert blocker.id in ready_ids
  end

  test "unblock_work_unit/2 decrements blockers and re-admits ready row" do
    run = run!()
    assert {:ok, blocked} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})
    assert {:ok, blocker} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :coder})
    assert {:ok, _} = WorkUnits.block_work_unit(blocked.id, blocker.id)
    assert {:ok, cleared} = WorkUnits.unblock_work_unit(blocked.id, blocker.id)
    assert cleared.blockers_open_count == 0

    ready = Repo.all(ReadyQuery.ready_for_run(run.id))
    assert Enum.any?(ready, &(&1.id == blocked.id))

    kinds =
      from(e in WorkUnitEvent,
        where: e.work_unit_id == ^blocked.id,
        order_by: [asc: e.inserted_at],
        select: e.event_kind
      )
      |> Repo.all()

    assert :unblocked in kinds
  end

  test "close_work_unit/2 closes unit and appends :closed event" do
    run = run!()
    assert {:ok, wu} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :tester})
    assert {:ok, closed} = WorkUnits.close_work_unit(wu.id, :tester)
    assert closed.state == :closed
    assert closed.closed_at

    last =
      from(e in WorkUnitEvent,
        where: e.work_unit_id == ^wu.id,
        order_by: [desc: e.inserted_at],
        limit: 1,
        select: e.event_kind
      )
      |> Repo.one()

    assert last == :closed
  end

  test "claim_next_ready/2 enforces role-tag match" do
    run = run!()
    assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)
    assert {:error, :role_mismatch} = WorkUnits.claim_next_ready(run.id, :coder)
  end

  test "ready-query ordering is stable by priority then insertion time" do
    run = run!()

    assert {:ok, third} =
             WorkUnits.create_work_unit(%{
               run_id: run.id,
               agent_role: :planner,
               priority: 10,
               input_payload: %{},
               result_payload: %{}
             })

    assert {:ok, first} =
             WorkUnits.create_work_unit(%{
               run_id: run.id,
               agent_role: :planner,
               priority: 5,
               input_payload: %{},
               result_payload: %{}
             })

    assert {:ok, second} =
             WorkUnits.create_work_unit(%{
               run_id: run.id,
               agent_role: :planner,
               priority: 10,
               input_payload: %{},
               result_payload: %{}
             })

    ids = ReadyQuery.ready_for_run(run.id) |> select([w], w.id) |> Repo.all()
    assert ids == [first.id, third.id, second.id]
  end

  test "complete_and_handoff/3 closes current unit and creates successors" do
    run = run!()
    assert {:ok, wu} = WorkUnits.create_work_unit(%{run_id: run.id, agent_role: :planner})

    assert {:ok, {closed, succ}} =
             WorkUnits.complete_and_handoff(wu.id, :planner, [
               %{agent_role: :coder},
               %{agent_role: :tester}
             ])

    assert closed.state == :closed
    assert length(succ) == 2
    assert Enum.all?(succ, &(&1.state == :open))

    kinds =
      from(e in WorkUnitEvent,
        where: e.work_unit_id == ^wu.id,
        order_by: [asc: e.inserted_at],
        select: e.event_kind
      )
      |> Repo.all()

    assert kinds == [:created, :completed, :closed]
  end
end
