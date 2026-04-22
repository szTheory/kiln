#!/usr/bin/env bash
# Run `mix precommit` with the same **defaults as CI** when env is thin
# (e.g. agent sandboxes, fresh shells). Matches `script/planning_gates.sh`
# + `.github/workflows/ci.yml` `check` job for `MIX_ENV`, `DATABASE_URL`,
# `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`.
#
# If `.env` exists, it is sourced first so local `kiln:kiln_dev@localhost:5432/kiln_dev`
# still wins when `DATABASE_URL` is set there.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$root"

export MIX_ENV="${MIX_ENV:-test}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

export DATABASE_URL="${DATABASE_URL:-ecto://postgres:postgres@localhost:5432/kiln_test}"
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-ci_only_64_byte_placeholder_replace_in_prod_xxxxxxxxxxxxxxxxxxxx}"
export PHX_HOST="${PHX_HOST:-localhost}"
export PORT="${PORT:-4000}"

exec mix precommit "$@"
