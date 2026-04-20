defmodule Kiln.Sandboxes.DTU.Supervisor do
  @moduledoc """
  Host-side DTU support supervisor.

  This hosts the periodic health poller and the loopback callback router.
  The contract-test worker stays registered through Oban config rather
  than as a direct supervisor child.
  """

  use Supervisor

  alias Kiln.Sandboxes.DTU

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      DTU.HealthPoll,
      {DTU.CallbackRouter, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
