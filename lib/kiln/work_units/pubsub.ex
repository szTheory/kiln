defmodule Kiln.WorkUnits.PubSub do
  @moduledoc """
  Topic helpers and post-commit broadcast helpers for work-unit
  coordination (Phase 4 contract).
  """

  @global_topic "work_units"

  @doc false
  def global_topic, do: @global_topic

  @doc "Per-unit topic: `work_units:<id>`"
  @spec unit_topic(Ecto.UUID.t()) :: String.t()
  def unit_topic(id), do: "work_units:#{id}"

  @doc "Per-run topic: `work_units:run:<run_id>`"
  @spec run_topic(Ecto.UUID.t()) :: String.t()
  def run_topic(run_id), do: "work_units:run:#{run_id}"

  @doc """
  Broadcasts a committed work-unit change on all three topics.

  `message` must remain small and stable for LiveView subscribers.
  """
  @spec broadcast_change(map()) :: :ok
  def broadcast_change(%{id: id, run_id: run_id} = payload) do
    msg = {:work_unit, payload}

    Phoenix.PubSub.broadcast(Kiln.PubSub, @global_topic, msg)
    Phoenix.PubSub.broadcast(Kiln.PubSub, unit_topic(id), msg)
    Phoenix.PubSub.broadcast(Kiln.PubSub, run_topic(run_id), msg)
    :ok
  end
end
