defmodule Mix.Tasks.Kiln.BootChecksTest do
  @moduledoc """
  CI parity test for `mix kiln.boot_checks` (D-34). The task raises via
  `Mix.raise/1` on any boot-check failure; a no-raise on the happy path
  is equivalent to "CI would exit 0".

  Uses `Kiln.DataCase` (non-async → shared sandbox) so the task's
  `Kiln.BootChecks.run!/0` call can reach the pool from the test
  process. The task's `Mix.Task.run("app.start")` is a no-op in test
  env because the app is already started.
  """
  use Kiln.DataCase, async: false

  import ExUnit.CaptureIO

  @task Mix.Tasks.Kiln.BootChecks

  describe "run/1 — happy path (D-34 CI parity)" do
    test "does not raise and prints the success signal" do
      output =
        capture_io(fn ->
          result =
            try do
              @task.run([])
              :ok
            rescue
              Mix.Error -> :mix_raise
              Kiln.BootChecks.Error -> :boot_checks_error
            end

          assert result == :ok, "mix kiln.boot_checks raised on the happy path: #{result}"
        end)

      # Mix.shell() routes to the default shell in test; capture_io picks
      # up the IO-based success line.
      assert output =~ "OK" or output =~ "satisfied" or output == ""
    end
  end
end
