defmodule Mix.Tasks.Kiln.E2e do
  @moduledoc """
  `mix kiln.e2e` — One-shot Playwright e2e runner for agents (and
  humans) that prefer mix to bash.

  Steps:

    1. `bash script/e2e_boot.sh` (compose up + migrate + seed + Phoenix +
       /health wait).
    2. `npm ci` in `test/e2e/` if `node_modules/` is missing.
    3. `npx playwright install --with-deps chromium webkit` on first run.
    4. `npx playwright test` (or `playwright test --ui` when `--ui` is
       passed).
    5. On exit (including failure), kills the background Phoenix server
       started by the boot script.

  Flags:
    * `--ui`         — opens Playwright's watch/debug UI.
    * `--headed`     — runs with `--headed`.
    * `--reuse`      — skips the boot step (assumes server is up on 4000).
    * `--no-install` — skips `npx playwright install` (useful in CI
                       where browsers are cached via actions/cache).

  Extra args after `--` are passed verbatim to Playwright:

      mix kiln.e2e -- tests/routes.spec.ts --project=desktop-chromium-light
  """

  use Mix.Task

  @shortdoc "Boot Phoenix, seed e2e fixtures, and run Playwright against all 14 LV routes"

  @switches [ui: :boolean, headed: :boolean, reuse: :boolean, no_install: :boolean]

  @impl Mix.Task
  def run(argv) do
    {opts, argv} = OptionParser.parse_head!(argv, switches: @switches)
    passthrough = drop_separator(argv)

    root = File.cwd!()
    e2e_dir = Path.join(root, "test/e2e")

    unless File.dir?(e2e_dir) do
      Mix.raise("kiln.e2e: expected test/e2e/ to exist (scaffold from the plan)")
    end

    boot_pid = maybe_boot(opts[:reuse], root)

    try do
      ensure_node_modules(e2e_dir)
      unless opts[:no_install], do: ensure_browsers(e2e_dir)

      status = run_playwright(e2e_dir, opts, passthrough)
      if status != 0, do: exit({:shutdown, status})
    after
      tear_down(boot_pid)
    end
  end

  defp drop_separator(["--" | rest]), do: rest
  defp drop_separator(rest), do: rest

  defp maybe_boot(true, _root) do
    Mix.shell().info("kiln.e2e: --reuse set, skipping boot")
    nil
  end

  defp maybe_boot(_, root) do
    Mix.shell().info("kiln.e2e: booting Phoenix via script/e2e_boot.sh…")
    script = Path.join(root, "script/e2e_boot.sh")
    {out, code} = System.cmd("bash", [script], stderr_to_stdout: true)
    IO.write(out)

    if code != 0 do
      Mix.raise("kiln.e2e: script/e2e_boot.sh failed (exit #{code})")
    end

    # e2e_boot.sh echoes "PHX_PID=<pid>" when it started the server
    # itself; capture so we can tear it down.
    extract_pid(out)
  end

  defp extract_pid(output) do
    Regex.run(~r/PHX_PID=(\d+)/, output)
    |> case do
      [_, pid_str] -> String.to_integer(pid_str)
      _ -> nil
    end
  end

  defp ensure_node_modules(e2e_dir) do
    if File.dir?(Path.join(e2e_dir, "node_modules")) do
      :ok
    else
      Mix.shell().info("kiln.e2e: installing npm deps (one-time)…")

      install_args =
        if File.exists?(Path.join(e2e_dir, "package-lock.json")) do
          ["ci"]
        else
          ["install"]
        end

      {_, code} = System.cmd("npm", install_args, cd: e2e_dir, into: IO.stream())

      if code != 0 do
        Mix.raise("kiln.e2e: npm #{Enum.join(install_args, " ")} failed (exit #{code})")
      end
    end
  end

  defp ensure_browsers(e2e_dir) do
    Mix.shell().info("kiln.e2e: ensuring Playwright browsers are installed…")

    {_, code} =
      System.cmd("npx", ["playwright", "install", "--with-deps", "chromium", "webkit"],
        cd: e2e_dir,
        into: IO.stream()
      )

    if code != 0 do
      Mix.raise("kiln.e2e: playwright install failed (exit #{code})")
    end
  end

  defp run_playwright(e2e_dir, opts, passthrough) do
    args =
      ["playwright", "test"]
      |> add_flag(opts[:ui], "--ui")
      |> add_flag(opts[:headed], "--headed")
      |> Kernel.++(passthrough)

    {_, code} = System.cmd("npx", args, cd: e2e_dir, into: IO.stream())
    code
  end

  defp add_flag(args, true, flag), do: args ++ [flag]
  defp add_flag(args, _, _), do: args

  defp tear_down(nil), do: :ok

  defp tear_down(pid) when is_integer(pid) do
    Mix.shell().info("kiln.e2e: tearing down Phoenix (pid=#{pid})…")
    _ = System.cmd("kill", [Integer.to_string(pid)], stderr_to_stdout: true)
    :ok
  end
end
