defmodule Kiln.Application do
  @moduledoc false
  use Application

  alias Kiln.Agents.TelemetryHandler
  alias Kiln.Sandboxes.Limits
  alias Kiln.Telemetry.ObanHandler

  # D-42 (P1) / D-92..D-96 (Phase 2) + Phase 3/4 infra: the children list
  # is EXACTLY 13 post-boot (infra children + `KilnWeb.Endpoint`). Phase 1
  # locked the 7-child shape (D-42 "no DNSCluster, no stub Phase 2+
  # children"); Plan 02-07 extends the tree per D-92..D-96 by adding:
  #
  #   * `Kiln.Runs.RunSupervisor`    — DynamicSupervisor hosting
  #     per-run subtrees (D-95, max_children: 10).
  #   * `{Kiln.Runs.RunDirector, []}` — :permanent GenServer that
  #     owns boot-scan + periodic-scan + DOWN-reaction rehydration
  #     (D-92..D-96). init/1 defers the scan via `send(self(), :boot_scan)`
  #     so supervisor boot never blocks on a DB query.
  #   * `Kiln.Policies.StuckDetector` — :permanent GenServer invoked
  #     inside `Kiln.Runs.Transitions.transition/3` as a pre-state-
  #     change hook (D-91; no-op body in Phase 2, sliding-window body
  #     lands in Phase 5).
  #
  # Plan 02-06 shipped the staged-boot pattern (infra children →
  # BootChecks.run! → Endpoint); Phase 4 removes the global
  # `Kiln.Agents.SessionSupervisor` scaffold (per-run sessions only).
  # Post-boot `Supervisor.which_children(Kiln.Supervisor)` returns
  # EXACTLY 13 entries (asserted by test/kiln/application_test.exs).
  @impl true
  def start(_type, _args) do
    :ok = Limits.load!()

    opts = [strategy: :one_for_one, name: Kiln.Supervisor]

    case Supervisor.start_link(infra_children(), opts) do
      {:ok, sup_pid} ->
        # Stage 2: assert boot-time invariants (D-32). On failure, raise
        # Kiln.BootChecks.Error propagates up as {:error, ...} from
        # Application.start/2 and the BEAM exits with the message
        # printed to stderr.
        Kiln.BootChecks.run!()

        # Stage 3: attach the Oban telemetry handler (Plan 05). Telemetry
        # handlers are ETS-backed, not process-backed — they aren't
        # supervisor children, so this doesn't affect the 10-child count.
        # Idempotent: returns `{:error, :already_exists}` on re-attach
        # (tolerated so code-reload / iex restarts don't crash).
        _ = ObanHandler.attach()
        _ = TelemetryHandler.attach()

        # Stage 4: add `KilnWeb.Endpoint` as the final child. After this
        # call `Supervisor.which_children(Kiln.Supervisor)` returns
        # EXACTLY 13 entries (asserted by test/kiln/application_test.exs).
        {:ok, _endpoint_pid} = Supervisor.start_child(sup_pid, KilnWeb.Endpoint.child_spec([]))

        {:ok, sup_pid}

      other ->
        other
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    KilnWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @impl true
  def stop(_state) do
    _ = ObanHandler.detach()
    _ = TelemetryHandler.detach()
    :ok
  end

  @doc false
  def infra_children do
    [
      KilnWeb.Telemetry,
      Kiln.Repo,
      {Phoenix.PubSub, name: Kiln.PubSub},
      {Finch, name: Kiln.Finch, pools: finch_pools()},
      {Registry, keys: :unique, name: Kiln.RunRegistry},
      {Oban, Application.fetch_env!(:kiln, Oban)},
      Kiln.Sandboxes.Supervisor,
      Kiln.Sandboxes.DTU.Supervisor,
      Kiln.Policies.FactoryCircuitBreaker,
      Kiln.Runs.RunSupervisor,
      {Kiln.Runs.RunDirector, []},
      Kiln.Policies.StuckDetector
    ]
  end

  @doc false
  def finch_pools do
    %{
      "https://api.anthropic.com" => [size: 10, count: 1, protocols: [:http2]],
      "https://api.openai.com" => [size: 10, count: 1, protocols: [:http2]],
      "https://generativelanguage.googleapis.com" => [size: 10, count: 1],
      "http://localhost:11434" => [size: 5, count: 1],
      "http://172.28.0.10:80" => [size: 5, count: 1],
      :default => [size: 10, count: 1]
    }
  end
end
