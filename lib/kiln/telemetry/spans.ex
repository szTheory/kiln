defmodule Kiln.Telemetry.Spans do
  @moduledoc false

  require OpenTelemetry.Tracer

  @string_limit 256

  @doc false
  def with_run_stage(attrs \\ %{}, fun) when is_map(attrs) and is_function(fun, 0) do
    OpenTelemetry.Tracer.with_span "kiln.run.stage", %{attributes: trim_map(attrs)} do
      fun.()
    end
  end

  @doc false
  def with_agent_call(attrs \\ %{}, fun) when is_map(attrs) and is_function(fun, 0) do
    OpenTelemetry.Tracer.with_span "kiln.agent.call", %{attributes: trim_map(attrs)} do
      fun.()
    end
  end

  @doc false
  def with_docker_op(attrs \\ %{}, fun) when is_map(attrs) and is_function(fun, 0) do
    OpenTelemetry.Tracer.with_span "kiln.docker.op", %{attributes: trim_map(attrs)} do
      fun.()
    end
  end

  @doc false
  def with_llm_request(attrs \\ %{}, fun) when is_map(attrs) and is_function(fun, 0) do
    OpenTelemetry.Tracer.with_span "kiln.llm.request", %{attributes: trim_map(attrs)} do
      fun.()
    end
  end

  defp trim_map(map) do
    Map.new(map, fn {k, v} -> {k, trim_val(v)} end)
  end

  defp trim_val(v) when is_binary(v), do: String.slice(v, 0, @string_limit)
  defp trim_val(v) when is_atom(v), do: v |> Atom.to_string() |> trim_val()
  defp trim_val(v), do: v |> to_string() |> trim_val()
end
