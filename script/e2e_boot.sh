#!/usr/bin/env bash
# Boot Kiln for Playwright e2e:
#
#   1. docker compose up -d db
#   2. KILN_DB_ROLE=kiln_owner mix setup (create + migrate; idempotent)
#   3. mix run priv/repo/seeds_e2e.exs (upserts canonical fixtures,
#      writes test/e2e/.fixture-ids.json)
#   4. KILN_SKIP_OPERATOR_READINESS=1 mix phx.server (background)
#   5. Wait for /health up to 60s
#
# Exports $PHX_PID for the caller (CI / just / mix task) to tear down.
# Idempotent: safe to run against an already-up stack — seeds upsert,
# health-check short-circuits once the endpoint responds.
#
# Usage:
#   bash script/e2e_boot.sh
#   KILN_E2E_BASE_URL=http://localhost:4000 bash script/e2e_boot.sh
#
# Env overrides:
#   PHX_PORT       — default 4000
#   HEALTH_TIMEOUT — default 60 (seconds)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PHX_PORT="${PHX_PORT:-4000}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
LOG_DIR="${TMPDIR:-/tmp}"
PHX_LOG="${LOG_DIR}/kiln_e2e_phx.log"

echo "[e2e_boot] docker compose up -d db..."
docker compose up -d db

echo "[e2e_boot] waiting for Postgres (pg_isready)..."
for _ in $(seq 1 60); do
  if docker compose exec -T db pg_isready -U kiln >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker compose exec -T db pg_isready -U kiln >/dev/null 2>&1; then
  echo "[e2e_boot] FAIL: Postgres did not become ready"
  exit 1
fi

echo "[e2e_boot] mix setup (create + migrate as kiln_owner)..."
printf 'n\n' | KILN_DB_ROLE=kiln_owner mix setup

echo "[e2e_boot] seeding e2e fixtures..."
mix run priv/repo/seeds_e2e.exs

# Fast-path: if something is already listening on PHX_PORT and
# /health returns 200, reuse it instead of double-booting.
if curl -fsS "http://localhost:${PHX_PORT}/health" >/dev/null 2>&1; then
  echo "[e2e_boot] Phoenix already up on :${PHX_PORT} — reusing existing server"
  exit 0
fi

echo "[e2e_boot] starting Phoenix on :${PHX_PORT} (log: ${PHX_LOG})..."
KILN_SKIP_OPERATOR_READINESS=1 \
  PORT="${PHX_PORT}" \
  mix phx.server >"${PHX_LOG}" 2>&1 &
PHX_PID=$!
export PHX_PID
echo "[e2e_boot] PHX_PID=${PHX_PID}"

echo "[e2e_boot] waiting up to ${HEALTH_TIMEOUT}s for /health..."
for _ in $(seq 1 "${HEALTH_TIMEOUT}"); do
  if curl -fsS "http://localhost:${PHX_PORT}/health" >/dev/null 2>&1; then
    echo "[e2e_boot] /health OK — Phoenix ready on :${PHX_PORT}"
    echo "[e2e_boot] tear-down: kill ${PHX_PID}"
    exit 0
  fi
  if ! kill -0 "${PHX_PID}" 2>/dev/null; then
    echo "[e2e_boot] FAIL: Phoenix process exited early. Log tail:"
    tail -n 80 "${PHX_LOG}" || true
    exit 1
  fi
  sleep 1
done

echo "[e2e_boot] FAIL: /health not ready after ${HEALTH_TIMEOUT}s. Log tail:"
tail -n 80 "${PHX_LOG}" || true
kill "${PHX_PID}" 2>/dev/null || true
exit 1
