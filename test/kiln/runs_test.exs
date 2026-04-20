defmodule Kiln.RunsTest do
  @moduledoc """
  Context-level tests for `Kiln.Runs`: the public API RunDirector,
  Transitions, and later-phase consumers depend on — `create/1`,
  `get!/1`, `get/1`, `list_active/0`, `workflow_checksum/1`.
  """

  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs
  alias Kiln.Runs.Run

  describe "create/1" do
    test "inserts a run in :queued state with a hydrated uuidv7 id" do
      attrs = RunFactory.run_factory() |> Map.from_struct()

      assert {:ok, %Run{} = run} = Runs.create(attrs)
      assert run.state == :queued
      assert is_binary(run.id)
      # Canonical UUID string form: 36 chars (32 hex + 4 hyphens)
      assert String.length(run.id) == 36
      # uuidv7 sets the high nibble of the 7th byte to 7 — string form 15th char
      # (0-indexed) position. Loose check: the 15th char (after hyphen layout)
      # should be '7'. This is the 14th hex nibble; in UUID string form with
      # hyphens at 8,13,18,23 it's at index 14.
      assert String.at(run.id, 14) == "7"
    end

    test "returns {:error, changeset} on missing required fields" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Runs.create(%{})
    end

    test "returns {:error, changeset} on bad workflow_checksum format" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:workflow_checksum, "not-hex")

      assert {:error, %Ecto.Changeset{valid?: false} = cs} = Runs.create(attrs)
      assert Keyword.has_key?(cs.errors, :workflow_checksum)
    end
  end

  describe "get/1 and get!/1" do
    test "get!/1 returns the row when present" do
      inserted = RunFactory.insert(:run)
      fetched = Runs.get!(inserted.id)
      assert fetched.id == inserted.id
    end

    test "get!/1 raises Ecto.NoResultsError when absent" do
      assert_raise Ecto.NoResultsError, fn ->
        Runs.get!(Ecto.UUID.generate())
      end
    end

    test "get/1 returns nil when absent" do
      assert Runs.get(Ecto.UUID.generate()) == nil
    end
  end

  describe "list_active/0" do
    test "returns runs in all 6 active states" do
      active_ids =
        Run.active_states()
        |> Enum.map(fn state ->
          RunFactory.insert(:run, state: state).id
        end)
        |> MapSet.new()

      result_ids = Runs.list_active() |> Enum.map(& &1.id) |> MapSet.new()
      assert MapSet.subset?(active_ids, result_ids)
    end

    test "excludes runs in terminal states" do
      _merged = RunFactory.insert(:run, state: :merged)
      _failed = RunFactory.insert(:run, state: :failed)
      _escalated = RunFactory.insert(:run, state: :escalated)
      active = RunFactory.insert(:run, state: :coding)

      result = Runs.list_active()
      result_ids = Enum.map(result, & &1.id) |> MapSet.new()

      assert MapSet.member?(result_ids, active.id)
      refute Enum.any?(result, &(&1.state in [:merged, :failed, :escalated]))
    end

    test "returns empty list when no runs exist" do
      assert Runs.list_active() == []
    end

    test "orders results by inserted_at ascending" do
      first = RunFactory.insert(:run, state: :queued)
      # Small sleep to ensure a different inserted_at (utc_datetime_usec resolution)
      Process.sleep(2)
      second = RunFactory.insert(:run, state: :queued)

      [r1, r2 | _] = Runs.list_active()
      assert r1.id == first.id
      assert r2.id == second.id
    end
  end

  describe "workflow_checksum/1" do
    test "returns {:ok, sha} for an existing run" do
      sha = String.duplicate("b", 64)
      run = RunFactory.insert(:run, workflow_checksum: sha)

      assert {:ok, ^sha} = Runs.workflow_checksum(run.id)
    end

    test "returns {:error, :not_found} for an unknown id" do
      assert {:error, :not_found} = Runs.workflow_checksum(Ecto.UUID.generate())
    end
  end
end
