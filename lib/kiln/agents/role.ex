defmodule Kiln.Agents.Role do
  @moduledoc """
  Shared behaviour for the seven fixed Phase 4 role `GenServer`s.

  Roles coordinate exclusively through `Kiln.WorkUnits` — no direct
  `Repo` writes and no per-work-unit processes.
  """

  @typedoc "One of the seven durable agent roles on `work_units`."
  @type role :: atom()

  @doc "The role this implementation serves."
  @callback role() :: role()

  @doc false
  @spec via(Ecto.UUID.t(), role()) :: {:via, Registry, {module(), tuple()}}
  def via(run_id, role) when is_binary(run_id) and is_atom(role) do
    {:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id, role}}}
  end

  defmacro __using__(role: role) do
    quote location: :keep do
      @behaviour Kiln.Agents.Role

      use GenServer

      alias Kiln.Agents.Role, as: RoleNaming
      alias Kiln.WorkUnits
      alias Kiln.WorkUnits.PubSub, as: WUPubSub

      @poll_interval_ms 100

      @impl Kiln.Agents.Role
      def role, do: unquote(role)

      @spec child_spec(keyword()) :: Supervisor.child_spec()
      def child_spec(opts) do
        run_id = Keyword.fetch!(opts, :run_id)

        %{
          id: {__MODULE__, run_id},
          start: {__MODULE__, :start_link, [opts]},
          restart: :permanent,
          shutdown: 5_000,
          type: :worker
        }
      end

      @spec start_link(keyword()) :: GenServer.on_start()
      def start_link(opts) do
        run_id = Keyword.fetch!(opts, :run_id)

        GenServer.start_link(__MODULE__, run_id, name: RoleNaming.via(run_id, unquote(role)))
      end

      @impl true
      def init(run_id) when is_binary(run_id) do
        :ok = Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.run_topic(run_id))
        :ok = maybe_seed_planner(run_id)

        {:ok, %{run_id: run_id}, {:continue, :schedule_tick}}
      end

      defp maybe_seed_planner(run_id) do
        case unquote(role) do
          :mayor ->
            case WorkUnits.seed_initial_planner_unit(run_id) do
              {:ok, _} -> :ok
              {:error, _} -> :ok
            end

          _ ->
            :ok
        end
      end

      @impl true
      def handle_continue(:schedule_tick, state) do
        schedule_tick()
        {:noreply, state}
      end

      defp schedule_tick do
        Process.send_after(self(), :tick, @poll_interval_ms)
      end

      @impl true
      def handle_info(:tick, state) do
        _ = try_claim(state)
        schedule_tick()
        {:noreply, state}
      end

      def handle_info({:work_unit, _payload}, state) do
        _ = try_claim(state)
        {:noreply, state}
      end

      def handle_info(_other, state), do: {:noreply, state}

      defp try_claim(%{run_id: run_id}) do
        WorkUnits.claim_next_ready(run_id, role())
      end
    end
  end
end
