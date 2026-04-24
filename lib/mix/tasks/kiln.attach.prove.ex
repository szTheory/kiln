defmodule Mix.Tasks.Kiln.Attach.Prove do
  @moduledoc """
  Proves attached-repo delivery by delegating three locked proof layers in order:

    1. hermetic attach delivery happy path
    2. refusal-path safety gate coverage
    3. focused `/attach` LiveView truth-surface coverage
  """
  use Mix.Task

  @shortdoc "Run the attached-repo proof layers in locked order"

  @proof_layers [
    ["env", "MIX_ENV=test", "mix", "test", "test/integration/github_delivery_test.exs"],
    ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/safety_gate_test.exs"],
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
