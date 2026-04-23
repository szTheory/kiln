defmodule Kiln.OperatorNudgeLimiter do
  @moduledoc """
  ETS-backed cooldown + per-hour cap for operator nudges (Phase 19 FEEDBACK-01).
  """

  @table :kiln_operator_nudge_limiter

  @doc "Creates the ETS table if missing. Idempotent."
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> :ok
    end

    :ok
  end

  @doc """
  Returns `:ok` when the caller may accept a nudge, or `{:error, :rate_limited}`.
  Does not mutate state — call `record_accept/2` after a successful audit append.
  """
  @spec check(Ecto.UUID.t(), pos_integer(), pos_integer(), pos_integer()) ::
          :ok | {:error, :rate_limited}
  def check(run_id, now_unix, cooldown_seconds \\ 20, max_per_hour \\ 30)
      when is_binary(run_id) and is_integer(now_unix) do
    _ = ensure_table()
    hour = div(now_unix, 3600)

    case :ets.lookup(@table, run_id) do
      [] ->
        :ok

      [{^run_id, {last_accept, hour_bucket, count}}] ->
        cond do
          now_unix < last_accept + cooldown_seconds ->
            {:error, :rate_limited}

          hour_bucket != hour ->
            :ok

          count >= max_per_hour ->
            {:error, :rate_limited}

          true ->
            :ok
        end
    end
  end

  @doc "Records a successful accept for cooldown + hourly accounting."
  @spec record_accept(Ecto.UUID.t(), pos_integer()) :: :ok
  def record_accept(run_id, now_unix) when is_binary(run_id) and is_integer(now_unix) do
    _ = ensure_table()
    hour = div(now_unix, 3600)

    case :ets.lookup(@table, run_id) do
      [] ->
        :ets.insert(@table, {run_id, {now_unix, hour, 1}})

      [{^run_id, {_last, hour_bucket, count}}] ->
        if hour_bucket == hour do
          :ets.insert(@table, {run_id, {now_unix, hour, count + 1}})
        else
          :ets.insert(@table, {run_id, {now_unix, hour, 1}})
        end
    end

    :ok
  end
end
