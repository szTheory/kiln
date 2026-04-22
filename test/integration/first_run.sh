#!/usr/bin/env bash
# LOCAL-01 / VALIDATION.md behavior 42 — fresh-clone first-run smoke
# test.  Not wired into `mix check` (requires Docker + jq); run locally
# when compose.yaml, mix setup aliases, or the Kiln.HealthPlug contract
# changes.
#
# README alignment (Phase 9 / D-932): this script does **not** install
# Erlang/Elixir. Match the README “Prerequisites” contract — `mix` must
# already be on PATH (via asdf, mise, rtx, distro packages, etc.). The
# script never runs `asdf install`; optional **direnv** only loads `.env`.
#
# Prerequisites: Docker Desktop (or Engine + Compose v2), jq, curl, lsof,
# plus Elixir/Mix on PATH per `.tool-versions` / README.
#
# Steps (D-40 first-run UX):
#   1. cp .env.sample .env (if missing)
#   2. docker compose up -d db (+ wait for healthy)
#   3. KILN_DB_ROLE=kiln_owner mix setup
#   4. mix phx.server &
#   5. curl localhost:4000/health, assert status=="ok" + all four
#      dependency fields green (behavior 42).

set -euo pipefail

cd "$(dirname "$0")/../.."

echo "[first_run] checking prerequisites..."
for cmd in docker jq curl lsof; do
  command -v "$cmd" >/dev/null || {
    echo "[first_run] FAIL: '$cmd' not on PATH"
    echo "[first_run]   install: brew install ${cmd} (or apt/yum equivalent)"
    exit 1
  }
done

# The sigra-uat-postgres container is a known-long-term operator
# blocker on this dev host (see .planning/STATE.md > Deferred Items).
# Detect the conflict up front and give a clear operator message so
# the run doesn't fail mysteriously deep in `docker compose up`.
if lsof -iTCP:5432 -sTCP:LISTEN -P -n >/dev/null 2>&1; then
  HOLDER=$(docker ps --filter "publish=5432" --format '{{.Names}}' | head -1)
  if [ -n "$HOLDER" ] && [ "$HOLDER" != "kiln-db-1" ] && [ "$HOLDER" != "kiln_db_1" ]; then
    cat <<EOF
[first_run] FAIL: host port 5432 is held by Docker container '$HOLDER'.
           Kiln's compose.yaml maps 5432:5432 and cannot start while
           another container holds the port.

           Operator action (pick one):
             1. Stop the conflicting container:
                  docker stop $HOLDER
             2. Or: edit compose.yaml to remap (e.g., "5433:5432") and
                update .env DATABASE_URL to match.

           After resolving, re-run: bash test/integration/first_run.sh
EOF
    exit 1
  fi
fi

echo "[first_run] preparing .env..."
if [ ! -f .env ]; then
  cp .env.sample .env
  echo "[first_run]   created .env from .env.sample (edit before production use)"
fi

# Load env into the current shell so subsequent `mix` calls see the
# same DATABASE_URL + SECRET_KEY_BASE as the operator's day-to-day
# flow (direnv's `dotenv .env` path).
set -a
# shellcheck disable=SC1091
source .env
set +a

echo "[first_run] docker compose up -d db..."
docker compose up -d db

echo "[first_run] waiting for Postgres healthcheck..."
for _ in $(seq 1 30); do
  if docker compose ps db --format json 2>/dev/null | jq -e '.Health == "healthy"' >/dev/null 2>&1 ||
    docker compose ps db --format json 2>/dev/null | jq -e '.[0].Health == "healthy"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[first_run] mix setup (KILN_DB_ROLE=kiln_owner for DDL)..."
KILN_DB_ROLE=kiln_owner mix setup

echo "[first_run] starting phx.server in background..."
mix phx.server &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

echo "[first_run] waiting for /health..."
for _ in $(seq 1 30); do
  if curl -sf localhost:4000/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[first_run] asserting /health returns status=ok + all four dependency fields green..."
RESP=$(curl -sf localhost:4000/health)
echo "[first_run]   response: $RESP"

echo "$RESP" | jq -e '.status == "ok"' >/dev/null
echo "$RESP" | jq -e '.postgres == "up"' >/dev/null
echo "$RESP" | jq -e '.oban == "up"' >/dev/null
echo "$RESP" | jq -e '.contexts == 12' >/dev/null
echo "$RESP" | jq -e '.version | type == "string"' >/dev/null

echo "[first_run] OK — fresh-clone boot reached /health with all dependency fields green."
