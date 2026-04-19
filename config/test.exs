import Config

# Configure your database.
#
# Matches compose.yaml credentials (kiln / kiln_dev). The base database
# name is kiln_test; the MIX_TEST_PARTITION env var (parallel CI test
# DBs) is appended in config/runtime.exs per T-02 (no env reads in
# compile-time config).
config :kiln, Kiln.Repo,
  username: "kiln",
  password: "kiln_dev",
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
