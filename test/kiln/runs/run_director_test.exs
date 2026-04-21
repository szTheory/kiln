defmodule Kiln.Runs.RunDirectorTest do
  @moduledoc """
  Unit tests for `Kiln.Runs.RunDirector`'s three drivers (D-92..D-96):

    * `:boot_scan` discovers active runs and spawns per-run subtrees
      under `Kiln.Runs.RunSupervisor`.
    * D-94 workflow-checksum mismatch (and missing-workflow-file)
      transitions the run to `:escalated` with `reason:
      :workflow_changed` BEFORE spawning a subtree.
    * Periodic `:periodic_scan` does NOT double-spawn a subtree for a
      run that is already monitored — the MapSet filter on the
      monitor table is the idempotency guard.

  Plan 02-07 (this plan) starts `RunDirector` as a `:permanent` child
  of `Kiln.Supervisor`, so these tests interact with the live
  singleton rather than spawning a fresh instance per test.
  `Kiln.DataCase` gives DB isolation via the Ecto sandbox;
  `Kiln.RehydrationCase.reset_run_director_for_test/0` forces the
  director's DB connection into the current test's sandbox BEFORE the
  fresh `:boot_scan` runs, resolving threat-model T6 (pre-sandbox-
  allow race).

  Note on `@tag :skip`: there is NO `@tag :skip` on any test here.
  Checker issue #1 required ORCH-02 to have an active end-to-end
  test; the previously-skipped `:boot_scan` test is live again as of
  this plan because the RehydrationCase helper makes the DB-connection
  race deterministic.
  """

  use Kiln.DataCase, async: false
  use Kiln.RehydrationCase

  alias Kiln.Runs.{RunDirector, RunSupervisor}
  alias Kiln.Factory.Run, as: RunFactory

  @moduletag :run_director

  setup do
    # Force RunDirector's Repo connection into this test's sandbox,
    # then re-trigger :boot_scan with the sandboxed connection. Without
    # this the director might already have a pool-default connection
    # bound before the test set up its sandbox — threat T6.
    reset_run_director_for_test()

    # Clean out any subtrees a prior test left behind under
    # RunSupervisor. RunDirector is a :permanent singleton across the
    # whole MIX_ENV=test run, so per-test RunSupervisor cleanup is
    # required for deterministic child-count assertions.
    for {_id, pid, _type, _mods} <- DynamicSupervisor.which_children(RunSupervisor) do
      _ = DynamicSupervisor.terminate_child(RunSupervisor, pid)
    end

    :ok
  end

  describe ":boot_scan handler (D-92)" do
    test "discovers active runs and spawns subtrees under RunSupervisor" do
      # Insert a run in :coding state (active) with a workflow checksum
      # matching the real elixir_phoenix_feature.yaml on disk so
      # assert_workflow_unchanged/1 passes.
      {:ok, cg} = Kiln.Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

      run =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: cg.id,
          workflow_checksum: cg.checksum
        )

      # Manually send :boot_scan to the live singleton — this exercises
      # do_scan/1 end-to-end.
      send(RunDirector, :boot_scan)
      Process.sleep(200)
      allow_session_roles_for_run(run.id)

      children = DynamicSupervisor.which_children(RunSupervisor)

      assert Enum.any?(children, fn {_id, pid, _type, _mods} -> is_pid(pid) end),
             "expected at least one per-run subtree spawned under RunSupervisor; got #{inspect(children)}"
    end
  end

  describe "workflow checksum assertion (D-94)" do
    test "run with mismatched workflow_checksum (workflow file missing) is transitioned to :escalated" do
      # workflow_id "nonexistent_workflow" has no matching on-disk file,
      # so assert_workflow_unchanged/1 returns {:error, :workflow_changed}
      # BEFORE any subtree spawn.
      run =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: "nonexistent_workflow",
          workflow_checksum: String.duplicate("0", 64)
        )

      send(RunDirector, :boot_scan)
      Process.sleep(200)

      reloaded = Kiln.Repo.get!(Kiln.Runs.Run, run.id)
      assert reloaded.state == :escalated
      assert reloaded.escalation_reason == "workflow_changed"
    end
  end

  describe "idempotent periodic scan" do
    test "re-scan does not double-spawn an already-monitored run" do
      {:ok, cg} = Kiln.Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

      run =
        RunFactory.insert(:run,
          state: :coding,
          workflow_id: cg.id,
          workflow_checksum: cg.checksum
        )

      send(RunDirector, :boot_scan)
      Process.sleep(200)
      allow_session_roles_for_run(run.id)

      children_after_first = length(DynamicSupervisor.which_children(RunSupervisor))

      send(RunDirector, :periodic_scan)
      Process.sleep(200)

      children_after_second = length(DynamicSupervisor.which_children(RunSupervisor))

      assert children_after_first == children_after_second,
             "periodic scan must not double-spawn: #{children_after_first} before, #{children_after_second} after"
    end
  end
end
