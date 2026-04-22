defmodule Mix.Tasks.Docs.Verify do
  @moduledoc """
  Optional parity with the path-filtered docs workflow (`.github/workflows/docs.yml`).

  Set `DOCS=1` to run `pnpm` in `site/`, `astro build`, then `htmltest`, `lychee`, and `typos`
  when each executable is on `PATH`. CI remains the source of truth for `main`.
  """
  use Mix.Task

  @shortdoc "Run docs site checks when DOCS=1 (optional local parity)"

  @impl Mix.Task
  def run(_args) do
    if System.get_env("DOCS") != "1" do
      IO.puts(:stderr, "[kiln] skipping docs.verify (set DOCS=1 to run)")
    else
      run_when_enabled()
    end
  end

  defp run_when_enabled do
    site = Path.expand("site", File.cwd!())

    unless File.dir?(site) do
      Mix.raise("site/ directory not found — docs site not present in this checkout")
    end

    cmd!("pnpm", ["install", "--frozen-lockfile"], cd: site)
    cmd!("pnpm", ["exec", "astro", "build"], cd: site)
    cmd!("pnpm", ["run", "verify:mermaid"], cd: site)

    dist = Path.join(site, "dist")

    unless File.dir?(dist) do
      Mix.raise("site/dist missing after astro build")
    end

    run_tool("bash", ["scripts/htmltest-ci.sh"], cd: site)

    run_tool(
      "lychee",
      [
        "--config",
        "site/lychee.toml",
        "--no-progress",
        "README.md",
        "CONTRIBUTING.md",
        "site/README.md",
        "site/src/content/docs"
      ],
      cd: File.cwd!()
    )

    run_tool(
      "typos",
      ["--config", "typos.toml", "README.md", "CONTRIBUTING.md", "AGENTS.md", "site"],
      cd: File.cwd!()
    )

    Mix.shell().info("[kiln] docs.verify completed")
  end

  defp run_tool(bin, args, opts) do
    case System.find_executable(bin) do
      nil ->
        Mix.raise("#{bin} not on PATH — install #{bin} or rely on GitHub Actions for docs gates")

      path ->
        {out, status} = System.cmd(path, args, opts ++ [stderr_to_stdout: true])
        Mix.shell().info(out)

        if status != 0 do
          Mix.raise("#{bin} exited #{status}")
        end
    end
  end

  defp cmd!(bin, args, opts) do
    {out, status} = System.cmd(bin, args, opts ++ [stderr_to_stdout: true])
    Mix.shell().info(out)

    if status != 0 do
      Mix.raise("#{bin} #{inspect(args)} failed with exit #{status}")
    end
  end
end
