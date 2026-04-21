defmodule Kiln.Runs.RunDirector do
  @moduledoc """
  `:permanent` singleton GenServer that owns per-run subtree hydration
  (D-92..D-96).

  `RunDirector` is the reason ORCH-04 "resumable after crash or
  redeploy" holds: on boot, every `runs` row whose state is
  non-terminal (`Run.active_states/0`) is matched against an in-memory
  monitor table; new rows get a fresh `Kiln.Runs.RunSubtree` spawned
  under `Kiln.Runs.RunSupervisor` and `Process.monitor`'d so a subtree
  crash is observed and logged.

  ## Staged boot (D-92)

  `init/1` returns `{:ok, state}` IMMEDIATELY and sends `:boot_scan`
  to itself asynchronously. Supervisor boot MUST NOT block on a
  database query — a long scan would delay `KilnWeb.Endpoint` binding
  its port past health-check deadlines. The first scan runs inside
  `handle_info(:boot_scan, _)` after the supervisor tree is fully
  up.

  ## Three drivers (D-92, D-96)

    * `:boot_scan` — async self-message sent from `init/1`. Happens
      exactly once after boot.
    * `:periodic_scan` — scheduled every 30 s via
      `Process.send_after/3`. Defensive against a node-restart race
      that could deliver a subtree collapse before the replacement
      `RunDirector` has completed its boot scan.
    * `{:DOWN, ref, :process, pid, reason}` — fires when a monitored
      subtree crashes. The dead pid is removed from the monitor
      table; the next periodic scan re-spawns the subtree for its
      run (or escalates the run per D-94 if the workflow file
      changed underfoot).

  ## D-94 workflow-checksum assertion on rehydration

  Before spawning a per-run subtree, `assert_workflow_unchanged/1`
  compares the current on-disk workflow's compiled sha256 against
  `runs.workflow_checksum` (frozen at run start). Mismatch — or the
  workflow file is missing / fails to load — transitions the run to
  `:escalated` with `reason: :workflow_changed` via
  `Kiln.Runs.Transitions.transition/3` (audit-paired, PubSub-
  broadcast). This is the v1 integrity mechanism for workflow
  mutation; v2 WFE-02 will add cryptographic signatures.

  ## Idempotent periodic scan

  `do_scan/1` filters out already-monitored runs via a `MapSet`
  membership check over the monitor table's run_id values. A burst
  of `:periodic_scan` messages (or a `:boot_scan` followed immediately
  by `:periodic_scan`) will NOT double-spawn subtrees.

  ## Crash recovery

  `RunDirector` is stateless — `init/1` rebuilds the monitor table
  from Postgres via the boot scan, so a `:permanent` restart after
  a bug-induced crash simply picks up where the previous instance
  left off. Peer infra children (`Repo`, `Oban`, `RunSupervisor`,
  already-live per-run subtrees) are untouched under `:one_for_one`.

  ## Test-isolation race (threat T6)

  Tests that drive rehydration MUST `use Kiln.RehydrationCase` and
  call `reset_run_director_for_test/0` in `setup`. The helper forces
  the director's Repo connection into the test's sandbox BEFORE
  sending a fresh `:boot_scan`, eliminating the pre-sandbox-allow
  race (see `test/support/rehydration_case.ex`).
  """

  use GenServer
  require Logger

  alias Kiln.Runs
  alias Kiln.Runs.{RunSubtree, RunSupervisor}

  @periodic_scan_ms 30_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec start_run(Ecto.UUID.t()) :: {:ok, Kiln.Runs.Run.t()} | no_return()
  def start_run(run_id) when is_binary(run_id) do
    run = Runs.get!(run_id)

    case missing_provider_keys(run) do
      [] ->
        Kiln.Runs.Transitions.transition(run.id, :planning)

      missing ->
        maybe_notify_missing_key(run.id, missing)

        Kiln.Blockers.raise_block(:missing_api_key, run.id, %{
          provider_keys_missing: Enum.map(missing, &Atom.to_string/1)
        })
    end
  end

  @impl true
  def init(_opts) do
    # D-92 — supervisor boot NEVER blocks on the scan. Defer to a
    # self-message so `Kiln.Application.start/2` returns promptly.
    send(self(), :boot_scan)
    # state.monitors is %{pid => {monitor_ref, run_id}}
    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_info(:boot_scan, state) do
    state = do_scan(state)
    Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
    {:noreply, state}
  end

  def handle_info(:periodic_scan, state) do
    state = do_scan(state)
    Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{monitors: mons} = state) do
    case Map.pop(mons, pid) do
      {nil, _} ->
        # DOWN from a pid we never monitored — ignore.
        {:noreply, state}

      {{_ref, run_id}, remaining} ->
        Logger.warning("run subtree died; will rehydrate on next scan",
          run_id: run_id,
          reason: inspect(reason)
        )

        {:noreply, %{state | monitors: remaining}}
    end
  end

  # Catch-all for unexpected messages — don't crash the director on a
  # stray message (would :permanent-restart + loop).
  def handle_info(_msg, state), do: {:noreply, state}

  # -- private helpers ----------------------------------------------------

  defp do_scan(state) do
    active = Runs.list_active()

    already =
      state.monitors
      |> Map.values()
      |> Enum.map(fn {_ref, run_id} -> run_id end)
      |> MapSet.new()

    Enum.reduce(active, state, fn run, acc ->
      if MapSet.member?(already, run.id) do
        acc
      else
        case spawn_subtree(run) do
          {:ok, pid} ->
            ref = Process.monitor(pid)
            %{acc | monitors: Map.put(acc.monitors, pid, {ref, run.id})}

          {:error, :workflow_changed} ->
            # Run already escalated with reason :workflow_changed by
            # assert_workflow_unchanged/1 — do not add a monitor.
            acc

          {:error, reason} ->
            Logger.error("failed to spawn run subtree",
              run_id: run.id,
              reason: inspect(reason)
            )

            acc
        end
      end
    end)
  end

  defp spawn_subtree(run) do
    case assert_workflow_unchanged(run) do
      :ok ->
        DynamicSupervisor.start_child(RunSupervisor, {RunSubtree, run_id: run.id})

      {:error, :workflow_changed} ->
        _ =
          Kiln.Runs.Transitions.transition(run.id, :escalated, %{reason: :workflow_changed})

        {:error, :workflow_changed}
    end
  end

  # D-94 — compute the current on-disk workflow checksum and compare
  # against runs.workflow_checksum (frozen at run start).
  defp assert_workflow_unchanged(run) do
    path = Path.join(["priv/workflows", "#{run.workflow_id}.yaml"])

    case File.exists?(path) do
      false ->
        Logger.error("workflow file missing for rehydration",
          run_id: run.id,
          path: path
        )

        # Treat missing as changed — force escalation. Operator sees a
        # typed, audit-visible signal rather than the subtree silently
        # spawning against nothing.
        {:error, :workflow_changed}

      true ->
        case Kiln.Workflows.load(path) do
          {:ok, compiled} ->
            if compiled.checksum == run.workflow_checksum do
              :ok
            else
              {:error, :workflow_changed}
            end

          {:error, _reason} ->
            {:error, :workflow_changed}
        end
    end
  end

  defp missing_provider_keys(run) do
    run.model_profile_snapshot
    |> required_provider_keys()
    |> Enum.reject(&Kiln.Secrets.present?/1)
    |> Enum.uniq()
  end

  defp required_provider_keys(%{"profile" => profile} = snapshot) when is_binary(profile) do
    roles =
      case Enum.find(Kiln.ModelRegistry.all_presets(), &(Atom.to_string(&1) == profile)) do
        nil -> snapshot["roles"] || %{}
        preset -> Kiln.ModelRegistry.resolve(preset)
      end

    roles
    |> Map.values()
    |> Enum.map(&model_id_from_role_spec/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&provider_key_for_model/1)
  end

  defp required_provider_keys(%{"roles" => roles}) when is_map(roles) do
    roles
    |> Map.values()
    |> Enum.map(&model_id_from_role_spec/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&provider_key_for_model/1)
  end

  defp required_provider_keys(_), do: []

  defp model_id_from_role_spec(model) when is_binary(model), do: model
  defp model_id_from_role_spec(%{model: model}) when is_binary(model), do: model
  defp model_id_from_role_spec(%{"model" => model}) when is_binary(model), do: model
  defp model_id_from_role_spec(_), do: nil

  defp provider_key_for_model("claude-" <> _), do: :anthropic_api_key
  defp provider_key_for_model("gpt-" <> _), do: :openai_api_key
  defp provider_key_for_model("gemini-" <> _), do: :google_api_key

  defp provider_key_for_model(model) when is_binary(model) do
    cond do
      String.contains?(model, "sonnet") or String.contains?(model, "haiku") or
          String.contains?(model, "opus") ->
        :anthropic_api_key

      String.contains?(model, "llama") or String.contains?(model, "ollama") ->
        :ollama_host

      true ->
        :anthropic_api_key
    end
  end

  defp maybe_notify_missing_key(run_id, missing) do
    if Code.ensure_loaded?(Kiln.Notifications) and
         function_exported?(Kiln.Notifications, :desktop, 2) and
         :ets.whereis(Kiln.Notifications.DedupCache) != :undefined do
      Kiln.Notifications.desktop(:missing_api_key, %{
        run_id: run_id,
        provider_keys_missing: Enum.map_join(missing, ",", &Atom.to_string/1)
      })
    else
      :ok
    end
  end
end
