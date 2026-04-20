defmodule KilnDtu.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bandit, plug: KilnDtu.Router, scheme: :http, port: 80}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: KilnDtu.Supervisor)
  end
end
