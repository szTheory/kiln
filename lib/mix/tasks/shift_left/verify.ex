defmodule Mix.Tasks.ShiftLeft.Verify do
  @moduledoc """
  Runs `script/shift_left_verify.sh` — **CI-parity `mix check`** plus the
  **integration smoke** (`test/integration/first_run.sh`: Compose DB, host
  Phoenix, `/health` contract).

  This is the single automated path for shift-left verification before GSD
  gap planning or release prep. Set `SHIFT_LEFT_SKIP_INTEGRATION=1` to run only
  `mix check` (same as `mix planning.gates`).
  """
  use Mix.Task

  @shortdoc "mix check + integration smoke (shift-left, one command)"

  @impl Mix.Task
  def run(_) do
    script = Path.expand("script/shift_left_verify.sh", File.cwd!())

    unless File.exists?(script) do
      Mix.raise("shift_left.verify: missing #{script}")
    end

    escaped_script = String.replace(script, "\"", "\\\"")

    Mix.shell().info("==> shift_left.verify: #{script}")

    case System.shell(~s(bash "#{escaped_script}"),
           cd: File.cwd!(),
           stderr_to_stdout: true,
           close_stdin: true
         ) do
      {out, 0} ->
        if out != "", do: Mix.shell().info(String.trim_trailing(out))
        :ok

      {out, code} ->
        if out != "", do: Mix.shell().error(String.trim_trailing(out))
        Mix.raise("shift_left.verify failed (exit #{code})")
    end
  end
end
