defmodule Kiln.Agents.TelemetryHandler do
  @moduledoc """
  Converts adapter telemetry (`[:kiln, :agent, :call, *]`) into audit
  events so every LLM call that dispatched a fallback model is
  operator-visible (OPS-02 / D-106 - silent-fallback-impossible
  guardrail).

  Writes ONE `model_routing_fallback` audit row per `:stop` event
  whose metadata satisfies `actual_model_used != requested_model`.
  When the two match (normal happy path), nothing is written.

  `:start` and `:exception` events are accepted but generate no
  audit emission in P3 - their handlers exist so
  `:telemetry.attach_many/4` covers the full lifecycle without fanning
  out to orphaned `function_clause` matches at the producer side.

  Attached at boot in `Kiln.Application.start/2` (wired in Wave 5).
  Mirrors `Kiln.Telemetry.ObanHandler.attach/0` - ETS-backed, not
  process-based, so it is NOT a supervision-tree child.
  """

  require Logger

  @handler_id {__MODULE__, :agent_call_lifecycle}

  @doc """
  Attach the handler to the three `:kiln.agent.call.*` telemetry
  events. Idempotent: returns `{:error, :already_exists}` if already
  attached (e.g. from a prior call during tests).
  """
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach_many(
      @handler_id,
      [
        [:kiln, :agent, :call, :start],
        [:kiln, :agent, :call, :stop],
        [:kiln, :agent, :call, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Detach the handler. Used by test teardown; rarely called in
  production paths.
  """
  @spec detach() :: :ok | {:error, :not_found}
  def detach, do: :telemetry.detach(@handler_id)

  @doc false
  @spec handle_event(list(), map(), map(), term()) :: :ok
  def handle_event([:kiln, :agent, :call, :stop], measurements, metadata, _config) do
    requested = metadata[:requested_model]
    actual = metadata[:actual_model_used]

    if is_binary(requested) and is_binary(actual) and requested != actual do
      correlation_id = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

      wall_clock_ms =
        case measurements[:duration] do
          nil -> 0
          d when is_integer(d) -> System.convert_time_unit(d, :native, :millisecond)
          _ -> 0
        end

      payload = %{
        "requested_model" => to_string(requested),
        "actual_model_used" => to_string(actual),
        "fallback_reason" => to_string(metadata[:fallback_reason] || "http_429"),
        "tier_crossed" => tier_crossed?(requested, actual),
        "attempt_number" => metadata[:attempt_number] || 1,
        "wall_clock_ms" => wall_clock_ms
      }

      payload =
        payload
        |> maybe_put("provider", metadata[:provider])
        |> maybe_put("role", metadata[:role])
        |> maybe_put("provider_http_status", metadata[:provider_http_status])

      _ =
        Kiln.Audit.append(%{
          event_kind: :model_routing_fallback,
          run_id: metadata[:run_id],
          stage_id: metadata[:stage_id],
          correlation_id: correlation_id,
          payload: payload
        })
    end

    :ok
  end

  def handle_event([:kiln, :agent, :call, :start], _measurements, _metadata, _config), do: :ok
  def handle_event([:kiln, :agent, :call, :exception], _measurements, _metadata, _config), do: :ok
  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value) when is_binary(value), do: Map.put(map, key, value)
  defp maybe_put(map, key, value) when is_atom(value), do: Map.put(map, key, to_string(value))
  defp maybe_put(map, key, value) when is_integer(value), do: Map.put(map, key, value)

  defp tier_crossed?(requested, actual) when is_binary(requested) and is_binary(actual) do
    tier_of(requested) != tier_of(actual)
  end

  defp tier_crossed?(_, _), do: false

  defp tier_of("claude-opus" <> _), do: :opus
  defp tier_of("claude-sonnet" <> _), do: :sonnet
  defp tier_of("claude-haiku" <> _), do: :haiku
  defp tier_of("gpt-4o-mini" <> _), do: :mini
  defp tier_of("gpt-4o" <> _), do: :flagship
  defp tier_of("gemini-2.5-flash" <> _), do: :mini
  defp tier_of("gemini-2.5-pro" <> _), do: :flagship
  defp tier_of(_), do: :unknown
end
