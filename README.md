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
mix check        # full gate: format + compile + test + credo + dialyzer + sobelow + mix_audit + xref
mix test --stale # fast local loop
```

## License

Private / personal project. See LICENSE (TBD in Phase 9 release prep).
