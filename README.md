# Kiln

Software dark factory written in Elixir/Phoenix LiveView. Given a spec, ships working software end-to-end with no human intervention.

See `.planning/PROJECT.md` for full vision.

## First run (fresh clone)

Prerequisites: `asdf`, `direnv`, Docker Desktop (or Docker Engine + Compose plugin).

```bash
# 1. Toolchain
asdf install

# 2. Env
cp .env.sample .env
direnv allow    # or: set -a; source .env; set +a

# 3. Database
docker compose up -d db

# 4. App
mix setup
mix phx.server
```

Open:

- `http://localhost:4000/` — redirects to LiveDashboard
- `http://localhost:4000/ops/dashboard` — Phoenix LiveDashboard (VM metrics, processes, Ecto queries)
- `http://localhost:4000/ops/oban` — Oban.Web (durable job registry)
- `http://localhost:4000/health` — health check JSON (Plan 06 wires this fully)

## Running the test suite

```bash
mix check        # full gate: format + compile + test + credo + dialyzer + sobelow + mix_audit + xref + kiln.boot_checks
mix test --stale # fast local loop
```

## Running the integration smoke test (LOCAL-01 validation)

```bash
bash test/integration/first_run.sh
```

This exercises the fresh-clone UX end-to-end: `.env` copy, `docker compose up -d db`, `mix setup`, `mix phx.server`, and `curl /health` returning `{"status":"ok",...}` with all four dependency fields (`postgres`, `oban`, `contexts`, `version`) green. Requires `jq`, `curl`, `lsof` on PATH.

If host port 5432 is held by another container, the script fails fast with a clear operator message + two remediation options (stop the other container, or remap Kiln's compose port). See `.planning/STATE.md > Deferred Items` for the known `sigra-uat-postgres` conflict on this host.

### Running migrations

Plan 03 introduces a two-role Postgres model (`kiln_owner` owns DDL, `kiln_app` is the runtime role). Migrations must be run as `kiln_owner`:

```bash
KILN_DB_ROLE=kiln_owner mix ecto.migrate
```

See `config/runtime.exs` for the `KILN_DB_ROLE` switch. The default runtime role is `kiln_app`; only migration / DDL operations need `kiln_owner`.

### Bypassing boot checks (emergency only)

`Kiln.BootChecks.run!/0` asserts the durability-floor invariants at every boot. If you genuinely need to boot with a broken floor (e.g. debugging a migration mid-flight), set `KILN_SKIP_BOOTCHECKS=1`:

```bash
KILN_SKIP_BOOTCHECKS=1 mix phx.server
```

The skip emits a loud error-level log line — never use in production.

## License

Private / personal project. See LICENSE (TBD in Phase 9 release prep).
