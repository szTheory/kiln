defmodule Kiln.Integration.AgentRoleCrashTest do
  @moduledoc """
  Dedicated validation-matrix proof that killing a role process under one
  run does not affect peer runs (Phase 4 plan 04-04).
  """

  use Kiln.DataCase, async: false
  use Kiln.RehydrationCase

  alias Kiln.Agents.SessionSupervisor
  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.{RunDirector, RunSupervisor}

  @moduletag :integration

  setup do
    reset_run_director_for_test()

    for {_id, pid, _type, _mods} <- DynamicSupervisor.which_children(RunSupervisor) do
      _ = DynamicSupervisor.terminate_child(RunSupervisor, pid)
    end

    :ok
  end

  test "killing a role under one run leaves other runs' role pids stable" do
    {:ok, cg} = Kiln.Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run_a =
      RunFactory.insert(:run,
        state: :coding,
        workflow_id: cg.id,
        workflow_checksum: cg.checksum
      )

    run_b =
      RunFactory.insert(:run,
        state: :coding,
        workflow_id: cg.id,
        workflow_checksum: cg.checksum
      )

    send(RunDirector, :boot_scan)
    Process.sleep(400)

    allow_session_roles_for_run(run_a.id)
    allow_session_roles_for_run(run_b.id)

    coder_a = SessionSupervisor.role_pid(run_a.id, :coder)
    assert is_pid(coder_a)

    coder_b_before = SessionSupervisor.role_pid(run_b.id, :coder)
    assert is_pid(coder_b_before)

    director_pid = Process.whereis(RunDirector)
    assert is_pid(director_pid)

    Process.exit(coder_a, :kill)
    Process.sleep(600)

    assert Process.whereis(RunDirector) == director_pid,
           "RunDirector must survive a role crash in a subtree"

    assert SessionSupervisor.role_pid(run_b.id, :coder) == coder_b_before,
           "peer run role pid must be untouched"

    coder_a_after = SessionSupervisor.role_pid(run_a.id, :coder)
    assert is_pid(coder_a_after)
    refute coder_a_after == coder_a
  end
end
