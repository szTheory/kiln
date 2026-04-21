defmodule Kiln.Runs.RunSubtree do
  @moduledoc """
  Per-run `Supervisor` (`:one_for_all`, `:transient`) hosted under
  `Kiln.Runs.RunSupervisor` (D-95).

  ## Strategy — `:one_for_all`

  A failure in the per-run agent session or other lived children forces
  a coordinated restart — consistent with CLAUDE.md's crash contract.

  ## Phase 4 shape

  The subtree hosts `Kiln.Agents.SessionSupervisor` in per-run mode (seven
  fixed role workers). `lived_child_pid/1` resolves the session supervisor
  for ORCH-02 crash tests.

  ## Registry naming

  * `{__MODULE__, run_id}` — the subtree supervisor pid
  * `{Kiln.Agents.SessionSupervisor, run_id}` — the session supervisor
  * `{Kiln.Agents.Role, run_id, role}` — each role worker
  """

  use Supervisor

  alias Kiln.Agents.SessionSupervisor

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    %{
      id: {__MODULE__, run_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: 5_000,
      type: :supervisor
    }
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    Supervisor.start_link(__MODULE__, opts, name: via(run_id))
  end

  @impl true
  def init(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    children = [
      {SessionSupervisor, run_id: run_id}
    ]

    Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
  end

  @doc """
  Returns the per-run session supervisor pid, or `nil` if the subtree is
  not running.

  Used by integration tests as the killable process under the subtree.
  """
  @spec lived_child_pid(Ecto.UUID.t()) :: pid() | nil
  def lived_child_pid(run_id) do
    SessionSupervisor.whereis(run_id)
  end

  @doc "See `Kiln.Agents.SessionSupervisor.whereis/1`."
  @spec session_supervisor_pid(Ecto.UUID.t()) :: pid() | nil
  def session_supervisor_pid(run_id), do: SessionSupervisor.whereis(run_id)

  @doc "See `Kiln.Agents.SessionSupervisor.role_pid/2`."
  @spec role_pid(Ecto.UUID.t(), atom()) :: pid() | nil
  def role_pid(run_id, role), do: SessionSupervisor.role_pid(run_id, role)

  defp via(run_id) do
    {:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id}}}
  end
end
