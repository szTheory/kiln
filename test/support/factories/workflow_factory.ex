defmodule Kiln.Factory.Workflow do
  @moduledoc """
  LIVE ex_machina factory for workflow **raw maps** (pre-compilation).

  Phase 2 Plan 01's `Kiln.Workflows.Loader` (not yet shipped) accepts a
  string-keyed map parsed from YAML by `YamlElixir.read_from_file/2`; this
  factory produces exactly that shape so downstream unit tests can skip the
  YAML-parse step and drive the loader/validator/compiler with synthetic
  inputs.

  Unlike `Kiln.Factory.Run`, `Kiln.Factory.StageRun`, and
  `Kiln.Factory.Artifact` — which ship as SHELLS in Wave 0 and are filled
  in by Plans 02/03 once their Ecto schemas land — this factory is LIVE on
  day one because workflow maps are raw data, not Ecto-schema-backed rows.

  This module uses `use ExMachina` (no Ecto), not `use ExMachina.Ecto`.

  Exposed factory functions (callable via `ExMachina`'s `build/1,2`,
  `params_for/1,2`, etc.):

    * `workflow_map/0` — canonical good workflow map matching
      `test/support/fixtures/workflows/minimal_two_stage.yaml` shape
      (D-55..D-59 — all required keys present, one entry node, no
      `on_failure`).
    * `cyclic_workflow_map/0` — 3-stage cycle (`a -> b -> c -> a`) for
      toposort rejection tests.
    * `invalid_kind_workflow_map/0` — a stage with
      `kind: "bogus_kind_not_in_enum"` for JSV enum-rejection tests.

  Example:

      import Kiln.Factory.Workflow

      map = build(:workflow_map)
      # => %{"apiVersion" => "kiln.dev/v1", "id" => "minimal_two_stage", ...}

      cyclic = build(:cyclic_workflow_map)
      # a -> b -> c -> a

      invalid = build(:invalid_kind_workflow_map)
      # first stage has kind "bogus_kind_not_in_enum"
  """

  use ExMachina

  @doc """
  Canonical good workflow map matching D-55..D-59 shape (all string keys —
  mirrors what `YamlElixir.read_from_file/2` returns with no `atoms:` flag).
  """
  def workflow_map_factory do
    %{
      "apiVersion" => "kiln.dev/v1",
      "id" => "minimal_two_stage",
      "version" => 1,
      "metadata" => %{
        "description" => "Canonical minimal two-stage workflow (factory-built).",
        "author" => "kiln-test-suite",
        "tags" => ["test", "factory"]
      },
      "signature" => nil,
      "spec" => %{
        "caps" => %{
          "max_retries" => 3,
          "max_tokens_usd" => 1.00,
          "max_elapsed_seconds" => 600,
          "max_stage_duration_seconds" => 300
        },
        "model_profile" => "elixir_lib",
        "stages" => [
          %{
            "id" => "plan",
            "kind" => "planning",
            "agent_role" => "planner",
            "depends_on" => [],
            "timeout_seconds" => 300,
            "retry_policy" => %{
              "max_attempts" => 3,
              "backoff" => "exponential",
              "base_delay_seconds" => 5
            },
            "sandbox" => "readonly"
          },
          %{
            "id" => "code",
            "kind" => "coding",
            "agent_role" => "coder",
            "depends_on" => ["plan"],
            "timeout_seconds" => 300,
            "retry_policy" => %{
              "max_attempts" => 3,
              "backoff" => "exponential",
              "base_delay_seconds" => 5
            },
            "sandbox" => "readwrite"
          }
        ]
      }
    }
  end

  @doc """
  3-stage cycle (`a -> b -> c -> a`) — exercises D-62 validator 2 (toposort
  must succeed) and `:digraph_utils.is_acyclic/1` rejection.
  """
  def cyclic_workflow_map_factory do
    workflow_map_factory()
    |> Map.put("id", "cyclic")
    |> put_in(["metadata", "description"], "Cyclic 3-stage graph (rejection fixture).")
    |> put_in(["spec", "stages"], [
      %{
        "id" => "a",
        "kind" => "planning",
        "agent_role" => "planner",
        "depends_on" => ["c"],
        "timeout_seconds" => 300,
        "retry_policy" => %{
          "max_attempts" => 3,
          "backoff" => "exponential",
          "base_delay_seconds" => 5
        },
        "sandbox" => "readonly"
      },
      %{
        "id" => "b",
        "kind" => "coding",
        "agent_role" => "coder",
        "depends_on" => ["a"],
        "timeout_seconds" => 300,
        "retry_policy" => %{
          "max_attempts" => 3,
          "backoff" => "exponential",
          "base_delay_seconds" => 5
        },
        "sandbox" => "readwrite"
      },
      %{
        "id" => "c",
        "kind" => "testing",
        "agent_role" => "tester",
        "depends_on" => ["b"],
        "timeout_seconds" => 300,
        "retry_policy" => %{
          "max_attempts" => 3,
          "backoff" => "exponential",
          "base_delay_seconds" => 5
        },
        "sandbox" => "readonly"
      }
    ])
  end

  @doc """
  Workflow with an invalid `kind` value (`"bogus_kind_not_in_enum"`) on its
  first stage — exercises JSV enum rejection at schema-validation time.
  """
  def invalid_kind_workflow_map_factory do
    base = workflow_map_factory()

    stages =
      base
      |> get_in(["spec", "stages"])
      |> List.update_at(0, &Map.put(&1, "kind", "bogus_kind_not_in_enum"))

    base
    |> Map.put("id", "invalid_kind")
    |> put_in(["metadata", "description"], "Invalid stage.kind (factory-built).")
    |> put_in(["spec", "stages"], stages)
  end
end
