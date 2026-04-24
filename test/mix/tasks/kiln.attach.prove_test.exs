defmodule Mix.Tasks.Kiln.Attach.ProveTest do
  use ExUnit.Case, async: false

  @task Mix.Tasks.Kiln.Attach.Prove

  test "delegates the three locked attach proof layers in order" do
    parent = self()

    Application.put_env(
      :kiln,
      :kiln_attach_prove_cmd_runner,
      fn args ->
        send(parent, {:cmd_run, args})
        :ok
      end,
      persistent: false
    )

    on_exit(fn ->
      Application.delete_env(:kiln, :kiln_attach_prove_cmd_runner)
    end)

    assert :ok = @task.run([])

    assert_received {:cmd_run,
                     [
                       "env",
                       "MIX_ENV=test",
                       "mix",
                       "test",
                       "test/integration/github_delivery_test.exs"
                     ]}

    assert_received {:cmd_run,
                     [
                       "env",
                       "MIX_ENV=test",
                       "mix",
                       "test",
                       "test/kiln/attach/safety_gate_test.exs"
                     ]}

    assert_received {:cmd_run,
                     [
                       "env",
                       "MIX_ENV=test",
                       "mix",
                       "test",
                       "test/kiln_web/live/attach_entry_live_test.exs"
                     ]}

    refute_received {:cmd_run, _}
  end

  test "can be re-run without stale task state" do
    parent = self()

    Application.put_env(
      :kiln,
      :kiln_attach_prove_cmd_runner,
      fn args ->
        send(parent, {:cmd_run, args})
        :ok
      end,
      persistent: false
    )

    on_exit(fn ->
      Application.delete_env(:kiln, :kiln_attach_prove_cmd_runner)
    end)

    assert :ok = @task.run([])
    assert :ok = @task.run([])

    for _ <- 1..6 do
      assert_received {:cmd_run, _}
    end

    refute_received {:cmd_run, _}
  end
end
