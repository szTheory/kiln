defmodule Mix.Tasks.Kiln.FirstRun.ProveTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.Kiln.FirstRun.Prove

  test "delegates exactly the two locked proof layers in order" do
    parent = self()

    Process.put(:kiln_first_run_prove_runner, fn task, args ->
      send(parent, {:task_run, task, args})
      :ok
    end)

    on_exit(fn ->
      Process.delete(:kiln_first_run_prove_runner)
    end)

    assert :ok = @task.run([])

    assert_received {:task_run, "integration.first_run", []}

    assert_received {:task_run, "test",
                     [
                       "test/kiln_web/live/templates_live_test.exs",
                       "test/kiln_web/live/run_detail_live_test.exs"
                     ]}

    refute_received {:task_run, _, _}
  end
end
