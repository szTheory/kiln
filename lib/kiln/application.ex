defmodule Kiln.Application do
  @moduledoc false
  use Application

  alias Kiln.Telemetry.ObanHandler

  # D-42 locks the children list to EXACTLY 7 — no DNSCluster, no stub
  # Phase 2+ children. Plan 06 will re-topologise into a staged start
  # (infra_children → BootChecks.run! → Endpoint); this wave-3 version is
  # the simple single-list start plus the Oban telemetry handler attached
  # once the supervisor is up (Plan 05 / OBS-01).
  @impl true
  def start(_type, _args) do
    children = [
      KilnWeb.Telemetry,
      Kiln.Repo,
      {Phoenix.PubSub, name: Kiln.PubSub},
      {Finch, name: Kiln.Finch},
      {Registry, keys: :unique, name: Kiln.RunRegistry},
      {Oban, Application.fetch_env!(:kiln, Oban)},
      KilnWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Kiln.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Telemetry handlers are ETS-backed, not process-backed — attach
        # here rather than adding an 8th supervisor child (D-42 7-child
        # invariant). Idempotent: returns `{:error, :already_exists}` on
        # re-attach (tolerated so code-reload / iex restarts don't crash).
        _ = ObanHandler.attach()
        {:ok, pid}

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
    :ok
  end
end
