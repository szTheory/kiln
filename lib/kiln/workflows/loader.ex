defmodule Kiln.Workflows.Loader do
  @moduledoc """
  Loads a workflow YAML file into a validated + compiled
  `%Kiln.Workflows.CompiledGraph{}`.

  Pipeline (D-62, D-63):

      YAML file → YamlElixir.read_from_file (atoms: false — default)
               → string-keyed map
               → Kiln.Workflows.SchemaRegistry.fetch(:workflow)
               → JSV.validate/2
               → Kiln.Workflows.Compiler.compile/1 (6 D-62 validators)
               → %CompiledGraph{}

  ## YAML parsing (D-63 / threat T1)

  `YamlElixir.read_from_file/1` is called WITHOUT options — the default
  `atoms: false` is essential. Overriding that default allows an
  adversarial YAML file with thousands of keys to exhaust the BEAM atom
  table (atom-table exhaustion is a module-global DoS vector; atoms are
  never GC'd). All downstream code uses string-keyed access (`raw["id"]`,
  not `raw.id`) for the same reason. `String.to_existing_atom/1` — not
  `String.to_atom/1` — is used by `Kiln.Workflows.Compiler` when
  converting kind/agent_role/sandbox values to atoms; those enums are
  bounded and already present in the compiled bytecode.

  ## Return shape

  `{:ok, %CompiledGraph{}}` on success.

  `{:error, reason}` otherwise, where `reason` is one of:

    * `{:yaml_parse, detail}` — file not found, parse error, non-map root
    * `{:schema_invalid, normalized_error_map}` — JSV rejected the shape
      (normalised through `JSV.normalize_error/1` so no raw JSV tuples
      reach the UI or audit log — D-63)
    * `{:graph_invalid, atom_or_tuple, detail_map}` — one of the 6 D-62
      Elixir-side validators rejected the workflow (see
      `Kiln.Workflows.Compiler.compile/1` for the full reason taxonomy)

  ## load!/1

  `load!/1` raises `RuntimeError` with the normalised reason in the
  message on any failure. Suitable for test setup and `mix run` smoke
  checks; production callers should use `load/1` + explicit error
  handling.
  """

  alias Kiln.Workflows.{CompiledGraph, Compiler, SchemaRegistry}

  @spec load(Path.t()) ::
          {:ok, CompiledGraph.t()}
          | {:error,
             {:yaml_parse, term()}
             | {:schema_invalid, map()}
             | {:graph_invalid, term(), map()}}
  def load(path) do
    with {:ok, raw} <- read_yaml(path),
         {:ok, _} <- validate_schema(raw),
         {:ok, compiled} <- Compiler.compile(raw) do
      {:ok, compiled}
    end
  end

  @spec load!(Path.t()) :: CompiledGraph.t()
  def load!(path) do
    case load(path) do
      {:ok, cg} ->
        cg

      {:error, reason} ->
        raise "Kiln.Workflows.load!/1 failed for #{inspect(path)}: #{inspect(reason)}"
    end
  end

  # -- private -------------------------------------------------------------

  defp read_yaml(path) do
    # D-63: no options passed → yaml_elixir's default atoms: false is used,
    # which keeps map keys as binaries. See threat model T1.
    case YamlElixir.read_from_file(path) do
      {:ok, map} when is_map(map) ->
        {:ok, map}

      {:ok, other} ->
        {:error, {:yaml_parse, {:not_a_map, other}}}

      {:error, err} ->
        {:error, {:yaml_parse, err}}
    end
  end

  defp validate_schema(raw) do
    case SchemaRegistry.fetch(:workflow) do
      {:ok, root} ->
        case JSV.validate(raw, root) do
          {:ok, _cast} ->
            {:ok, raw}

          {:error, err} ->
            {:error, {:schema_invalid, JSV.normalize_error(err)}}
        end

      {:error, :unknown_kind} ->
        {:error, {:schema_invalid, %{reason: "workflow schema not registered"}}}
    end
  end
end
