#!/usr/bin/env bash
# Dockerized-app smoke (Phase 36 followup, PR #1 chore/e2e-verification-cleanup).
# Sibling of test/integration/first_run.sh — same shape, different target:
# this exercises the dockerized `app` service in compose.yaml end-to-end.
#
# On failure: prints a fixed-format diagnostic dump (compose ps, per-service
# logs, in-container setup log, /health body, kiln_* volumes) so the dev
# loop is `run → read dump → fix → re-run` without any manual log paste.
#
# Usage:
#   bash script/compose_smoke.sh                 # cached re-run (fast path)
#   bash script/compose_smoke.sh --clean         # `down -v` first; exercises first-boot bootstrap
#   bash script/compose_smoke.sh --keep          # leave stack up on success
#   bash script/compose_smoke.sh --timeout 240   # /health poll deadline (default 180s)

set -euo pipefail

cd "$(dirname "$0")/.."

CLEAN=0
KEEP=0
TIMEOUT=180

while [ $# -gt 0 ]; do
  case "$1" in
    --clean) CLEAN=1; shift ;;
    --keep) KEEP=1; shift ;;
    --timeout) TIMEOUT="${2:?--timeout requires N}"; shift 2 ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "[compose_smoke] unknown arg: $1" >&2; exit 2 ;;
  esac
done

LP="[compose_smoke]"

echo "$LP checking prerequisites..."
for cmd in docker jq curl; do
  command -v "$cmd" >/dev/null || { echo "$LP FAIL: '$cmd' not on PATH"; exit 1; }
done

# Load .env so KILN_DB_HOST_PORT, PORT, SECRET_KEY_BASE, etc. resolve identically
# to operator's day-to-day flow (compose.yaml uses these via ${VAR:-default}).
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PORT="${PORT:-4000}"

