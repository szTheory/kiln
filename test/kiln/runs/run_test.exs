defmodule Kiln.Runs.RunTest do
  @moduledoc """
  Schema-level tests for `Kiln.Runs.Run` — the changeset's enum
  enforcement (D-86 9-state domain), the workflow_checksum format
  regex (D-94 defence-in-depth mirror of the DB CHECK), and the three
  public accessors (`states/0`, `terminal_states/0`, `active_states/0`)
  the state machine (Plan 06) + RunDirector (Plan 07) will call.
  """

  use Kiln.DataCase, async: true

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.Run

  describe "changeset/2" do
    test "accepts a factory-shaped set of attrs as valid" do
      attrs = RunFactory.run_factory() |> Map.from_struct()
      cs = Run.changeset(%Run{}, attrs)
      assert cs.valid?, "factory attrs produced invalid changeset: #{inspect(cs.errors)}"
    end

    test "rejects unknown state (Ecto.Enum boundary)" do
      attrs = RunFactory.run_factory() |> Map.from_struct() |> Map.put(:state, :bogus)
      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
    end

    test "accepts all 9 known states as valid" do
      for state <- Run.states() do
        attrs = RunFactory.run_factory() |> Map.from_struct() |> Map.put(:state, state)
        cs = Run.changeset(%Run{}, attrs)
        assert cs.valid?, "state=#{state} produced invalid changeset: #{inspect(cs.errors)}"
      end
    end

    test "rejects malformed workflow_checksum (validate_format)" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:workflow_checksum, "not-hex")

      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :workflow_checksum)
    end

    test "rejects short workflow_checksum (<64 chars)" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:workflow_checksum, String.duplicate("a", 32))

      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :workflow_checksum)
    end

    test "rejects uppercase workflow_checksum (must be lowercase hex)" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:workflow_checksum, String.duplicate("A", 64))

      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :workflow_checksum)
    end

    test "requires workflow_id" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:workflow_id, nil)

      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :workflow_id)
    end

    test "requires correlation_id" do
      attrs =
        RunFactory.run_factory()
        |> Map.from_struct()
        |> Map.put(:correlation_id, nil)

      cs = Run.changeset(%Run{}, attrs)
      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :correlation_id)
    end
  end

  describe "states/0 and the two sub-accessors" do
    test "states/0 returns exactly 9 atoms" do
      assert length(Run.states()) == 9
      assert :queued in Run.states()
      assert :escalated in Run.states()
      assert :blocked in Run.states()
    end

    test "terminal_states/0 returns [merged, failed, escalated]" do
      assert MapSet.new(Run.terminal_states()) == MapSet.new([:merged, :failed, :escalated])
    end

    test "active_states/0 returns the 6 non-terminal states" do
      assert MapSet.new(Run.active_states()) ==
               MapSet.new([:queued, :planning, :coding, :testing, :verifying, :blocked])
    end

    test "terminal_states and active_states are disjoint and partition states" do
      terminal = MapSet.new(Run.terminal_states())
      active = MapSet.new(Run.active_states())
      all = MapSet.new(Run.states())

      assert MapSet.disjoint?(terminal, active)
      assert MapSet.union(terminal, active) == all
    end
  end

  describe "transition_changeset/3" do
    test "accepts a valid target state" do
      run = RunFactory.insert(:run)
      cs = Run.transition_changeset(run, %{state: :planning}, %{})
      assert cs.valid?
    end

    test "rejects an unknown target state" do
      run = RunFactory.insert(:run)
      cs = Run.transition_changeset(run, %{state: :bogus}, %{})
      refute cs.valid?
    end
  end
end
