defmodule Kiln.Agents.SessionSupervisorCompatibilityTest do
  @moduledoc """
  Proves standalone legacy `SessionSupervisor` (`start_link([])`) coexists
  with per-run supervisors without Registry collisions (Phase 4 plan 04-03).
  """

  use Kiln.DataCase, async: false

  alias Kiln.Agents.SessionSupervisor
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.RunSubtree

  test "standalone legacy supervisor does not collide with per-run registry keys" do
    assert {:ok, legacy} = SessionSupervisor.start_link([])
    on_exit(fn -> _ = Process.exit(legacy, :kill) end)

    run = RunFactory.insert(:run, state: :coding)

    assert {:ok, tree} = RunSubtree.start_link(run_id: run.id)
    on_exit(fn -> _ = Process.exit(tree, :kill) end)

    for role <- [:mayor, :planner, :coder, :tester, :reviewer, :uiux, :qa_verifier] do
      pid = SessionSupervisor.role_pid(run.id, role)

      if is_pid(pid) do
        Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
      end
    end

    per_run_sess = SessionSupervisor.whereis(run.id)
    assert is_pid(per_run_sess)
    refute per_run_sess == legacy
  end
end
