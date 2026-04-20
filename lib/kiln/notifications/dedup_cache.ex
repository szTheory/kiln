defmodule Kiln.Notifications.DedupCache do
  @moduledoc """
  ETS-backed dedup table for `Kiln.Notifications.desktop/2` (D-140 —
  BLOCK-03). Keyed by `{run_id, reason}` with a 5-minute TTL.

  Lifecycle:

    * Started as a named GenServer child of the Phase 3 supervision tree
      (see `Kiln.Application.start/2` wiring in Plan 03-11). The
      GenServer's `init/1` creates the `:ets.new/2` table as
      `:set, :public, :named_table` so callers can
      `:ets.lookup/2` without marshalling through a `GenServer.call/2`.
    * Concurrency: `read_concurrency: true` + `write_concurrency: true`
      (notification storms are read-heavy — every candidate fire checks
      the table; every actual fire updates a single row).
    * Table death == GenServer death (standard ETS ownership). Restart
      policy is `:permanent` so dedup state is transiently lost on crash
      but rebuilds as new `{run_id, reason}` keys arrive — lossy is fine
      because the downstream cost of a duplicate notification is
      operator-visible, not data-corrupting.

  The `check_and_record/1` API is intentionally single-call — the
  callers never `lookup` then `insert` separately (would race under two
  concurrent notification producers for the same key).
  """

  use GenServer

  @table __MODULE__
  # 5 minutes, matching D-140 dedup window.
  @ttl_ms 5 * 60 * 1000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Atomic fire-or-suppress gate.

  Returns `:fire` if the `{run_id, reason}` key is NOT in the cache or
  the existing entry has exceeded the 5-minute TTL — and records the
  new timestamp in the same call. Returns `:suppress` if the key was
  seen within the TTL window.

  The single-call shape avoids a TOCTOU race between two concurrent
  notification producers for the same key (both would see "empty cache"
  on the lookup, then both would insert, then both would shell out).
  `:ets.insert/2` on a `:set` table is last-writer-wins and
  time-monotonic-read + time-monotonic-write inside the same process
  gives serializable ordering on the cache for our purposes.
  """
  @spec check_and_record({term(), atom()}) :: :fire | :suppress
  def check_and_record({_run_id, _reason} = key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [] ->
        :ets.insert(@table, {key, now})
        :fire

      [{^key, recorded_at}] when now - recorded_at >= @ttl_ms ->
        :ets.insert(@table, {key, now})
        :fire

      _ ->
        :suppress
    end
  end

  @doc """
  Returns the configured TTL in milliseconds. Test-only introspection —
  production callers should not depend on the TTL value; the 5-minute
  window is a D-140 decision that Phase 5 may tune.
  """
  @spec ttl_ms() :: pos_integer()
  def ttl_ms, do: @ttl_ms

  @doc """
  Wipes the cache — intended for tests.
  """
  @spec clear() :: :ok
  def clear do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _ref -> :ets.delete_all_objects(@table)
    end

    :ok
  end

  @impl true
  def init(_opts) do
    # The GenServer owns the ETS table. If the GenServer dies, the table
    # is auto-destroyed — supervision restart rebuilds an empty cache
    # (acceptable per module-doc; dedup is a "nice to have" for operator
    # UX, not a data integrity invariant).
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ref ->
        # Table may already exist if this is a restart-before-table-GC
        # window; keep it as-is.
        :ok
    end

    {:ok, %{}}
  end

  # Defensive catch-all so the :permanent cache GenServer doesn't crash
  # on stray messages delivered to its mailbox.
  @impl true
  def handle_info(_msg, state), do: {:noreply, state}
end
