# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kiln,
  ecto_repos: [Kiln.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :kiln, KilnWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KilnWeb.ErrorHTML, json: KilnWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kiln.PubSub,
  live_view: [signing_salt: "Pz7cOVxP"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  kiln: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  kiln: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Oban configuration (D-44 — safer defaults; full base worker lands in Plan 04)
config :kiln, Oban,
  repo: Kiln.Repo,
  engine: Oban.Engines.Basic,
  queues: [default: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ]

# LoggerJSON (D-45, D-46) — consumed fully in Plan 05
config :logger, :default_formatter,
  metadata: [:correlation_id, :causation_id, :actor, :actor_role, :run_id, :stage_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
