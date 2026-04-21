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

# SPEC-04: verifier role credentials (migration `HoldoutPrivileges`); DB name
# patched for MIX_TEST_PARTITION in `config/runtime.exs` (T-02).
config :kiln, Kiln.Repo.VerifierReadRepo,
  username: "kiln_verifier",
  password: "kiln_dev_verifier",
  hostname: "localhost",
  database: "kiln_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Kiln.Artifacts CAS + tmp roots (D-77). Point test writes at a
# stable per-test-env directory under System.tmp_dir!() so unit tests
# never pollute priv/artifacts (dev) or the prod CAS.
#
# The paths are stable (NOT per-invocation-unique) because
# `Kiln.Artifacts.CAS` uses `Application.compile_env/3` to capture these
# at module compile time — any drift between compile-time and runtime
# values raises `:validate_compile_env` at boot. Content-addressed dedup
# means test writes to the same bytes produce the same path, so
# stability is safe: either the file already exists with correct bytes
# (dedup hit) or this test is the first writer. Kiln.CasTestHelper is
# retained for tests that want the env override semantics for other
# `Application.get_env` readers (e.g. future GC workers).
config :kiln, :artifacts,
  cas_root: Path.join(System.tmp_dir!(), "kiln_test_cas"),
  tmp_root: Path.join(System.tmp_dir!(), "kiln_test_tmp")

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kiln, KilnWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Aq5xnGbPos5QP1UIZ3Ri3NUVE4jcmPxxt1LZIbPMEqgXxfzp7o0RAjW4PCc3D6BL",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Oban in manual testing mode (D-47 metadata-threading test calls
# `Oban.drain_queue/1` explicitly — :inline mode can bypass the
# `[:oban, :job, :start]` telemetry handler in some Oban 2.21 paths,
# and manual drain is deterministic).
config :kiln, Oban, testing: :manual

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
