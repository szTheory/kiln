defmodule Kiln.Agents.SessionSupervisor do
  @moduledoc """
  Agent session supervision for Kiln runs.

  **Legacy mode** — empty `Supervisor` registered as `__MODULE__` so the
  Phase 3 application tree keeps a stable boot slot until Phase 4
  removes it.

  **Per-run mode** — `:one_for_all` `Supervisor` with exactly seven role
  workers, registered in `Kiln.RunRegistry` at `{__MODULE__, run_id}`.
  """

  use Supervisor

  alias Kiln.Agents.Roles.{
    Coder,
    Mayor,
    Planner,
    QAVerifier,
    Reviewer,
    Tester,
    UIUX
  }

  @doc false
  @spec child_spec(keyword() | []) :: Supervisor.child_spec()
  def child_spec([]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor
    }
  end

  def child_spec(opts) when is_list(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    %{
      id: {__MODULE__, run_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: :infinity,
      type: :supervisor
    }
  end

  @spec start_link([] | keyword()) :: Supervisor.on_start()
  def start_link([]) do
    Supervisor.start_link(__MODULE__, :legacy, name: __MODULE__)
  end

  def start_link(opts) when is_list(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    Supervisor.start_link(__MODULE__, {:per_run, run_id}, name: via(run_id))
  end

  @impl true
  def init(:legacy) do
    Supervisor.init([], strategy: :one_for_one)
  end

  def init({:per_run, run_id}) do
    children = [
      {Mayor, run_id: run_id},
      {Planner, run_id: run_id},
      {Coder, run_id: run_id},
      {Tester, run_id: run_id},
      {Reviewer, run_id: run_id},
      {UIUX, run_id: run_id},
      {QAVerifier, run_id: run_id}
    ]

    Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
  end

  @doc false
  @spec via(Ecto.UUID.t()) :: {:via, Registry, {module(), tuple()}}
  def via(run_id) when is_binary(run_id) do
    {:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id}}}
  end

  @doc "Returns the per-run session supervisor pid, if running."
  @spec whereis(Ecto.UUID.t()) :: pid() | nil
  def whereis(run_id) when is_binary(run_id) do
    case Registry.lookup(Kiln.RunRegistry, {__MODULE__, run_id}) do
      [{pid, _}] when is_pid(pid) -> pid
      _ -> nil
    end
  end

  @doc "Returns the role worker pid for `run_id` + `role`, if registered."
  @spec role_pid(Ecto.UUID.t(), atom()) :: pid() | nil
  def role_pid(run_id, role) when is_binary(run_id) and is_atom(role) do
    case Registry.lookup(Kiln.RunRegistry, {Kiln.Agents.Role, run_id, role}) do
      [{pid, _}] when is_pid(pid) -> pid
      _ -> nil
    end
  end
end
