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

  config :kiln, Kiln.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
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

# KILN_DB_ROLE switching hook (Plan 03 activates; stub in P1)
# config :kiln, Kiln.Repo, parameters: [role: System.get_env("KILN_DB_ROLE", "kiln_app")]
