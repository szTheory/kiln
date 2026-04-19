import Config

# Configure your database
#
# Per T-02 (proactive), env-variable reads are forbidden in compile-time config
# files — all env reads happen in config/runtime.exs. The MIX_TEST_PARTITION env
# var (used for parallel CI test DBs) is therefore read in runtime.exs and
# overrides `:database` below.
config :kiln, Kiln.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "kiln_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kiln, KilnWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Aq5xnGbPos5QP1UIZ3Ri3NUVE4jcmPxxt1LZIbPMEqgXxfzp7o0RAjW4PCc3D6BL",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
