defmodule Kiln.Workflows.GraphTest do
  @moduledoc """
  Unit tests for `Kiln.Workflows.Graph.topological_sort/1`.

  Covers:
    * empty/single/linear/diamond DAG shapes
    * cycle rejection via `:digraph.new([:acyclic])`
    * missing-dep rejection (distinct from :cycle)
    * ETS-leak regression (threat T5 — see plan 02-05 threat model)
  """

  use ExUnit.Case, async: true

  alias Kiln.Workflows.Graph

  describe "topological_sort/1" do
    test "empty stages list returns {:ok, []}" do
      assert {:ok, []} = Graph.topological_sort([])
    end

    test "single entry node returns {:ok, [id]}" do
      stages = [%{id: "a", depends_on: []}]
      assert {:ok, ["a"]} = Graph.topological_sort(stages)
    end

    test "linear chain a -> b -> c returns topological order" do
      stages = [
        %{id: "a", depends_on: []},
        %{id: "b", depends_on: ["a"]},
        %{id: "c", depends_on: ["b"]}
      ]

      assert {:ok, ["a", "b", "c"]} = Graph.topological_sort(stages)
    end

    test "diamond a -> {b, c} -> d produces a valid topological order" do
      stages = [
        %{id: "a", depends_on: []},
        %{id: "b", depends_on: ["a"]},
        %{id: "c", depends_on: ["a"]},
        %{id: "d", depends_on: ["b", "c"]}
      ]

      {:ok, sorted} = Graph.topological_sort(stages)

      a_pos = Enum.find_index(sorted, &(&1 == "a"))
      b_pos = Enum.find_index(sorted, &(&1 == "b"))
      c_pos = Enum.find_index(sorted, &(&1 == "c"))
      d_pos = Enum.find_index(sorted, &(&1 == "d"))

      assert a_pos < b_pos
      assert a_pos < c_pos
      assert b_pos < d_pos
      assert c_pos < d_pos
    end

    test "cycle a -> b -> a returns {:error, :cycle}" do
      stages = [
        %{id: "a", depends_on: ["b"]},
        %{id: "b", depends_on: ["a"]}
      ]

      assert {:error, :cycle} = Graph.topological_sort(stages)
    end

    test "3-node cycle with a valid upstream entry still reports :cycle" do
      # start -> loop_a <-> loop_b (2-cycle downstream; valid entry node)
      stages = [
        %{id: "start", depends_on: []},
        %{id: "loop_a", depends_on: ["start", "loop_b"]},
        %{id: "loop_b", depends_on: ["loop_a"]}
      ]

      assert {:error, :cycle} = Graph.topological_sort(stages)
    end

    test "missing dep returns {:error, {:missing_dep, id}}" do
      stages = [%{id: "a", depends_on: ["nonexistent"]}]
      assert {:error, {:missing_dep, "nonexistent"}} = Graph.topological_sort(stages)
    end

    test "missing-dep takes precedence over cycle when both present" do
      stages = [
        %{id: "a", depends_on: ["ghost"]},
        %{id: "b", depends_on: ["a"]},
        %{id: "c", depends_on: ["b", "c"]}
      ]

      assert {:error, {:missing_dep, "ghost"}} = Graph.topological_sort(stages)
    end
  end

  describe "ETS hygiene (threat T5 — :digraph leak regression)" do
    test "1000 iterations do not grow :ets.all/0 meaningfully" do
      # :digraph is ETS-backed. A missing :digraph.delete/1 would leak one
      # table per call; 1000 iterations would add 1000 tables and eventually
      # exhaust the ETS limit. Allow a small delta (< 10) for unrelated
      # async table activity (Logger handlers etc.).
      before = length(:ets.all())

      for _ <- 1..1000 do
        assert {:ok, _} =
                 Graph.topological_sort([
                   %{id: "x", depends_on: []},
                   %{id: "y", depends_on: ["x"]}
                 ])
      end

      after_count = length(:ets.all())
      assert after_count - before < 10, "ETS table leak: +#{after_count - before} tables"
    end

    test "error paths also clean up the :digraph ETS table" do
      before = length(:ets.all())

      for _ <- 1..500 do
        assert {:error, :cycle} =
                 Graph.topological_sort([
                   %{id: "a", depends_on: ["b"]},
                   %{id: "b", depends_on: ["a"]}
                 ])

        assert {:error, {:missing_dep, _}} =
                 Graph.topological_sort([%{id: "x", depends_on: ["ghost"]}])
      end

      after_count = length(:ets.all())
      assert after_count - before < 10
    end
  end
end
