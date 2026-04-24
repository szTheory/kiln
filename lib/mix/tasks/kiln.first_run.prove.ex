defmodule Mix.Tasks.Kiln.FirstRun.Prove do
  @moduledoc """
  Proves Kiln's setup-ready local first-run path by delegating exactly two
  existing proof layers in order:

    1. `mix integration.first_run`
    2. focused LiveView tests for the operator journey
  """
  use Mix.Task

  @shortdoc "Run the local first-run proof layers in locked order"

  @focused_liveview_files [
    "test/kiln_web/live/templates_live_test.exs",
    "test/kiln_web/live/run_detail_live_test.exs"
  ]

  @impl Mix.Task
  def run(_args) do
    run_task("integration.first_run", [])
    run_task("test", @focused_liveview_files)
  end

  defp runner do
    Process.get(:kiln_first_run_prove_runner, &Mix.Task.run/2)
  end

  defp reenabler do
    Process.get(:kiln_first_run_prove_reenabler, &Mix.Task.reenable/1)
  end

  defp run_task(task, args) do
    reenabler().(task)
    runner().(task, args)
  end
end
