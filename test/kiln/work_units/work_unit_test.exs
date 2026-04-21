defmodule Kiln.WorkUnits.WorkUnitTest do
  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Repo
  alias Kiln.WorkUnits.{Dependency, WorkUnit}

  defp insert_run!(attrs \\ %{}) do
    RunFactory.insert(:run, attrs)
  end

  describe "work_units schema" do
    test "inserts a valid work unit with uuidv7 id, state :open, blockers_open_count 0" do
      run = insert_run!()

      assert {:ok, %WorkUnit{} = wu} =
               %WorkUnit{}
               |> WorkUnit.changeset(%{
                 run_id: run.id,
                 agent_role: :planner,
                 input_payload: %{},
                 result_payload: %{}
               })
               |> Repo.insert()

      assert wu.state == :open
      assert wu.blockers_open_count == 0
      assert byte_size(Ecto.UUID.dump!(wu.id)) == 16
    end

    test "invalid state, agent_role, and negative priority fail changeset validation (mirrors DB CHECK domains)" do
      run = insert_run!()

      assert {:error, cs} =
               %WorkUnit{}
               |> WorkUnit.changeset(%{
                 "run_id" => run.id,
                 "agent_role" => "wizard",
                 "state" => "open",
                 "input_payload" => %{},
                 "result_payload" => %{}
               })
               |> Repo.insert()

      assert %{agent_role: [_]} = errors_on(cs)

      assert {:error, cs} =
               %WorkUnit{}
               |> WorkUnit.changeset(%{
                 "run_id" => run.id,
                 "agent_role" => "planner",
                 "state" => "bogus",
                 "input_payload" => %{},
                 "result_payload" => %{}
               })
               |> Repo.insert()

      assert %{state: [_]} = errors_on(cs)

      assert {:error, cs} =
               %WorkUnit{}
               |> WorkUnit.changeset(%{
                 "run_id" => run.id,
                 "agent_role" => "planner",
                 "priority" => -1,
                 "input_payload" => %{},
                 "result_payload" => %{}
               })
               |> Repo.insert()

      assert %{priority: [_]} = errors_on(cs)
    end

    test "dependency rows reject self-links and duplicate pairs" do
      run = insert_run!()

      {:ok, a} =
        %WorkUnit{}
        |> WorkUnit.changeset(%{run_id: run.id, agent_role: :planner})
        |> Repo.insert()

      {:ok, b} =
        %WorkUnit{}
        |> WorkUnit.changeset(%{run_id: run.id, agent_role: :coder})
        |> Repo.insert()

      assert {:error, cs} =
               %Dependency{}
               |> Dependency.changeset(%{
                 blocked_work_unit_id: a.id,
                 blocker_work_unit_id: a.id
               })
               |> Repo.insert()

      assert %{blocker_work_unit_id: [_]} = errors_on(cs)

      attrs = %{blocked_work_unit_id: a.id, blocker_work_unit_id: b.id}

      assert {:ok, _} =
               %Dependency{}
               |> Dependency.changeset(attrs)
               |> Repo.insert()

      assert {:error, cs} =
               %Dependency{}
               |> Dependency.changeset(attrs)
               |> Repo.insert()

      assert %{blocked_work_unit_id: [_]} = errors_on(cs)
    end

    test "deleting a run with referenced work units is rejected by FK restrictions" do
      run = insert_run!()

      assert {:ok, _} =
               %WorkUnit{}
               |> WorkUnit.changeset(%{run_id: run.id, agent_role: :planner})
               |> Repo.insert()

      assert_raise Ecto.ConstraintError, fn ->
        run |> Repo.delete!()
      end
    end

    test "ready-queue partial index exists for open/blocked/in_progress with zero blockers" do
      assert %Postgrex.Result{rows: [[true]]} =
               Repo.query!("""
               SELECT EXISTS (
                 SELECT 1
                 FROM pg_indexes
                 WHERE schemaname = 'public'
                   AND tablename = 'work_units'
                   AND indexname = 'work_units_ready_partial_idx'
               )
               """)
    end
  end
end
