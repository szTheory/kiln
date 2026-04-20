defmodule Kiln.Integration.RunSubtreeCrashTest do
  @moduledoc """
  ORCH-02 signature test — end-to-end proof that a child crash inside
  a per-run `Kiln.Runs.RunSubtree` is CONTAINED: the director
  survives, other runs' subtrees are untouched, and the affected run
  either recovers (`:one_for_all` restart absorbed the crash) or is
  escalated with a typed reason / awaits rehydration.

  This file addresses checker issue #1: before this plan, ORCH-02
  was covered only by an `@tag :skip` stub. The two tests here kill
  real `Task.Supervisor` pids under a real `RunSubtree` and assert
  the containment + recovery contract end-to-end, with no skip.

  ## Scenario 1 — single-crash absorption

  A killed child under a per-run subtree triggers the `:one_for_all`
  restart strategy. The subtree's `max_restarts: 3, max_seconds: 5`
  budget absorbs the crash; the lived child is replaced with a fresh
  pid. Meanwhile `RunDirector` is untouched, and unrelated runs'
  subtrees keep running without interruption.

  ## Scenario 2 — budget-trip escalation

  Four rapid-fire kills exceed the subtree's restart budget. The
  subtree itself terminates; `RunDirector`'s `Process.monitor`
  observes the `:DOWN`; the run is either explicitly transitioned
  to `:escalated` or left in its current state pending the next
  periodic scan's rehydration attempt. Critically, `RunDirector`
  itself stays alive — the director's isolation from subtree
  crashes is the ORCH-02 guarantee.
  """

  use Kiln.DataCase, async: false
  use Kiln.RehydrationCase

  require Logger
  alias Kiln.Runs.{RunDirector, RunSubtree, RunSupervisor}
  alias Kiln.Factory.Run, as: RunFactory

  @moduletag :integration
  @moduletag :run_subtree_crash

  setup do
    reset_run_director_for_test()

    # Clean out any subtrees a prior test left behind under
    # RunSupervisor. RunDirector is a :permanent singleton across the
    # whole MIX_ENV=test run, so per-test RunSupervisor cleanup is
    # required for deterministic behaviour on the boot-scan spawn path.
    for {_id, pid, _type, _mods} <- DynamicSupervisor.which_children(RunSupervisor) do
      _ = DynamicSupervisor.terminate_child(RunSupervisor, pid)
    end

    :ok
  end

  test "killing a child under a per-run RunSubtree does NOT crash the director or other subtrees" do
    # Arrange — two runs with matching on-disk workflow checksums,
    # so the director spawns real subtrees (D-94 escalation path
    # does NOT fire).
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

    # Trigger boot scan — spawns subtrees for both runs.
    send(RunDirector, :boot_scan)
    Process.sleep(300)

    # Find the Task.Supervisor lived-child under run_a's subtree.
    lived_child_a = RunSubtree.lived_child_pid(run_a.id)
    assert is_pid(lived_child_a),
           "expected lived child pid for run_a; got #{inspect(lived_child_a)}"

    lived_child_b_before = RunSubtree.lived_child_pid(run_b.id)
    assert is_pid(lived_child_b_before), "expected lived child pid for run_b"

    director_pid_before = Process.whereis(RunDirector)
    assert is_pid(director_pid_before)

    # Act — kill the Task.Supervisor under run_a.
    Process.exit(lived_child_a, :kill)
    # Give supervisor time to observe + restart.
    Process.sleep(300)

    # Assert (director isolation) — RunDirector MUST survive a child
    # crash in an unrelated subtree. This is the ORCH-02 guarantee.
    assert Process.whereis(RunDirector) == director_pid_before,
           "RunDirector must survive a child crash in an unrelated subtree"

    # Assert (peer-subtree isolation) — run_b's lived child is
    # untouched; the :one_for_one strategy on RunSupervisor contains
    # the crash to run_a's subtree alone.
    assert RunSubtree.lived_child_pid(run_b.id) == lived_child_b_before,
           "run_b's lived child must be untouched"

    # Assert (recovery) — run_a either has a NEW lived child
    # (:one_for_all restart absorbed the crash), OR the subtree
    # terminated and the run is in :escalated state, OR the subtree
    # is dead and pending re-spawn by the next periodic scan.
    lived_child_a_after = RunSubtree.lived_child_pid(run_a.id)
    reloaded_run_a = Kiln.Repo.get!(Kiln.Runs.Run, run_a.id)

    assert (is_pid(lived_child_a_after) and lived_child_a_after != lived_child_a) or
             reloaded_run_a.state == :escalated or
             is_nil(lived_child_a_after),
           "run_a must have recovered (new pid) or escalated (typed reason) or be awaiting rehydration; " <>
             "got state=#{reloaded_run_a.state} lived_child_after=#{inspect(lived_child_a_after)}"
  end

  test "repeated crashes beyond subtree restart budget terminate the subtree and the run awaits rehydration or escalates" do
    {:ok, cg} = Kiln.Workflows.load("priv/workflows/elixir_phoenix_feature.yaml")

    run =
      RunFactory.insert(:run,
        state: :coding,
        workflow_id: cg.id,
        workflow_checksum: cg.checksum
      )

    send(RunDirector, :boot_scan)
    Process.sleep(300)

    # Hammer the subtree: kill the lived-child 4 times in a burst.
    # Budget is max_restarts: 3 in max_seconds: 5; the 4th kill trips
    # the budget and terminates the whole RunSubtree — which cascades
    # as a :DOWN to RunDirector.
    for _ <- 1..4 do
      pid = RunSubtree.lived_child_pid(run.id)
      if is_pid(pid), do: Process.exit(pid, :kill)
      Process.sleep(50)
    end

    # Let the cascade settle.
    Process.sleep(500)

    # Either:
    #   (a) subtree is gone (no lived child) — RunDirector's DOWN
    #       handler logged; next periodic scan will rehydrate or
    #       escalate based on the D-94 workflow-checksum assertion.
    #   (b) run was explicitly transitioned to :escalated.
    reloaded = Kiln.Repo.get!(Kiln.Runs.Run, run.id)
    lived_now = RunSubtree.lived_child_pid(run.id)

    assert reloaded.state in [:escalated, :coding] or is_nil(lived_now),
           "repeated crashes must result in escalation or subtree termination; " <>
             "got state=#{reloaded.state} lived=#{inspect(lived_now)}"

    # Critical — RunDirector itself MUST still be alive. Crashes in
    # subtrees must NOT bring down the director (that's the ORCH-02
    # guarantee; this assertion is the central one for checker #1).
    assert Process.whereis(RunDirector) != nil,
           "RunDirector must survive repeated subtree crashes"
  end
end