# Early port-conflict check on app's host port. db port collision is already
# mitigated via KILN_DB_HOST_PORT in .env — no need to re-check here.
if lsof -iTCP:"$PORT" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
  HOLDER=$(lsof -iTCP:"$PORT" -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2 {print $1, $2}')
  echo "$LP FAIL: host port :$PORT is held by '$HOLDER'."
  echo "$LP   stop the conflicting process or set PORT in .env to a free port."
  exit 1
fi

TS_START=$(date +%s)
TMPDIR=$(mktemp -d -t compose_smoke.XXXXXX)
APP_LOG="$TMPDIR/app.log"
FOLLOW_PID=""
STAGE="0/6"
EXIT_CODE=0
DUMPED=0

_dump_diagnostics() {
  # Idempotent; called at most once per run.
  if [ "$DUMPED" -eq 1 ]; then return; fi
  DUMPED=1

  echo
  echo "$LP === [FAIL] stage $STAGE ==="
  echo
  echo "$LP === compose ps ==="
  docker compose ps 2>&1 || true
  for svc in db app dtu otel-collector; do
    local tail=200
    [ "$svc" = "otel-collector" ] && tail=50
    echo
    echo "$LP === service: $svc (last $tail) ==="
    docker compose logs --no-color --tail="$tail" "$svc" 2>&1 || true
  done
  echo
  echo "$LP === app follow log ($APP_LOG, last 400) ==="
  if [ -s "$APP_LOG" ]; then tail -n 400 "$APP_LOG"; else echo "(empty / not started)"; fi
  echo
  echo "$LP === in-container setup log (/tmp/setup.log) ==="
  docker compose exec -T app sh -c 'tail -n 200 /tmp/setup.log 2>/dev/null || echo "(no /tmp/setup.log)"' 2>&1 \
    || echo "(app container not reachable for exec)"
  echo
  echo "$LP === /health (best effort) ==="
  curl -sS -m 3 "http://localhost:${PORT}/health" 2>&1 || echo "(unreachable)"
  echo
  echo "$LP === docker version + kiln_* volumes ==="
  docker version --format 'server={{.Server.Version}} client={{.Client.Version}}' 2>&1 || true
  docker volume ls --filter name=kiln_ 2>&1 || true
  df -h "$(docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo /)" 2>&1 || true
  echo
  echo "$LP failure dump above. Tmp dir retained: $TMPDIR"
}

_on_exit() {
  local rc=$?
  EXIT_CODE=$rc
  if [ -n "$FOLLOW_PID" ]; then
    # `docker compose logs -f` spawns a docker-compose plugin child that
    # holds the pipe open and ignores SIGTERM on the parent — so we kill
    # the whole subtree (children first, then parent), without `wait`,
    # which would block forever on the orphaned grandchild.
    pkill -TERM -P "$FOLLOW_PID" 2>/dev/null || true
    kill -TERM "$FOLLOW_PID" 2>/dev/null || true
    sleep 1
    pkill -KILL -P "$FOLLOW_PID" 2>/dev/null || true
    kill -KILL "$FOLLOW_PID" 2>/dev/null || true
  fi
  if [ "$rc" -ne 0 ]; then
    _dump_diagnostics
    return
  fi
  if [ "$KEEP" -eq 1 ]; then
    echo "$LP --keep: containers retained. Re-run without --clean for fast iteration. PORT=$PORT"
    rm -rf "$TMPDIR"
    return
  fi
  echo "$LP tearing down (no -v, deps/build/pgdata cached for next run)..."
  docker compose down >/dev/null 2>&1 || true
  rm -rf "$TMPDIR"
}
trap _on_exit EXIT INT TERM

# ---- Stage 1/6 ---------------------------------------------------------------
STAGE="1/6"
echo "$LP [stage 1/6] compose config validation..."
docker compose config -q

# ---- Stage 2/6 ---------------------------------------------------------------
STAGE="2/6"
if [ "$CLEAN" -eq 1 ]; then
  echo "$LP [stage 2/6] --clean: docker compose down -v --remove-orphans..."
  docker compose down -v --remove-orphans
else
  echo "$LP [stage 2/6] (skipped — pass --clean to wipe volumes)"
fi

# ---- Stage 3/6 ---------------------------------------------------------------
STAGE="3/6"
echo "$LP [stage 3/6] docker compose build --pull app dtu..."
docker compose build --pull app dtu

# ---- Stage 4/6 ---------------------------------------------------------------
STAGE="4/6"
echo "$LP [stage 4/6] docker compose up -d db; waiting for healthy..."
docker compose up -d db
DB_READY=0
for _ in $(seq 1 60); do
  STATE=$(docker compose ps db --format json 2>/dev/null || echo '')
  # compose v2 returns either an array or a single object — handle both.
  if echo "$STATE" | jq -e '.Health == "healthy"' >/dev/null 2>&1 \
     || echo "$STATE" | jq -e '.[0].Health == "healthy"' >/dev/null 2>&1; then
    DB_READY=1
    break
  fi
  sleep 1
done
if [ "$DB_READY" -ne 1 ]; then
  echo "$LP db never reported healthy within 60s"
  exit 1
fi

# ---- Stage 5/6 ---------------------------------------------------------------
STAGE="5/6"
echo "$LP [stage 5/6] docker compose up -d app; tailing app log to $APP_LOG..."
docker compose up -d app
docker compose logs -f --no-color app >"$APP_LOG" 2>&1 &
FOLLOW_PID=$!

# ---- Stage 6/6 ---------------------------------------------------------------
STAGE="6/6"
echo "$LP [stage 6/6] polling http://localhost:${PORT}/health (timeout ${TIMEOUT}s)..."
HEALTH_OK=0
RESP=""
for _ in $(seq 1 "$TIMEOUT"); do
  if RESP=$(curl -sf -m 2 "http://localhost:${PORT}/health" 2>/dev/null); then
    if echo "$RESP" | jq -e '.status == "ok"' >/dev/null 2>&1 \
       && echo "$RESP" | jq -e '.postgres == "up"' >/dev/null 2>&1 \
       && echo "$RESP" | jq -e '.oban == "up"' >/dev/null 2>&1 \
       && echo "$RESP" | jq -e '.contexts == 13' >/dev/null 2>&1 \
       && echo "$RESP" | jq -e '.version | type == "string"' >/dev/null 2>&1; then
      HEALTH_OK=1
      break
    fi
  fi
  # Detect early death of app container so we don't burn the full timeout.
  if ! docker compose ps app --format json 2>/dev/null \
       | jq -e '(.State == "running") or (.[0].State == "running")' >/dev/null 2>&1; then
    echo "$LP app container is no longer running — aborting poll early"
    exit 1
  fi
  sleep 1
done

if [ "$HEALTH_OK" -ne 1 ]; then
  echo "$LP /health never returned all-green within ${TIMEOUT}s. Last response: ${RESP:-<none>}"
  exit 1
fi

ELAPSED=$(( $(date +%s) - TS_START ))
echo "$LP [OK] compose smoke green in ${ELAPSED}s — health=$(echo "$RESP" | jq -c .)"
