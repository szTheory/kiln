#!/usr/bin/env bash
# One-shot local bring-up: Compose Postgres → mix setup → Phoenix (foreground).
# KISS: no Kiln app container; matches README host-Phoenix model (Phase 12).
#
# Usage (from repo root):
#   bash script/dev_up.sh
# Or:
#   just dev
#
# Prerequisites: Docker + Compose v2, Elixir/Mix on PATH, optional `just`.
# Loads `.env` when present; creates from `.env.sample` if missing.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  echo "[dev_up] FAIL: docker compose not available"
  exit 1
fi
command -v mix >/dev/null || {
  echo "[dev_up] FAIL: mix not on PATH"
  exit 1
}

if [ ! -f .env ]; then
  cp .env.sample .env
  echo "[dev_up] created .env from .env.sample — set SECRET_KEY_BASE before production (mix phx.gen.secret)"
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

export MIX_ENV=dev

echo "[dev_up] docker compose up -d db..."
docker compose up -d db

echo "[dev_up] waiting for Postgres (pg_isready)..."
for _ in $(seq 1 60); do
  if docker compose exec -T db pg_isready -U kiln >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker compose exec -T db pg_isready -U kiln >/dev/null 2>&1; then
  echo "[dev_up] FAIL: Postgres did not become ready (check compose logs, DATABASE_URL, KILN_DB_HOST_PORT)"
  exit 1
fi

# Path segment after the last "/" in DATABASE_URL (strip ?query); default matches compose POSTGRES_DB.
dev_up_database_name() {
  url="${DATABASE_URL:-ecto://kiln:kiln_dev@127.0.0.1:5432/kiln_dev}"
  x="${url%%\?*}"
  db="${x##*/}"
  if [ -z "$db" ] || [ "$db" = "$x" ]; then
    echo "kiln_dev"
  else
    echo "$db"
  fi
}

# D-48: migrate without KILN_DB_ROLE creates schema_migrations as user `kiln`; later
# KILN_DB_ROLE=kiln_owner cannot lock it (42501). Align owner whenever the table exists.
ensure_schema_migrations_owned_by_kiln_owner() {
  db_name="$(dev_up_database_name)"
  if docker compose exec -T db psql -U kiln -d "$db_name" -v ON_ERROR_STOP=1 -c \
    "ALTER TABLE IF EXISTS public.schema_migrations OWNER TO kiln_owner;" >/dev/null 2>&1; then
    echo "[dev_up] schema_migrations owner OK (kiln_owner) for database ${db_name}"
  else
    echo "[dev_up] note: could not align schema_migrations owner (normal on first boot before migrations)"
  fi
}

ensure_schema_migrations_owned_by_kiln_owner

bootstrap_first_roles() {
  echo "[dev_up] first-time DB bootstrap (roles/tables) — running without KILN_DB_ROLE..."
  env -u KILN_DB_ROLE mix ecto.create || true
  env -u KILN_DB_ROLE mix ecto.migrate
  ensure_schema_migrations_owned_by_kiln_owner
  mix run priv/repo/seeds.exs
  printf 'n\n' | mix do assets.setup + assets.build
}

SETUP_ERR="${TMPDIR:-/tmp}/kiln_dev_up.$$.log"
set +e
printf 'n\n' | KILN_DB_ROLE=kiln_owner mix setup >"${SETUP_ERR}" 2>&1
setup_code=$?
set -e
if [ "${setup_code}" -ne 0 ]; then
  if grep -qE 'role "kiln_owner" does not exist|FATAL 22023' "${SETUP_ERR}"; then
    bootstrap_first_roles
    printf 'n\n' | KILN_DB_ROLE=kiln_owner mix setup
  else
    cat "${SETUP_ERR}" >&2
    rm -f "${SETUP_ERR}"
    exit "${setup_code}"
  fi
fi
rm -f "${SETUP_ERR}"

ensure_schema_migrations_owned_by_kiln_owner

echo "[dev_up] starting Phoenix — http://localhost:${PORT:-4000}/onboarding (Ctrl+C to stop)"
exec env -u KILN_DB_ROLE mix phx.server
