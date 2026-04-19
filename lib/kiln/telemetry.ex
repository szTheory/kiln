defmodule Kiln.Telemetry do
  @moduledoc """
  Cross-process context propagation for Logger metadata (D-45).

  Pack the current process's six D-46 mandatory metadata keys into a
  serialisable map on the caller side, unpack in the spawned process
  (Task, Oban worker) so child log lines carry the same
  `correlation_id`, `causation_id`, `actor`, `actor_role`, `run_id`,
  and `stage_id` as the parent.

  Three APIs:

    * `pack_ctx/0` / `unpack_ctx/1` — explicit threading when you spawn
      your own process and want to restore parent metadata inside it.
    * `async_stream/3` — drop-in wrapper around `Task.async_stream/3`
      that pre-packs ctx and unpacks it inside each child task, so
      callers never forget to thread.
    * `pack_meta/0` — returns a `%{"kiln_ctx" => ...}` map intended as
      the `:meta` option of an `Oban.Job` at enqueue time; the
      `Kiln.Telemetry.ObanHandler` telemetry listener unpacks it
      inside the worker process.
  """

  alias Kiln.Logger.Metadata

  @doc """
  Snapshots the six D-46 mandatory keys from the current process's
  Logger metadata. Missing keys default to `:none`.

  Returned map has string keys so the same structure can round-trip
  through JSONB storage (Oban `Job.meta`) without coercion surprises.
  """
  @spec pack_ctx() :: %{String.t() => term()}
  def pack_ctx do
    meta = Logger.metadata()

    Map.new(Metadata.mandatory_keys(), fn key ->
      {Atom.to_string(key), Keyword.get(meta, key, :none)}
    end)
  end

  @doc """
  Restores the six D-46 mandatory keys into the current process's
  Logger metadata from a map previously produced by `pack_ctx/0`.

  Keys missing from the packed ctx default to `:none`. The string
  `"none"` (produced by JSONB round-trip of the atom `:none`) is
  normalised back to `:none` so formatter output stays stable across
  in-memory and Oban-persisted paths.
  """
  @spec unpack_ctx(map()) :: :ok
  def unpack_ctx(ctx) when is_map(ctx) do
    meta =
      Enum.map(Metadata.mandatory_keys(), fn key ->
        raw = Map.get(ctx, Atom.to_string(key), :none)
        {key, normalize(raw)}
      end)

    Logger.metadata(meta)
    :ok
  end

  @doc """
  Wrapper around `Task.async_stream/3` that pre-packs the current
  Logger metadata into each task's closure and unpacks inside the child
  process. Child log lines carry the parent's metadata without explicit
  threading at the call site (behavior LOG-01).

  Only extracts the fields needed into the closure — do NOT capture
  `socket`, `run`, or other large terms via outer-scope closures
  (ARCHITECTURE.md §13.5).
  """
  @spec async_stream(Enumerable.t(), (term() -> term()), keyword()) :: Enumerable.t()
  def async_stream(enumerable, fun, opts \\ []) when is_function(fun, 1) do
    ctx = pack_ctx()

    Task.async_stream(
      enumerable,
      fn item ->
        :ok = unpack_ctx(ctx)
        fun.(item)
      end,
      opts
    )
  end

  @doc """
  Enqueue-time helper: returns a map suitable for `Oban.Job`'s `:meta`
  option, wrapping the caller's Logger metadata under the `kiln_ctx`
  key. The `Kiln.Telemetry.ObanHandler` telemetry handler restores
  this ctx into the worker process's Logger metadata on
  `[:oban, :job, :start]` (behavior LOG-02).

      %{probe: probe_id}
      |> MyWorker.new(meta: Kiln.Telemetry.pack_meta())
      |> Oban.insert()
  """
  @spec pack_meta() :: %{String.t() => map()}
  def pack_meta do
    %{"kiln_ctx" => pack_ctx()}
  end

  # JSONB round-trip collapses the atom `:none` to the string `"none"`.
  # Normalise on unpack so downstream formatters see the atom uniformly
  # regardless of whether the ctx took the in-memory path (Task) or the
  # persisted path (Oban).
  defp normalize("none"), do: :none
  defp normalize(value), do: value
end
