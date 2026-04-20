import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
#
# T-02 mitigation: ALL env-var reads live in this file. Compile-time
# config (config/config.exs, dev.exs, test.exs, prod.exs) must not
# call `System.get_env/1,2` or `System.fetch_env!/1`. Plan 02 ships
# `mix check_no_compile_time_secrets` as the formalized grep gate.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/kiln start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :kiln, KilnWeb.Endpoint, server: true
end

config :kiln, KilnWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# MIX_TEST_PARTITION support (parallel CI DBs) — lives here to keep compile-time
# config free of env-var reads per T-02 mitigation.
if config_env() == :test do
  config :kiln, Kiln.Repo, database: "kiln_test#{System.get_env("MIX_TEST_PARTITION")}"
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # pool_size: 20 — D-68 budget calc: Oban aggregate 16 (D-67 six-queue
  # taxonomy) + plugin overhead ~2 + LiveView/`/ops/*` queries ~2 +
  # RunDirector + StuckDetector ~1 + request-spike headroom ~3 ≈ 24 peak
  # pressure vs 20 checkouts. Defensible because `:stages` concurrency (4)
  # is dominated by LLM-call wall-clock (minutes), not DB checkouts.
  # Revisit to 28 when Phase 3's provider-split queues activate (D-71).
  # Kiln.BootChecks.check_oban_queue_budget!/0 asserts the paired D-68
  # invariant: `sum(queue-concurrency) <= 16`.
  config :kiln, Kiln.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :kiln, KilnWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end

# D-48: two-role Postgres access model. Postgrex reads the `:parameters`
# keyword and issues `SET ROLE <role>` after connect, so every subsequent
# query in that session runs as the chosen role.
#
# Behavior by `KILN_DB_ROLE` value:
#
#   * unset (bootstrap / tooling like `mix ecto.drop|create|migrate`):
#     no role switch — the session keeps the connecting user. This avoids
#     the chicken-and-egg where `mix ecto.drop` tries to `SET ROLE kiln_app`
#     before migration 20260418000002 has created the role.
#   * `kiln_owner` (DDL: `KILN_DB_ROLE=kiln_owner mix ecto.migrate`):
#     session runs as kiln_owner; new tables are owned by it.
#   * `kiln_app` (runtime — application boot in dev/prod):
#     session runs with restricted privileges (no UPDATE/DELETE/TRUNCATE
#     on audit_events). This is the intended default once the DB is
#     fully migrated.
case System.get_env("KILN_DB_ROLE") do
  nil -> :ok
  "" -> :ok
  role -> config :kiln, Kiln.Repo, parameters: [role: role]
end

Kiln.Secrets.put(:anthropic_api_key, System.get_env("ANTHROPIC_API_KEY"))
Kiln.Secrets.put(:openai_api_key, System.get_env("OPENAI_API_KEY"))
Kiln.Secrets.put(:google_api_key, System.get_env("GOOGLE_API_KEY"))
Kiln.Secrets.put(:ollama_host, System.get_env("OLLAMA_HOST"))
