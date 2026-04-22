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

# Start DB only, then hand off to host Phoenix in another shell.
dev-deps: db-up
    @echo 'Postgres is up — run `mix phx.server` in another terminal (Phoenix stays on the host).'

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

