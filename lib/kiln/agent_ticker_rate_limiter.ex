defmodule Kiln.AgentTickerRateLimiter do
  @moduledoc """
  UI-09 — token bucket (per run, per wall-clock second) for **`agent_ticker`**
  fan-out. Backed by a public named **ETS** table created at app boot.
  """

  @table :kiln_agent_ticker_rl
  @max_per_second 10

  @doc "Creates the ETS table if missing. Idempotent."
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> :ok
    end

    :ok
  end

  @doc "Returns `true` if the event may be published; drops when over budget."
  @spec allow?(Ecto.UUID.t()) :: boolean()
  def allow?(run_id) when is_binary(run_id) do
    _ = ensure_table()
    second = System.system_time(:second)

    case :ets.lookup(@table, run_id) do
      [] ->
        :ets.insert(@table, {run_id, {1, second}})
        true

      [{^run_id, {n, ^second}}] when n >= @max_per_second ->
        false

      [{^run_id, {n, ^second}}] ->
        :ets.insert(@table, {run_id, {n + 1, second}})
        true

      [{^run_id, {_n, _old_second}}] ->
        :ets.insert(@table, {run_id, {1, second}})
        true
    end
  end
end
