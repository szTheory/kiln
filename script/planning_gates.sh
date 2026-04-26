#!/usr/bin/env bash
# CI-parity gates before GSD gap planning (`/gsd-plan-phase N --gaps`).
# Env defaults mirror `.github/workflows/ci.yml` `check` job so local runs
# match GitHub without requiring a second mental model.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

derive_test_database_url() {
  local source_url base query
  source_url="${1:-ecto://kiln:kiln_dev@localhost:5432/kiln_dev}"
  base="${source_url%%\?*}"
  query=""

  if [ "$base" != "$source_url" ]; then
    query="?${source_url#*\?}"
  fi

  printf '%s/kiln_test%s\n' "${base%/*}" "$query"
}

derive_verifier_source_url() {
  local primary_url authority
  primary_url="${1:-ecto://kiln:kiln_dev@localhost:5432/kiln_dev}"
  authority="${primary_url#*://}"
  authority="${authority#*@}"
  printf 'ecto://kiln_verifier:kiln_dev_verifier@%s\n' "$authority"
}

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export MIX_ENV=test
unset KILN_DB_ROLE
export DATABASE_URL="$(derive_test_database_url "${DATABASE_URL:-}")"
verifier_source_url="${DATABASE_VERIFIER_URL:-$(derive_verifier_source_url "$DATABASE_URL")}"
export DATABASE_VERIFIER_URL="$(
  derive_test_database_url "$verifier_source_url"
)"
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-ci_only_64_byte_placeholder_replace_in_prod_xxxxxxxxxxxxxxxxxxxx}"
export PHX_HOST="${PHX_HOST:-localhost}"
export PORT="${PORT:-4000}"

env -u KILN_DB_ROLE mix ecto.drop --quiet >/dev/null 2>&1 || true
env -u KILN_DB_ROLE mix ecto.create --quiet >/dev/null
env -u KILN_DB_ROLE mix ecto.migrate --quiet >/dev/null

echo "[planning_gates] $(date -u +%Y-%m-%dT%H:%M:%SZ) MIX_ENV=test mix check (defaults match CI when vars unset)" >&2
exec mix check
