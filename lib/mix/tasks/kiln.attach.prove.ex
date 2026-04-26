defmodule Mix.Tasks.Kiln.Attach.Prove do
  @moduledoc """
  Runs the sole owning proof command for attached draft-PR handoff.

  Delegates six locked proof layers in order:

    1. draft PR delivery integration proof
    2. delivery body seam contract proof
    3. attached continuity proof
    4. safety gate refusal coverage
    5. brownfield preflight warning coverage
    6. `/attach` LiveView truth-surface coverage
  """
  use Mix.Task

  @shortdoc "Run the attached-repo proof layers in locked order"

  @proof_layers [
    ["env", "MIX_ENV=test", "mix", "test", "test/integration/github_delivery_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/delivery_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/continuity_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/safety_gate_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/brownfield_preflight_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln_web/live/attach_entry_live_test.exs"]
  ]

  @impl Mix.Task
  def run(_args) do
    Enum.each(@proof_layers, &run_cmd/1)
  end

  defp cmd_runner do
    Application.get_env(:kiln, :kiln_attach_prove_cmd_runner, &Mix.Task.run("cmd", &1))
  end

  defp run_cmd(args) do
    cmd_runner().(args)
  end
end
