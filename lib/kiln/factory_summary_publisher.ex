defmodule Kiln.FactorySummaryPublisher do
  @moduledoc """
  Subscribes to **`runs:board`** and debounces recomputation of factory-wide
  counts onto the low-volume **`factory:summary`** topic (UI-07).
  """

  use GenServer

  alias Kiln.Runs
  alias Kiln.Runs.Run

  @board_topic "runs:board"
  @summary_topic "factory:summary"
  @debounce_ms 300

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(Kiln.PubSub, @board_topic)
    _ = Process.send_after(self(), :flush, 0)
    {:ok, %{timer: nil}}
  end

  @impl true
  def handle_info({:run_state, _}, state) do
    {:noreply, schedule_flush_state(state)}
  end

  def handle_info(:flush, state) do
    summary = compute_summary()
    Phoenix.PubSub.broadcast(Kiln.PubSub, @summary_topic, {:factory_summary, summary})
    {:noreply, %{state | timer: nil}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp schedule_flush_state(%{timer: nil} = state) do
    ref = Process.send_after(self(), :flush, @debounce_ms)
    %{state | timer: ref}
  end

  defp schedule_flush_state(%{timer: ref} = state) do
    _ = Process.cancel_timer(ref)
    ref = Process.send_after(self(), :flush, @debounce_ms)
    %{state | timer: ref}
  end

  defp compute_summary do
    runs = Runs.list_for_board()

    active =
      Enum.count(runs, fn %Run{state: s} -> s in Run.active_states() end)

    blocked = Enum.count(runs, fn %Run{state: s} -> s == :blocked end)
    %{active: active, blocked: blocked}
  end
end
