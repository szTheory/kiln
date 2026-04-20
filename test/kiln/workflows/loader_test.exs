defmodule Kiln.Workflows.LoaderTest do
  @moduledoc """
  Integration tests for `Kiln.Workflows.Loader.load/1` + `load!/1` against
  the Plan 02-00 fixtures + the Plan 02-05 realistic workflow. Covers:

    * Happy path (minimal 2-stage + realistic 5-stage)
    * All 5 failure paths exercised by the must_haves truths in 02-05-PLAN
    * yaml_parse errors (missing file)
    * load!/1 raise-on-error semantics
  """

  use ExUnit.Case, async: true

  alias Kiln.Workflows.{CompiledGraph, Loader}

  @minimal "test/support/fixtures/workflows/minimal_two_stage.yaml"
  @cyclic "test/support/fixtures/workflows/cyclic.yaml"
  @missing "test/support/fixtures/workflows/missing_entry.yaml"
  @forward "test/support/fixtures/workflows/forward_edge_on_failure.yaml"
  @signed "test/support/fixtures/workflows/signature_populated.yaml"
  @real "priv/workflows/elixir_phoenix_feature.yaml"

  describe "happy path" do
    test "loads minimal_two_stage.yaml into a well-formed CompiledGraph" do
      assert {:ok, %CompiledGraph{} = cg} = Loader.load(@minimal)
      assert cg.id == "minimal_two_stage"
      assert cg.version == 1
      assert cg.api_version == "kiln.dev/v1"
      assert length(cg.stages) == 2
      assert cg.entry_node == "plan"
      assert hd(cg.stages).id == "plan"
      assert String.length(cg.checksum) == 64
      assert cg.checksum =~ ~r/^[0-9a-f]{64}$/
      assert Map.keys(cg.stages_by_id) |> Enum.sort() == ["code", "plan"]
    end

    test "loads priv/workflows/elixir_phoenix_feature.yaml (positive end-to-end)" do
      assert {:ok, %CompiledGraph{} = cg} = Loader.load(@real)
      assert cg.id == "elixir_phoenix_feature"
      assert length(cg.stages) == 5
      assert cg.entry_node == "plan"

      assert MapSet.new(Map.keys(cg.stages_by_id)) ==
               MapSet.new(["plan", "code", "test", "verify", "merge"])

      # Topological order: plan is first; merge is last
      assert hd(cg.stages).id == "plan"
      assert List.last(cg.stages).id == "merge"

      # merge.on_failure is the :escalate string const per D-59
      merge = cg.stages_by_id["merge"]
      assert merge.on_failure == :escalate
      assert merge.kind == :merge
      # D-61: separate axes — merge kind, coder role
      assert merge.agent_role == :coder

      # on_failure routes back to the ancestor "plan" — D-62 validator 4
      code = cg.stages_by_id["code"]
      assert code.on_failure == %{action: :route, to: "plan", attach: "plan_ref"}
    end

    test "load!/1 returns the CompiledGraph on success" do
      assert %CompiledGraph{} = Loader.load!(@real)
    end
  end

  describe "failure paths — D-62 validator rejections" do
    test "cyclic.yaml rejected with {:graph_invalid, :cycle, _}" do
      assert {:error, {:graph_invalid, :cycle, _}} = Loader.load(@cyclic)
    end

    test "missing_entry.yaml rejected with {:graph_invalid, :no_entry_node, _}" do
      assert {:error, {:graph_invalid, reason, _}} = Loader.load(@missing)
      # The fixture has every stage declaring a depends_on, so no stage
      # has depends_on: [] (validator 1 fires). If a future fixture edit
      # produces a topologically-valid-but-no-entry shape, validator 1
      # still rejects first.
      assert reason == :no_entry_node
    end

    test "forward_edge_on_failure.yaml rejected with {:graph_invalid, :on_failure_forward_edge, _}" do
      assert {:error, {:graph_invalid, :on_failure_forward_edge, detail}} =
               Loader.load(@forward)

      # Detail must identify the offending edge so operators can fix it
      assert is_map_key(detail, :from)
      assert is_map_key(detail, :to)
    end

    test "signature_populated.yaml rejected with {:graph_invalid, :signature_must_be_null, _}" do
      assert {:error, {:graph_invalid, :signature_must_be_null, _}} = Loader.load(@signed)
    end
  end

  describe "failure paths — yaml_parse" do
    test "nonexistent path returns {:yaml_parse, _}" do
      assert {:error, {:yaml_parse, _}} =
               Loader.load("test/support/fixtures/workflows/does_not_exist.yaml")
    end
  end

  describe "load!/1 error semantics" do
    test "load!/1 raises on cyclic workflow" do
      assert_raise RuntimeError, ~r/Kiln\.Workflows\.load!.*failed/, fn ->
        Loader.load!(@cyclic)
      end
    end

    test "load!/1 raises on missing file" do
      assert_raise RuntimeError, ~r/Kiln\.Workflows\.load!.*failed/, fn ->
        Loader.load!("test/support/fixtures/workflows/does_not_exist.yaml")
      end
    end
  end

  describe "Kiln.Workflows facade" do
    test "Kiln.Workflows.load/1 delegates to Loader" do
      assert {:ok, %CompiledGraph{}} = Kiln.Workflows.load(@minimal)
    end

    test "Kiln.Workflows.load!/1 delegates to Loader" do
      assert %CompiledGraph{} = Kiln.Workflows.load!(@minimal)
    end

    test "Kiln.Workflows.checksum/1 returns the struct's 64-char hex" do
      {:ok, cg} = Kiln.Workflows.load(@minimal)
      assert Kiln.Workflows.checksum(cg) == cg.checksum
      assert Kiln.Workflows.checksum(cg) =~ ~r/^[0-9a-f]{64}$/
    end
  end
end
