defmodule Kiln.Runs.RunSubtree do
  @moduledoc """
  Per-run `Supervisor` (`:one_for_all`, `:transient`) hosted under
  `Kiln.Runs.RunSupervisor` (D-95).

  ## Phase 2 shape (this plan)

  Phase 2 ships the subtree with a minimal lived child — a
  `Task.Supervisor` registered by a per-run tuple in
  `Kiln.RunRegistry`. The lived-child exists so that
  `test/integration/run_subtree_crash_test.exs` can kill a real pid
  under the subtree and exercise the `:one_for_all` restart semantics
  (addresses checker issue #1 — ORCH-02 was previously only covered
  by an `@tag :skip` stub). Phase 3 replaces the `Task.Supervisor`
  child with the real `Kiln.Agents.SessionSupervisor` +
  `Kiln.Sandboxes.Supervisor` pair.

  ## Strategy — `:one_for_all`

  A coder crash restarts tester + planner alongside it — consistent
  with CLAUDE.md's "if an agent crashes, the run recovers or
  escalates." Agent state is not trusted to survive a crash in the
  sibling; forcing the whole subtree down + up preserves invariants.

  ## Restart — `:transient`

  A clean shutdown (`:normal` exit) does NOT restart the subtree.
  Abnormal termination restarts within the `max_restarts: 3` /
  `max_seconds: 5` budget. Once the budget is tripped the subtree
  itself terminates; `RunDirector`'s monitor observes the DOWN,
  logs the failure, and the next periodic scan re-spawns the
  subtree (or escalates the run per D-94 if the workflow file
  changed underfoot).

  ## Registry naming

  Both the subtree supervisor itself and its lived-child
  `Task.Supervisor` register via `{:via, Registry, {Kiln.RunRegistry,
  ...}}` — `Kiln.RunRegistry` is a P1 infra child (already in the
  supervision tree). The per-run tuples are:

    * `{__MODULE__, run_id}` — the subtree supervisor pid
    * `{Kiln.Runs.RunSubtree.Tasks, run_id}` — the lived-child
      `Task.Supervisor` pid (exposed via `lived_child_pid/1`)

  ## Phase 3 migration plan

  When Phase 3 adds real agent + sandbox supervisors, the `children`
  list in `init/1` replaces the `Task.Supervisor` entry with:

      children = [
        {Kiln.Agents.SessionSupervisor, run_id: run_id},
        {Kiln.Sandboxes.Supervisor, run_id: run_id}
      ]

  The `lived_child_pid/1` helper + `:one_for_all` strategy + the
  integration test both remain unchanged — the only delta is the
  child list itself.
  """

  use Supervisor

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

    # Phase 2 minimal lived-child: a `Task.Supervisor` named via the
    # run registry. Its only role is to exist as a real pid that can
    # be killed so `test/integration/run_subtree_crash_test.exs` can
    # exercise the `:one_for_all` restart semantics. Phase 3 replaces
    # this with `Kiln.Agents.SessionSupervisor` +
    # `Kiln.Sandboxes.Supervisor`.
    children = [
      {Task.Supervisor,
       name: {:via, Registry, {Kiln.RunRegistry, {__MODULE__.Tasks, run_id}}}}
    ]

    Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
  end

  @doc """
  Returns the pid of the lived-child `Task.Supervisor` for a given
  `run_id`, or `nil` if no subtree is alive for that run.

  Used by `test/integration/run_subtree_crash_test.exs` to find a
  killable process under the per-run subtree. Phase 3 will generalise
  this helper (or replace it with a `children/1` query returning all
  per-run child pids) once the lived-child set grows beyond one.
  """
  @spec lived_child_pid(Ecto.UUID.t()) :: pid() | nil
  def lived_child_pid(run_id) do
    case Registry.lookup(Kiln.RunRegistry, {__MODULE__.Tasks, run_id}) do
      [{pid, _}] when is_pid(pid) -> pid
      _ -> nil
    end
  end

  defp via(run_id) do
    {:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id}}}
  end
end
