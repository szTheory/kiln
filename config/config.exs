# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kiln,
  ecto_repos: [Kiln.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  # Phase 999.2: operator shell labels demo vs live; overridden in dev/test/runtime.
  operator_runtime_mode: :live,
  # Plan 06 / D-32: BootChecks.run!/0 reads :kiln, :env at runtime to
  # decide which secrets are required (prod/dev differ). `Mix.env()` is
  # evaluated here at COMPILE time — `config/*.exs` files are part of
  # the build, not the runtime path. The Kiln.Credo.NoMixEnvAtRuntime
  # check exempts `config/*.exs` for exactly this reason (see
  # lib/kiln/credo/no_mix_env_at_runtime.ex).
  env: Mix.env()

# Phase 18 COST-02 — soft budget threshold bands (% of `max_tokens_usd`).
config :kiln, Kiln.BudgetAlerts,
  soft_thresholds_pct: [50, 80]

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

# Oban configuration (D-44 + D-67..D-69 — six per-concern queues per Phase 2
# D-67; aggregate concurrency = 16; Kiln.BootChecks.check_oban_queue_budget!/0
# asserts `sum(values) <= 16` at boot so any future plan silently raising a
# queue cannot saturate the Postgres pool — see lib/kiln/boot_checks.ex.
#
# Queues (D-67):
#   * `:default`     (2) — ad-hoc / one-offs / anything without an explicit
#       queue. Deliberately small so a mis-routed `:stages` job shows up
#       immediately as a `:default` backlog, not a silent slot-steal.
#   * `:stages`      (4) — stage dispatch (Kiln.Stages.StageWorker arrives in
#       Plan 05). 4 = 2 parallel runs × 2 parallel stages, solo-op ceiling.
#   * `:github`      (2) — git / gh CLI shell-outs. Scaffolded here;
#       activated in Phase 6.
#   * `:audit_async` (4) — non-transactional audit appends.
#   * `:dtu`         (2) — DTU mock contract tests + health polls.
#       Scaffolded here; activated in Phase 3.
#   * `:maintenance` (2) — cron destinations: 30-day external_operations
#       pruner (P1), Phase 5 StuckDetector worker, Phase 3 DTU weekly
#       contract test, Phase 5 Artifacts Gc/Scrub workers.
#
# Plugins:
#   * `Oban.Plugins.Pruner` — deletes Oban's own completed/discarded job
#     rows after 7 days (not Kiln.ExternalOperations.Pruner).
#   * `Oban.Plugins.Cron` — triggers `Kiln.ExternalOperations.Pruner`
#     daily at 03:00 UTC (D-19). Four additional entries are commented
#     out until their owning plans activate them.
config :kiln, Oban,
  repo: Kiln.Repo,
  engine: Oban.Engines.Basic,
  queues: [
    default: 2,
    stages: 4,
    github: 2,
    audit_async: 4,
    dtu: 2,
    maintenance: 2
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", Kiln.ExternalOperations.Pruner, queue: :maintenance}
       # {"*/5 * * * *", Kiln.Policies.StuckDetectorWorker, queue: :maintenance},  # P5 activation
       # {"0 4 * * 0", Kiln.Sandboxes.DTU.ContractTestWorker, queue: :maintenance}, # P3 activation
       # {"15 2 * * *", Kiln.Artifacts.GcWorker, queue: :maintenance},              # P5 activation (Plan 02-03 shipped the worker stub)
       # {"30 2 * * 0", Kiln.Artifacts.ScrubWorker, queue: :maintenance}            # P5 activation (Plan 02-03 shipped the worker stub)
     ]}
  ]

# LoggerJSON (D-45, D-46, D-47) — structured JSON logging with the six
# mandatory metadata keys on every log line (OBS-01). Two parts:
#
#   * `:default_handler` — swaps the Erlang logger's stock text formatter
#     for `LoggerJSON.Formatters.Basic`. Tuple form is required in
#     compile-time config (`LoggerJSON.Formatters.Basic.new/1` isn't
#     callable here).
#   * `:default_handler.filters` — `Kiln.Logger.Metadata.default_filter/2`
#     defaults the six D-46 keys to `:none` (rendered `"none"` in JSON)
#     when absent, so grep pipelines see a consistent schema even for
#     log lines emitted before any scope-setter ran.
#
# `:default_formatter` stays set too so any handler that falls back to
# the generic formatter (e.g. in unusual test harnesses) still whitelists
# the same keys.
config :logger, :default_formatter,
  metadata: [:correlation_id, :causation_id, :actor, :actor_role, :run_id, :stage_id]

config :logger, :default_handler,
  formatter: {
    LoggerJSON.Formatters.Basic,
    # D-133 Layer 4: scrub secret-shaped keys + values from structured
    # log metadata BEFORE serialisation. The tuple form is required in
    # compile-time config (`Kiln.Logging.SecretRedactor.new/1` isn't
    # defined — the `@optional_callbacks new: 1` behaviour contract
    # lets redactors ship without one, and LoggerJSON resolves the
    # tuple per log line).
    metadata: [:correlation_id, :causation_id, :actor, :actor_role, :run_id, :stage_id],
    redactors: [{Kiln.Logging.SecretRedactor, []}]
  },
  filters: [
    kiln_metadata_defaults: {&Kiln.Logger.Metadata.default_filter/2, []}
  ],
  filters_config: [
    # `:log` keeps the (possibly mutated) log event flowing through the
    # handler. `:stop` would drop the line entirely.
    default: :log
  ]

# D-133 Layer 4 companion registration — the LoggerJSON 7.x app config
# reads `:redactors` at the top level of the `:logger_json` app so any
# handler that creates a formatter via
# `LoggerJSON.Formatters.<F>.new/1` at runtime (config/runtime.exs,
# test harnesses) picks up the redactor automatically. Both the
# handler-level (`default_handler.formatter.redactors`) registration
# above and this app-level registration point at the same redactor
# module; multiple registrations are idempotent (the redactor is
# stateless).
config :logger_json, :redactors, [{Kiln.Logging.SecretRedactor, []}]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
