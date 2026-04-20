defmodule Kiln.Stages.StageRunTest do
  @moduledoc """
  Schema-level tests for `Kiln.Stages.StageRun`:

    * changeset enum enforcement (kind/agent_role/state/sandbox)
    * attempt-range validation (D-74 1..10 ceiling)
    * unique `(run_id, workflow_stage_id, attempt)` business identity
    * FK `on_delete: :restrict` — runs with live stage_runs can't be
      deleted (D-81 forensic preservation)
  """

  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Factory.StageRun, as: StageRunFactory
  alias Kiln.Stages.StageRun

  describe "changeset/2" do
    test "accepts factory-shaped attrs as valid when run_id is supplied" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)

      cs = StageRun.changeset(%StageRun{}, attrs)
      assert cs.valid?, "factory attrs produced invalid changeset: #{inspect(cs.errors)}"
    end

    test "rejects unknown kind" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:kind, :bogus)

      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
    end

    test "rejects unknown agent_role" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:agent_role, :bogus)

      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
    end

    test "rejects unknown state" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:state, :bogus)

      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
    end

    test "rejects unknown sandbox" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:sandbox, :bogus)

      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
    end

    test "rejects attempt outside 1..10 (D-74 ceiling)" do
      run = RunFactory.insert(:run)

      for bad <- [0, 11, 100, -1] do
        attrs =
          StageRunFactory.stage_run_factory()
          |> Map.from_struct()
          |> Map.put(:run_id, run.id)
          |> Map.put(:attempt, bad)

        cs = StageRun.changeset(%StageRun{}, attrs)
        refute cs.valid?, "attempt=#{bad} should be invalid"
      end
    end

    test "accepts all 6 known states" do
      run = RunFactory.insert(:run)

      for state <- StageRun.states() do
        attrs =
          StageRunFactory.stage_run_factory()
          |> Map.from_struct()
          |> Map.put(:run_id, run.id)
          |> Map.put(:state, state)

        cs = StageRun.changeset(%StageRun{}, attrs)
        assert cs.valid?, "state=#{state} produced invalid changeset: #{inspect(cs.errors)}"
      end
    end

    test "requires run_id" do
      attrs = StageRunFactory.stage_run_factory() |> Map.from_struct()
      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :run_id)
    end

    test "requires workflow_stage_id" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:workflow_stage_id, nil)

      cs = StageRun.changeset(%StageRun{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :workflow_stage_id)
    end
  end

  describe "unique (run_id, workflow_stage_id, attempt)" do
    test "second insert with same triple fails with a clean changeset error" do
      run = RunFactory.insert(:run)

      attrs =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)

      assert {:ok, _first} = Kiln.Stages.create_stage_run(attrs)
      assert {:error, cs} = Kiln.Stages.create_stage_run(attrs)
      refute cs.valid?
      # Ecto reports the unique_constraint error on one of the fields in the key.
      errors = Enum.map(cs.errors, fn {field, _} -> field end)
      assert Enum.any?(errors, &(&1 in [:run_id, :workflow_stage_id, :attempt]))
    end

    test "same (run_id, workflow_stage_id) with different attempt succeeds" do
      run = RunFactory.insert(:run)

      base =
        StageRunFactory.stage_run_factory()
        |> Map.from_struct()
        |> Map.put(:run_id, run.id)
        |> Map.put(:workflow_stage_id, "stage_shared")

      assert {:ok, _a1} = Kiln.Stages.create_stage_run(Map.put(base, :attempt, 1))
      assert {:ok, _a2} = Kiln.Stages.create_stage_run(Map.put(base, :attempt, 2))
    end
  end

  describe "FK on_delete: :restrict (D-81)" do
    test "deleting a run with live stage_runs raises Ecto.ConstraintError on the FK" do
      run = RunFactory.insert(:run)
      _sr = StageRunFactory.insert(:stage_run, run_id: run.id)

      # Ecto translates the Postgres foreign_key_violation (SQLSTATE 23503)
      # into an Ecto.ConstraintError when the caller doesn't declare a
      # `foreign_key_constraint/2` on the delete changeset. The raw
      # Postgrex.Error would surface only if we bypassed Ecto (e.g., via
      # Repo.query!/2). Either way the D-81 invariant holds: the runs row
      # CANNOT be deleted while stage_runs reference it.
      assert_raise Ecto.ConstraintError, ~r/stage_runs_run_id_fkey/, fn ->
        Kiln.Repo.delete!(run)
      end
    end

    test "deleting a run via raw SQL raises Postgrex.Error foreign_key_violation" do
      run = RunFactory.insert(:run)
      _sr = StageRunFactory.insert(:stage_run, run_id: run.id)

      # Bypass Ecto's schema-level constraint translation to verify the
      # DB-level policy directly. This proves the FK is enforced by
      # Postgres even when a caller goes around the changeset layer.
      assert_raise Postgrex.Error, ~r/foreign key|23503/i, fn ->
        Kiln.Repo.query!("DELETE FROM runs WHERE id = $1", [Ecto.UUID.dump!(run.id)])
      end
    end
  end

  describe "public accessors" do
    test "states/0 returns exactly 6 atoms" do
      assert length(StageRun.states()) == 6
      assert :pending in StageRun.states()
      assert :cancelled in StageRun.states()
    end

    test "kinds/0 returns the 5 D-58 kinds" do
      assert MapSet.new(StageRun.kinds()) ==
               MapSet.new([:planning, :coding, :testing, :verifying, :merge])
    end

    test "agent_roles/0 returns the 7 D-58 roles" do
      assert MapSet.new(StageRun.agent_roles()) ==
               MapSet.new([:planner, :coder, :tester, :reviewer, :uiux, :qa_verifier, :mayor])
    end

    test "sandboxes/0 returns the 3 D-58 modes" do
      assert MapSet.new(StageRun.sandboxes()) == MapSet.new([:none, :readonly, :readwrite])
    end
  end
end
