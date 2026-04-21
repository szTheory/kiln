defmodule Kiln.Agents.SessionSupervisorTest do
  use Kiln.DataCase, async: false

  alias Kiln.Agents.SessionSupervisor
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.RunSubtree

  setup do
    run = RunFactory.insert(:run, state: :coding)
    {:ok, run: run}
  end

  test "per-run child_spec is keyed by run_id and registers via RunRegistry", %{run: run} do
    spec = SessionSupervisor.child_spec(run_id: run.id)
    assert spec.id == {SessionSupervisor, run.id}
    assert spec.type == :supervisor

    assert {:ok, sup} = Supervisor.start_link([spec], strategy: :one_for_one)
    on_exit(fn -> _ = Process.exit(sup, :kill) end)

    assert SessionSupervisor.whereis(run.id) != nil
  end

  test "per-run session supervisor starts exactly seven role workers", %{run: run} do
    assert {:ok, sup} = SessionSupervisor.start_link(run_id: run.id)
    on_exit(fn -> _ = Process.exit(sup, :kill) end)

    counts = Supervisor.count_children(sup)
    assert counts.active == 7
    assert counts.workers == 7
    assert counts.supervisors == 0
  end

  test "RunSubtree hosts SessionSupervisor and exposes lookup helpers", %{run: run} do
    assert {:ok, tree} = RunSubtree.start_link(run_id: run.id)
    on_exit(fn -> _ = Process.exit(tree, :kill) end)

    for role <- [:mayor, :planner, :coder, :tester, :reviewer, :uiux, :qa_verifier] do
      pid = SessionSupervisor.role_pid(run.id, role)

      if is_pid(pid) do
        Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
      end
    end

    sess = SessionSupervisor.whereis(run.id)
    assert is_pid(sess)
    assert RunSubtree.lived_child_pid(run.id) == sess
    assert RunSubtree.session_supervisor_pid(run.id) == sess

    assert is_pid(RunSubtree.role_pid(run.id, :mayor))
    assert is_pid(RunSubtree.role_pid(run.id, :planner))
  end
end
