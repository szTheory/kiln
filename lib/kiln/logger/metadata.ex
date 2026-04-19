defmodule Kiln.Logger.Metadata do
  @moduledoc """
  Block-style decorator for scoping Logger metadata to a function body
  on synchronous code paths. Resets metadata on block exit, even if the
  block raises.

      Kiln.Logger.Metadata.with_metadata([run_id: rid, stage_id: sid], fn ->
        Logger.info("stage started")
      end)

  For cross-process metadata propagation (`Task.async_stream`, Oban),
  use `Kiln.Telemetry.pack_ctx/0` + `Kiln.Telemetry.unpack_ctx/1`
  (D-45 explicit API).

  Also ships a `:logger` filter (`default_filter/2`) that guarantees the
  six D-46 mandatory keys render on every log line — missing keys default
  to the atom `:none`, which the JSON formatter serialises as the string
  `"none"` so grep pipelines see a consistent schema.
  """

  require Logger

  @mandatory_keys [:correlation_id, :causation_id, :actor, :actor_role, :run_id, :stage_id]

  @doc """
  Returns the six D-46 mandatory metadata keys. Exposed so callers can
  iterate without duplicating the list.
  """
  @spec mandatory_keys() :: [
          :actor | :actor_role | :causation_id | :correlation_id | :run_id | :stage_id,
          ...
        ]
  def mandatory_keys, do: @mandatory_keys

  @doc """
  Scopes a metadata keyword list to the supplied zero-arity function.
  The prior metadata is restored on exit (via `try/after`), even when
  `fun` raises.

  `meta` is merged via `Logger.metadata/1` so nested calls compose —
  inner calls override outer on key collision; keys absent from `meta`
  stay as set by the outer scope.
  """
  @spec with_metadata(keyword(), (-> any())) :: any()
  def with_metadata(meta, fun) when is_list(meta) and is_function(fun, 0) do
    prior = Logger.metadata()

    try do
      Logger.metadata(meta)
      fun.()
    after
      Logger.reset_metadata(prior)
    end
  end

  @doc """
  `:logger` filter that defaults the six D-46 mandatory metadata keys
  to the atom `:none` when they are absent from the log event's metadata.

  Wire via `config :logger, :default_handler, filters: [ ... ]` in
  `config/config.exs`. Returning the updated log event (rather than
  `:stop` / `:ignore`) lets the handler continue to the formatter.
  """
  @spec default_filter(:logger.log_event(), any()) :: :logger.log_event()
  def default_filter(%{meta: meta} = log_event, _extra) do
    filled =
      Enum.reduce(@mandatory_keys, meta, fn key, acc ->
        Map.put_new(acc, key, :none)
      end)

    %{log_event | meta: filled}
  end
end
