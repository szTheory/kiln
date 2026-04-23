defmodule Mix.Tasks.Planning.Gates do
  @moduledoc """
  Runs `script/planning_gates.sh` — the same `mix check` contract as CI
  (see `.github/workflows/ci.yml`) with test-env defaults.

  For **only** `mix check`, this task is enough. For **`mix check` + Docker
  integration smoke** (`first_run.sh`), use **`mix shift_left.verify`** instead.

  Use **before** `/gsd-plan-phase N --gaps` so verification gap closure targets
  real repo state, not a red tree.
  """
  use Mix.Task

  @shortdoc "CI-parity `mix check` before GSD plan-phase --gaps"

  @impl Mix.Task
  def run(_) do
    script = Path.expand("script/planning_gates.sh", File.cwd!())

    unless File.exists?(script) do
      Mix.raise("planning.gates: missing #{script}")
    end

    Mix.shell().info("==> planning.gates: #{script}")

    case System.cmd("bash", [script], cd: File.cwd!(), stderr_to_stdout: true) do
      {out, 0} ->
        if out != "", do: Mix.shell().info(String.trim_trailing(out))
        :ok

      {out, code} ->
        if out != "", do: Mix.shell().error(String.trim_trailing(out))
        Mix.raise("planning.gates failed (exit #{code})")
    end
  end
end
