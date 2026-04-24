defmodule Mix.Tasks.Kiln.FirstRun.ProveTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.Kiln.FirstRun.Prove

  test "delegates exactly the two locked proof layers in order" do
    parent = self()

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_reenabler,
      fn task ->
        send(parent, {:task_reenabled, task})
        :ok
      end,
      persistent: false
    )

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_runner,
      fn task, args ->
        send(parent, {:task_run, task, args})
        :ok
      end,
      persistent: false
    )

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_cmd_runner,
      fn args ->
        send(parent, {:cmd_run, args})
        :ok
      end,
      persistent: false
    )

    on_exit(fn ->
      Application.delete_env(:kiln, :kiln_first_run_prove_reenabler)
      Application.delete_env(:kiln, :kiln_first_run_prove_runner)
      Application.delete_env(:kiln, :kiln_first_run_prove_cmd_runner)
    end)

    assert :ok = @task.run([])

    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}

    assert_received {:cmd_run,
                     [
                       "env",
                       "MIX_ENV=test",
                       "mix",
                       "test",
                       "test/kiln_web/live/templates_live_test.exs",
                       "test/kiln_web/live/run_detail_live_test.exs"
                     ]}

    refute_received {:task_run, _, _}
    refute_received {:cmd_run, _}
  end

  test "re-enables both delegated tasks on repeated invocation" do
    parent = self()

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_reenabler,
      fn task ->
        send(parent, {:task_reenabled, task})
        :ok
      end,
      persistent: false
    )

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_runner,
      fn task, args ->
        send(parent, {:task_run, task, args})
        :ok
      end,
      persistent: false
    )

    Application.put_env(
      :kiln,
      :kiln_first_run_prove_cmd_runner,
      fn args ->
        send(parent, {:cmd_run, args})
        :ok
      end,
      persistent: false
    )

    on_exit(fn ->
      Application.delete_env(:kiln, :kiln_first_run_prove_reenabler)
      Application.delete_env(:kiln, :kiln_first_run_prove_runner)
      Application.delete_env(:kiln, :kiln_first_run_prove_cmd_runner)
    end)

    assert :ok = @task.run([])
    assert :ok = @task.run([])

    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}
    assert_received {:cmd_run, _}
    assert_received {:task_reenabled, "integration.first_run"}
    assert_received {:task_run, "integration.first_run", []}
    assert_received {:cmd_run, _}
    refute_received _
  end
end
