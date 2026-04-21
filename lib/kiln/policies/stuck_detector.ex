defmodule Kiln.Policies.StuckDetector do
  @moduledoc """
  GenServer hook called from inside `Kiln.Runs.Transitions.transition/3`
  AFTER the row lock (`SELECT ... FOR UPDATE`) and BEFORE the state
  column is updated (D-91).

  Phase 5 (OBS-04): `handle_call/3` delegates to **pure**
  `Kiln.Policies.StuckWindow` — **no** `Repo` calls here (nested-lock safe).

  Contract:

      check(ctx :: map()) :: {:ok, new_window :: list()} | {:halt, :stuck, payload :: map()}
  """

  use GenServer

  require Logger

  alias Kiln.Policies.StuckWindow

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec check(map()) :: {:ok, list()} | {:halt, atom(), map()}
  def check(ctx) when is_map(ctx), do: GenServer.call(__MODULE__, {:check, ctx})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:check, ctx}, _from, state) when is_map(ctx) do
    case ctx do
      %{run: run} when is_map(run) ->
        meta = Map.get(ctx, :meta, %{})
        stage = Map.get(meta, :stage_kind, Map.get(run, :state))
        fc = Map.get(meta, :failure_class, :unknown)
        prior = Map.get(run, :stuck_signal_window, []) || []

        {new_tuples, outcome} = StuckWindow.push_event(prior, stage, fc)

        maps =
          Enum.map(new_tuples, fn {s, f} ->
            %{"stage" => Atom.to_string(s), "failure_class" => Atom.to_string(f)}
          end)

        case outcome do
          :ok ->
            {:reply, {:ok, maps}, state}

          {:halt, halt} ->
            :telemetry.execute(
              [:kiln, :stuck_detector, :alarmed],
              %{count: 1},
              %{
                run_id: Map.get(run, :id),
                failure_class: fc,
                stage: stage
              }
            )

            {:reply, {:halt, :stuck, Map.put(halt, :stuck_signal_window, maps)}, state}
        end

      _ ->
        {:reply, {:ok, []}, state}
    end
  end
end
