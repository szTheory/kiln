defmodule Kiln.Agents.RoleTest do
  use Kiln.DataCase, async: false

  alias Kiln.Agents.SessionSupervisor
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.RunSubtree
  alias Kiln.WorkUnits

  describe "with per-run subtree" do
    setup do
      run = RunFactory.insert(:run, state: :coding)
      assert {:ok, tree} = RunSubtree.start_link(run_id: run.id)
      on_exit(fn -> _ = Process.exit(tree, :kill) end)

      for role <- [:mayor, :planner, :coder, :tester, :reviewer, :uiux, :qa_verifier] do
        pid = SessionSupervisor.role_pid(run.id, role)

        if is_pid(pid) do
          Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, self(), pid)
        end
      end

      {:ok, run: run}
    end

    test "each role module exports start_link/1 and role/0 via behaviour", %{run: run} do
      for {mod, role} <- [
            {Kiln.Agents.Roles.Mayor, :mayor},
            {Kiln.Agents.Roles.Planner, :planner},
            {Kiln.Agents.Roles.Coder, :coder},
            {Kiln.Agents.Roles.Tester, :tester},
            {Kiln.Agents.Roles.Reviewer, :reviewer},
            {Kiln.Agents.Roles.UIUX, :uiux},
            {Kiln.Agents.Roles.QAVerifier, :qa_verifier}
          ] do
        assert mod.role() == role
        assert is_pid(SessionSupervisor.role_pid(run.id, role))
      end
    end

    test "Mayor seeds the initial planner work unit once", %{run: run} do
      Process.sleep(200)
      units = WorkUnits.list_run_work_units(run.id)
      assert length(units) == 1
      assert hd(units).agent_role == :planner
      assert hd(units).state in [:open, :in_progress]
    end

    test "killing one role restarts the full role set under :one_for_all", %{run: run} do
      Process.sleep(200)
      before = SessionSupervisor.role_pid(run.id, :coder)
      assert is_pid(before)

      Process.exit(before, :kill)
      Process.sleep(500)

      after_pid = SessionSupervisor.role_pid(run.id, :coder)
      assert is_pid(after_pid)
      refute after_pid == before

      assert is_pid(SessionSupervisor.role_pid(run.id, :mayor))
    end
  end

  describe "claim discipline (WorkUnits API, no subtree race)" do
    setup do
      run = RunFactory.insert(:run, state: :coding)
      {:ok, run: run}
    end

    test "planner cannot claim a ready unit tagged for another role", %{run: run} do
      assert {:ok, _} = WorkUnits.seed_initial_planner_unit(run.id)
      assert {:ok, _} = WorkUnits.claim_next_ready(run.id, :planner)

      assert {:ok, _} =
               WorkUnits.create_work_unit(%{
                 run_id: run.id,
                 agent_role: :coder,
                 input_payload: %{},
                 result_payload: %{}
               })

      assert {:error, :role_mismatch} = WorkUnits.claim_next_ready(run.id, :planner)
    end
  end
end
