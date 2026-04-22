defmodule Kiln.MixProject do
  use Mix.Project

  def project do
    [
      app: :kiln,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      # Dialyzer (D-27) — PLT cached at priv/plts; cache key in
      # .github/workflows/ci.yml is keyed on ${OS}-${OTP}-${ELIXIR}-${hashFiles('mix.lock')}.
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_core_path: "priv/plts",
        # :credo is required because lib/kiln/credo/* modules use the
        # `Credo.Check` behaviour. `runtime: false` in mix.exs means it is
        # not loaded at app boot, but Dialyzer still needs the specs.
        plt_add_apps: [
          :ex_unit,
          :mix,
          :oban,
          :phoenix_live_dashboard,
          :oban_web,
          :credo
        ],
        ignore_warnings: ".dialyzer_ignore.exs",
        flags: [:error_handling, :extra_return, :missing_return, :underspecs]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Kiln.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phoenix + LV (LOCKED per D-01, STACK.md, LOCAL-02)
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.22"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.1.28"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.10"},

      # Data / HTTP / LLM
      {:req, "~> 0.5"},
      {:finch, "~> 0.19"},
      {:anthropix, "~> 0.6"},

      # Sandbox (Phase 3; D-115/D-120/D-154)
      # - muontrap: crash-safe `docker run` wrapper (supervised Port/cgroup child)
      # - ex_docker_engine_api: Docker Engine API client for OrphanSweeper LIST ops
      #   (destroy path remains `System.cmd("docker", ...)` per D-120).
      #   NOTE: package is versioned against the Docker Engine API revision it
      #   targets (1.43.x → Docker Engine 24+ / 25+), not abstract semver. The
      #   plan text "~> 7.0" was incorrect — Hex only publishes 1.43.x.
      {:muontrap, "~> 1.7"},
      {:ex_docker_engine_api, "~> 1.43"},

      # Workflow / audit
      {:yaml_elixir, "~> 2.12"},
      {:jsv, "~> 0.18"},

      # Durable jobs
      {:oban, "~> 2.21"},
      {:oban_web, "~> 2.12"},

      # Logging / observability
      {:logger_json, "~> 7.0"},
      {:opentelemetry, "~> 1.6"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_bandit, "~> 0.3"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_oban, "~> 1.2"},
      {:opentelemetry_process_propagator, "~> 0.3.0"},
      {:telemetry, "~> 1.3"},

      # Dev/test tooling (Plan 02 wires `.check.exs`; deps ship here)
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_envvar, "~> 0.1", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:mox, "~> 1.2", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind kiln", "esbuild kiln"],
      "assets.deploy": ["tailwind kiln --minify", "esbuild kiln --minify", "phx.digest"],
      # Phase 10 / D-1005 — single SSOT: shell script only (no duplicated compose/migrate logic).
      "integration.first_run": &integration_first_run/1
    ]
  end

  defp integration_first_run(_args) do
    script = Path.expand("test/integration/first_run.sh", File.cwd!())

    unless File.exists?(script) do
      Mix.raise("missing #{script}")
    end

    Mix.shell().info("[integration.first_run] #{script}")
    {output, status} = System.cmd("bash", [script], stderr_to_stdout: true)

    if output != "", do: Mix.shell().info(String.trim_trailing(output))

    if status != 0 do
      Mix.raise("integration.first_run failed (exit #{status})")
    end
  end
end
