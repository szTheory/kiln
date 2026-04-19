defmodule Kiln.Application do
  @moduledoc false
  use Application

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
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    KilnWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
