defmodule Kiln.Workflows.CompilerTest do
  @moduledoc """
  Unit tests for `Kiln.Workflows.Compiler.compile/1` on raw (string-keyed)
  maps — no YAML layer. Exercises every D-62 validator with surgically
  crafted inputs and asserts on checksum determinism + stability.
  """

  use ExUnit.Case, async: true

  alias Kiln.Workflows.{CompiledGraph, Compiler}

  # Build a valid base workflow map with one entry-node stage. Tests
  # mutate this via put_in / update_in to isolate each validator path.
  defp base_map(overrides \\ %{}) do
    base = %{
      "apiVersion" => "kiln.dev/v1",
      "id" => "wf_a",
      "version" => 1,
      "metadata" => %{},
      "signature" => nil,
      "spec" => %{
        "caps" => %{
          "max_retries" => 3,
          "max_tokens_usd" => 1.0,
          "max_elapsed_seconds" => 300,
          "max_stage_duration_seconds" => 120
        },
        "model_profile" => "elixir_lib",
        "stages" => [
          %{
            "id" => "stage_a",
            "kind" => "planning",
            "agent_role" => "planner",
            "depends_on" => [],
            "timeout_seconds" => 60,
            "retry_policy" => %{
              "max_attempts" => 3,
              "backoff" => "exponential",
              "base_delay_seconds" => 5
            },
            "sandbox" => "readonly"
          }
        ]
      }
    }

    Map.merge(base, overrides)
  end

  describe "happy path" do
    test "compiles a minimal valid single-stage workflow" do
      assert {:ok, %CompiledGraph{} = cg} = Compiler.compile(base_map())
      assert cg.entry_node == "stage_a"
      assert length(cg.stages) == 1
      assert cg.model_profile == "elixir_lib"
      assert String.length(cg.checksum) == 64
    end

    test "compiles a multi-stage workflow in topological order" do
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            s,
            %{
              "id" => "stage_b",
              "kind" => "coding",
              "agent_role" => "coder",
              "depends_on" => ["stage_a"],
              "timeout_seconds" => 60,
              "retry_policy" => %{
                "max_attempts" => 3,
                "backoff" => "exponential",
                "base_delay_seconds" => 5
              },
              "sandbox" => "readwrite"
            }
          ]
        end)

      {:ok, cg} = Compiler.compile(m)
      assert Enum.map(cg.stages, & &1.id) == ["stage_a", "stage_b"]
      assert cg.stages_by_id["stage_b"].kind == :coding
      assert cg.stages_by_id["stage_b"].agent_role == :coder
    end
  end

  describe "D-62 validator 6 — signature must be null" do
    test "rejects signature populated with an object" do
      m = put_in(base_map(), ["signature"], %{"alg" => "x"})
      assert {:error, {:graph_invalid, :signature_must_be_null, _}} = Compiler.compile(m)
    end

    test "rejects signature populated with a string" do
      m = put_in(base_map(), ["signature"], "already-signed")
      assert {:error, {:graph_invalid, :signature_must_be_null, _}} = Compiler.compile(m)
    end

    test "accepts signature: null (v1 invariant)" do
      assert {:ok, _} = Compiler.compile(put_in(base_map(), ["signature"], nil))
    end
  end

  describe "D-62 validator 1 — single entry node" do
    test "rejects workflow with no entry node" do
      # Two stages, each depending on the other — no entry.
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            Map.put(s, "depends_on", ["stage_b"]),
            %{
              "id" => "stage_b",
              "kind" => "coding",
              "agent_role" => "coder",
              "depends_on" => ["stage_a"],
              "timeout_seconds" => 60,
              "retry_policy" => %{
                "max_attempts" => 3,
                "backoff" => "exponential",
                "base_delay_seconds" => 5
              },
              "sandbox" => "readwrite"
            }
          ]
        end)

      assert {:error, {:graph_invalid, :no_entry_node, _}} = Compiler.compile(m)
    end

    test "rejects workflow with multiple entry nodes" do
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            s,
            %{
              "id" => "stage_b",
              "kind" => "coding",
              "agent_role" => "coder",
              "depends_on" => [],
              "timeout_seconds" => 60,
              "retry_policy" => %{
                "max_attempts" => 3,
                "backoff" => "exponential",
                "base_delay_seconds" => 5
              },
              "sandbox" => "readwrite"
            }
          ]
        end)

      assert {:error, {:graph_invalid, :multiple_entry_nodes, detail}} = Compiler.compile(m)
      assert detail.count == 2
    end
  end

  describe "D-62 validators 2 + 3 — toposort + missing-dep" do
    test "rejects workflow with missing dep" do
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [%{s | "depends_on" => []} |> Map.put("id", "real"), real_stage_b_with_missing_dep()]
        end)

      assert {:error, {:graph_invalid, {:missing_dep, "ghost"}, _}} = Compiler.compile(m)
    end

    test "rejects workflow with a downstream cycle (valid entry node + cycle)" do
      # start -> a <-> b (2-cycle downstream; toposort must catch it
      # despite a valid entry node, because validator 1 passes)
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            %{s | "id" => "start"},
            build_stage("loop_a", "coding", "coder", ["start", "loop_b"], "readwrite"),
            build_stage("loop_b", "testing", "tester", ["loop_a"], "readonly")
          ]
        end)

      assert {:error, {:graph_invalid, :cycle, _}} = Compiler.compile(m)
    end
  end

  describe "D-62 validator 4 — on_failure must be a strict ancestor" do
    test "accepts on_failure pointing to a topological ancestor" do
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          b = build_stage("stage_b", "coding", "coder", ["stage_a"], "readwrite")
          b = Map.put(b, "on_failure", %{"action" => "route", "to" => "stage_a", "attach" => "plan_ref"})
          [s, b]
        end)

      assert {:ok, cg} = Compiler.compile(m)
      assert cg.stages_by_id["stage_b"].on_failure.to == "stage_a"
    end

    test "rejects on_failure pointing to a descendant (forward edge)" do
      # a -> b -> c; a.on_failure -> c (forward/descendant)
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            Map.put(s, "on_failure", %{"action" => "route", "to" => "stage_c", "attach" => "test_ref"}),
            build_stage("stage_b", "coding", "coder", ["stage_a"], "readwrite"),
            build_stage("stage_c", "testing", "tester", ["stage_b"], "readonly")
          ]
        end)

      assert {:error, {:graph_invalid, :on_failure_forward_edge, detail}} =
               Compiler.compile(m)

      assert detail.from == "stage_a"
      assert detail.to == "stage_c"
    end

    test "rejects on_failure pointing to self (equal topological position)" do
      # Strict-less-than is the only valid ancestor relation (threat T3).
      m =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [
            Map.put(s, "on_failure", %{"action" => "route", "to" => "stage_a", "attach" => "self_ref"})
          ]
        end)

      assert {:error, {:graph_invalid, :on_failure_forward_edge, _}} = Compiler.compile(m)
    end
  end

  describe "D-62 validator 5 — every kind has a contract" do
    test "accepts all 5 registered kinds" do
      for kind <- ~w(planning coding testing verifying merge) do
        m = put_in(base_map(), ["spec", "stages"], [
              build_stage("only_stage", kind, compatible_agent_role_for(kind), [], "readonly")
            ])

        assert {:ok, _} = Compiler.compile(m), "kind=#{kind} must compile"
      end
    end
  end

  describe "checksum (D-94 rehydration integrity)" do
    test "is deterministic across two compilations of the same input" do
      {:ok, cg1} = Compiler.compile(base_map())
      {:ok, cg2} = Compiler.compile(base_map())
      assert cg1.checksum == cg2.checksum
    end

    test "changes when a stage id changes" do
      {:ok, cg1} = Compiler.compile(base_map())

      m2 =
        update_in(base_map(), ["spec", "stages"], fn [s] ->
          [%{s | "id" => "stage_b"}]
        end)

      {:ok, cg2} = Compiler.compile(m2)
      refute cg1.checksum == cg2.checksum
    end

    test "changes when caps change" do
      {:ok, cg1} = Compiler.compile(base_map())
      m2 = put_in(base_map(), ["spec", "caps", "max_retries"], 5)
      {:ok, cg2} = Compiler.compile(m2)
      refute cg1.checksum == cg2.checksum
    end

    test "changes when model_profile changes" do
      {:ok, cg1} = Compiler.compile(base_map())
      m2 = put_in(base_map(), ["spec", "model_profile"], "python_cli")
      {:ok, cg2} = Compiler.compile(m2)
      refute cg1.checksum == cg2.checksum
    end

    test "is 64 lowercase hex characters" do
      {:ok, cg} = Compiler.compile(base_map())
      assert cg.checksum =~ ~r/^[0-9a-f]{64}$/
    end
  end

  # -- helpers ------------------------------------------------------------

  defp build_stage(id, kind, role, depends_on, sandbox) do
    %{
      "id" => id,
      "kind" => kind,
      "agent_role" => role,
      "depends_on" => depends_on,
      "timeout_seconds" => 60,
      "retry_policy" => %{
        "max_attempts" => 3,
        "backoff" => "exponential",
        "base_delay_seconds" => 5
      },
      "sandbox" => sandbox
    }
  end

  defp real_stage_b_with_missing_dep do
    build_stage("stage_b", "coding", "coder", ["ghost"], "readwrite")
  end

  defp compatible_agent_role_for("planning"), do: "planner"
  defp compatible_agent_role_for("coding"), do: "coder"
  defp compatible_agent_role_for("testing"), do: "tester"
  defp compatible_agent_role_for("verifying"), do: "qa_verifier"
  # D-61 separate axes: merge kind + coder role is canonical.
  defp compatible_agent_role_for("merge"), do: "coder"
end
