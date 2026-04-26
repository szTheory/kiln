#!/usr/bin/env bash
# Docker-only dev startup. Postgres health is guaranteed by compose depends_on.
set -euo pipefail

# Auto-generate SECRET_KEY_BASE if missing or still the placeholder value.
if [ -z "${SECRET_KEY_BASE:-}" ] || echo "${SECRET_KEY_BASE}" | grep -q "replace_me"; then
  export SECRET_KEY_BASE
  SECRET_KEY_BASE=$(openssl rand -hex 32)
  echo "[kiln] INFO: auto-generated SECRET_KEY_BASE for this session — set it in .env to persist across restarts"
fi

# Auto-generate CLOAK_KEY (Sigra/Cloak vault, required by Kiln.Vault since Phase 36-01).
# Must be a 32-byte Base64 value. Per-session key is fine in dev (no persisted encrypted
# data crosses restarts); prod sets this explicitly via secret store.
if [ -z "${CLOAK_KEY:-}" ] || echo "${CLOAK_KEY}" | grep -q "replace_me"; then
  export CLOAK_KEY
  CLOAK_KEY=$(openssl rand -base64 32)
  echo "[kiln] INFO: auto-generated CLOAK_KEY for this session — set it in .env to persist across restarts"
fi

echo "[kiln] fetching mix deps..."
mix deps.get --only dev

echo "[kiln] running setup..."
# Fixed path so script/compose_smoke.sh can recover output via
# `docker compose exec -T app tail /tmp/setup.log` after a failure.
SETUP_LOG=/tmp/setup.log

# Mirror dev_up.sh: try with kiln_owner; on first boot roles don't exist yet,
# so fall back to the connecting superuser to bootstrap them via migration 002.
if ! printf 'n\n' | KILN_DB_ROLE=kiln_owner mix setup >"$SETUP_LOG" 2>&1; then
  if grep -qE 'role "kiln_owner" does not exist|FATAL 22023' "$SETUP_LOG"; then
    echo "[kiln] first-time bootstrap — creating roles via migration..."
    mix ecto.create 2>/dev/null || true
    mix ecto.migrate
    mix run priv/repo/seeds.exs
    printf 'n\n' | mix assets.setup
    mix assets.build
  else
    cat "$SETUP_LOG" >&2
    exit 1
  fi
fi

echo "[kiln] Phoenix starting — http://localhost:${PORT:-4000}"
exec mix phx.server
