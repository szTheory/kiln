#!/usr/bin/env bash
# Run `mix precommit` with the same **defaults as CI** when env is thin
# (e.g. agent sandboxes, fresh shells). Matches `script/planning_gates.sh`
# + `.github/workflows/ci.yml` `check` job for `MIX_ENV`, `DATABASE_URL`,
# `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`.
#
# If `.env` exists, it is sourced first for non-DB vars. Under `MIX_ENV=test`
# we still force the CI-parity test database unless
# `PRECOMMIT_PRESERVE_DATABASE_URL=1` is set explicitly.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
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

export MIX_ENV="${MIX_ENV:-test}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [ "$MIX_ENV" = "test" ] && [ "${PRECOMMIT_PRESERVE_DATABASE_URL:-0}" != "1" ]; then
  # `.env` and the caller shell are usually the developer's dev DB
  # contract. Precommit runs under MIX_ENV=test, so keep those values for
  # non-DB vars but force the CI-parity test database by default.
  # The restricted runtime role is correct for app boot, but `mix check`
  # also creates/migrates the test database and must not inherit a
  # persistent `KILN_DB_ROLE=kiln_app` from `.env`.
  unset KILN_DB_ROLE
  export DATABASE_URL="$(derive_test_database_url "${DATABASE_URL:-}")"
  verifier_source_url="${DATABASE_VERIFIER_URL:-$(derive_verifier_source_url "$DATABASE_URL")}"
  export DATABASE_VERIFIER_URL="$(
    derive_test_database_url "$verifier_source_url"
  )"
else
  export DATABASE_URL="${DATABASE_URL:-ecto://postgres:postgres@localhost:5432/kiln_test}"
fi
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-ci_only_64_byte_placeholder_replace_in_prod_xxxxxxxxxxxxxxxxxxxx}"
export PHX_HOST="${PHX_HOST:-localhost}"
export PORT="${PORT:-4000}"

if [ "$MIX_ENV" = "test" ]; then
  # Keep local gates aligned with CI rather than inheriting a stale
  # developer-owned `kiln_test` schema_migrations table from earlier
  # role-switch experiments.
  env -u KILN_DB_ROLE mix ecto.drop --quiet >/dev/null 2>&1 || true
  env -u KILN_DB_ROLE mix ecto.create --quiet >/dev/null
  env -u KILN_DB_ROLE mix ecto.migrate --quiet >/dev/null
fi

exec mix precommit "$@"
