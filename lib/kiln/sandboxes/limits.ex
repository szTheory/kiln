defmodule Kiln.Sandboxes.Limits do
  @moduledoc """
  Per-stage-kind sandbox resource limits (D-112), loaded from
  `priv/sandbox/limits.yaml` into `:persistent_term`.

  `for_stage/1` returns the map for a stage kind and falls back to the
  default profile for unknown kinds.
  """

  require Logger

  @term_key {__MODULE__, :limits_table}
  @yaml_path Path.expand("../../../priv/sandbox/limits.yaml", __DIR__)
  @external_resource @yaml_path

  @spec load!() :: :ok
  def load! do
    case YamlElixir.read_from_file(@yaml_path) do
      {:ok, table} when is_map(table) ->
        :persistent_term.put({__MODULE__, :limits_table}, table)
        :ok

      {:error, reason} ->
        raise "Kiln.Sandboxes.Limits could not load #{@yaml_path}: #{inspect(reason)}"
    end
  end

  @spec for_stage(atom() | String.t()) :: map()
  def for_stage(stage_kind) do
    table = :persistent_term.get(@term_key, %{})
    key = to_string(stage_kind)

    case Map.get(table, key) do
      nil ->
        Logger.warning(
          "Kiln.Sandboxes.Limits: unknown stage kind #{inspect(stage_kind)}, using default"
        )

        Map.fetch!(table, "default")

      value ->
        value
    end
  end

  @spec all_stage_kinds() :: [String.t()]
  def all_stage_kinds do
    @term_key
    |> :persistent_term.get(%{})
    |> Map.keys()
  end
end
