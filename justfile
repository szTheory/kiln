# Optional local orchestration (Phase 12, LOCAL-DX-01).
# Compose runs the data plane; Phoenix stays on the host (`mix phx.server`).
# See README "Optional: Just recipes".

set dotenv-load := true

default:
    @just --list

# Postgres (service name `db` in compose.yaml).
db-up:
    docker compose up -d db

# DTU mock HTTP for sandbox-backed stages.
dtu-up:
    docker compose up -d dtu

# Local trace pipeline (matches README "Traces (local)").
otel-up:
    docker compose up -d otel-collector jaeger

# One-shot DDL + migrate + seeds + assets as DB owner (README step 3).
setup:
    KILN_DB_ROLE=kiln_owner mix setup

# Machine smoke SSOT — do not duplicate script logic here.
smoke:
    bash test/integration/first_run.sh

# Dockerized-app smoke (compose `app` service to /health). Fast cached re-run.
# See `script/compose_smoke.sh`.
compose-smoke:
    bash script/compose_smoke.sh

# Same, but `down -v` first → exercises first-boot bootstrap (migration 002 grants).
compose-smoke-fresh:
    bash script/compose_smoke.sh --clean

# Start DB only, then hand off to host Phoenix in another shell.
dev-deps: db-up
    @echo 'Postgres is up — run `mix phx.server` in another terminal (Phoenix stays on the host).'

# One command: Postgres + `mix setup` + `mix phx.server` (foreground). See `script/dev_up.sh`.
dev:
    bash script/dev_up.sh

# Same env contract as `script/planning_gates.sh` / CI — loads `.env` when present
# (`dotenv-load` above) so `DATABASE_URL` is not missing.
precommit:
    bash script/precommit.sh

# CI-parity `mix check` (shift-left) before `/gsd-plan-phase N --gaps`. Requires
# Postgres on `DATABASE_URL` (defaults match `.github/workflows/ci.yml`).
planning-gates:
    bash script/planning_gates.sh

# Full shift-left: `mix check` + integration smoke (`first_run.sh`: Docker DB,
# host Phoenix, `/health`). One command — no separate manual smoke pass.
# `SHIFT_LEFT_SKIP_INTEGRATION=1 just shift-left` runs only `mix check`.
shift-left:
    bash script/shift_left_verify.sh

# Runs `shift-left`, then prints the Cursor command for gap mode.
before-plan-phase phase:
    bash script/shift_left_verify.sh
    @echo "Verification passed — run: /gsd-plan-phase {{phase}} --gaps"

# Boot Phoenix (compose DB + seed fixtures + host Phoenix on :4000) and run
# the full Playwright suite — all 14 LV routes x light/dark x mobile/desktop
# + axe-core a11y. Tears down the server when Playwright exits.
e2e:
    mix kiln.e2e

# Same as `just e2e` but opens Playwright's watch UI (great for local
# debugging of a single spec).
e2e-ui:
    mix kiln.e2e --ui

