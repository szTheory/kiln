defmodule Mix.Tasks.Kiln.FirstRun.ProveTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.Kiln.FirstRun.Prove

  test "delegates exactly the two locked proof layers in order" do
    parent = self()

    Process.put(:kiln_first_run_prove_reenabler, fn task ->
      send(parent, {:task_reenabled, task})
      :ok
    end)

    Process.put(:kiln_first_run_prove_runner, fn task, args ->
      send(parent, {:task_run, task, args})
      :ok
    end)

    on_exit(fn ->
      Process.delete(:kiln_first_run_prove_reenabler)
      Process.delete(:kiln_first_run_prove_runner)
    end)

    assert :ok = @task.run([])

    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}
    assert_received {:task_reenabled, "test"}
    assert_received {:task_run, "test",
                     [
                       "test/kiln_web/live/templates_live_test.exs",
                       "test/kiln_web/live/run_detail_live_test.exs"
                     ]}

    refute_received {:task_run, _, _}
  end

  test "re-enables both delegated tasks on repeated invocation" do
    parent = self()

    Process.put(:kiln_first_run_prove_reenabler, fn task ->
      send(parent, {:task_reenabled, task})
      :ok
    end)

    Process.put(:kiln_first_run_prove_runner, fn task, args ->
      send(parent, {:task_run, task, args})
      :ok
    end)

    on_exit(fn ->
      Process.delete(:kiln_first_run_prove_reenabler)
      Process.delete(:kiln_first_run_prove_runner)
    end)

    assert :ok = @task.run([])
    assert :ok = @task.run([])

    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}
    assert_received {:task_reenabled, "test"}
    assert_received {:task_run, "test", _}
    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}
    assert_received {:task_reenabled, "test"}
    assert_received {:task_run, "test", _}
    refute_received _
  end
end
