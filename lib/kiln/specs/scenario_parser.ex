defmodule Kiln.Specs.ScenarioParser do
  @moduledoc """
  Parses markdown for fenced `kiln-scenario` blocks, decodes inner YAML, and
  validates **scenario IR v1** with JSV (SPEC-02).
  """

  @schema_path Path.expand("../../../priv/jsv/scenario_ir_v1.json", __DIR__)
  @external_resource @schema_path

  @root (case File.read(@schema_path) do
           {:ok, json} ->
             raw = Jason.decode!(json)

             JSV.build!(raw,
               default_meta: "https://json-schema.org/draft/2020-12/schema",
               formats: true
             )

           {:error, reason} ->
             raise "scenario_ir_v1 schema missing at #{@schema_path}: #{inspect(reason)}"
         end)

  @fence_re ~r/```kiln-scenario\s*\n(.*?)```/us

  @doc """
  Extract every ```kiln-scenario fenced block, YAML-decode, merge `scenarios`
  arrays, and JSV-validate the merged IR once.
  """
  @spec parse_document(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_document(markdown) when is_binary(markdown) do
    bodies =
      @fence_re
      |> Regex.scan(markdown, capture: :all_but_first)
      |> Enum.map(&hd/1)

    if bodies == [] do
      {:error, {:no_kiln_scenario_blocks, "no ```kiln-scenario fences found"}}
    else
      with {:ok, maps} <- decode_yaml_blocks(bodies),
           merged <- merge_scenarios(maps) do
        validate_merged_ir(merged)
      end
    end
  end

  defp validate_merged_ir(%{"scenarios" => []}) do
    {:error, {:no_scenarios, "merged IR has zero scenarios"}}
  end

  defp validate_merged_ir(merged) do
    with {:ok, validated} <- jsv_validate(merged),
         :ok <- validate_shell_steps(validated) do
      {:ok, validated}
    end
  end

  defp jsv_validate(merged) do
    case JSV.validate(merged, @root) do
      {:ok, validated} -> {:ok, validated}
      {:error, err} -> {:error, {:schema_invalid, JSV.normalize_error(err)}}
    end
  end

  defp validate_shell_steps(%{"scenarios" => scenarios}) when is_list(scenarios) do
    unsafe =
      scenarios
      |> Enum.flat_map(&List.wrap(Map.get(&1, "steps") || Map.get(&1, :steps)))
      |> Enum.find(&unsafe_shell_argv?/1)

    if unsafe do
      {:error, {:schema_invalid, %{message: "shell argv must not contain ';' or newlines"}}}
    else
      :ok
    end
  end

  defp validate_shell_steps(_), do: :ok

  defp unsafe_shell_argv?(step) do
    kind = Map.get(step, "kind") || Map.get(step, :kind)
    argv = Map.get(step, "argv") || Map.get(step, :argv)

    kind == "shell" && is_list(argv) && not Enum.all?(argv, &shell_arg_safe?/1)
  end

  defp shell_arg_safe?(s) when is_binary(s) do
    not String.contains?(s, ";") and not String.contains?(s, "\n") and
      not String.contains?(s, "\r")
  end

  defp shell_arg_safe?(_), do: false

  defp decode_yaml_blocks(bodies) do
    Enum.reduce_while(bodies, {:ok, []}, fn body, {:ok, acc} ->
      case YamlElixir.read_from_string(body) do
        {:ok, map} when is_map(map) ->
          {:cont, {:ok, [map | acc]}}

        {:error, %YamlElixir.ParsingError{} = err} ->
          {:halt, {:error, {:yaml_invalid, format_yaml_error(err)}}}

        {:error, other} ->
          {:halt, {:error, {:yaml_invalid, other}}}
      end
    end)
    |> case do
      {:ok, maps} -> {:ok, Enum.reverse(maps)}
      other -> other
    end
  end

  defp merge_scenarios(maps) do
    scenarios =
      maps
      |> Enum.flat_map(fn m ->
        List.wrap(Map.get(m, "scenarios") || Map.get(m, :scenarios))
      end)

    %{"scenarios" => scenarios}
  end

  defp format_yaml_error(%YamlElixir.ParsingError{} = err) do
    msg = Exception.message(err)
    line = Map.get(err, :line) || Map.get(err, "line")
    %{message: msg, line: line}
  end

  defp format_yaml_error(other), do: %{message: inspect(other), line: nil}
end
