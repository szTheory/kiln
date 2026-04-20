defmodule Kiln.Sandboxes.Supervisor do
  @moduledoc """
  Supervises Phase 3 sandbox runtime support on the host.

  Child order matters:

    * `Kiln.Sandboxes.OrphanSweeper` boots first so stale containers are
      cleaned up before later runtime processes begin dispatching work.
    * `Kiln.Notifications.DedupCache` lives here to keep the application
      tree within the planned child-count budget.
  """

  use Supervisor

  alias Kiln.Notifications.DedupCache
  alias Kiln.Sandboxes.OrphanSweeper

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [
      OrphanSweeper,
      DedupCache
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
