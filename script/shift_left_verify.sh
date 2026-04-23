#!/usr/bin/env bash
# Single local entry for shift-left verification — no separate "remember to
# run integration smoke" step. Order:
#   1) CI-parity `mix check` (format, compile, dialyzer, ExUnit, kiln scenarios,
#      credo, security, boot checks, kiln.ui.lint, route_smoke_test) via
#      `script/planning_gates.sh`
#   2) `test/integration/first_run.sh` — Docker Compose DB + host Phoenix + /health
#   3) Playwright e2e — all 14 LiveView routes x light/dark x mobile/desktop + axe
#
# Prerequisites:
#   step 2: Docker + Compose v2, jq, curl, lsof, mix (see first_run.sh).
#   step 3: Node 20+, `npm`, plus Playwright browsers on first run.
#
# Skips:
#   SHIFT_LEFT_SKIP_INTEGRATION=1  → run only step 1
#   SHIFT_LEFT_SKIP_E2E=1          → run steps 1+2 (skip Playwright)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$root"

echo "[shift_left_verify] $(date -u +%Y-%m-%dT%H:%M:%SZ) start" >&2

echo "[shift_left_verify] (1/3) planning gates → mix check" >&2
bash script/planning_gates.sh

if [ "${SHIFT_LEFT_SKIP_INTEGRATION:-0}" = "1" ]; then
  echo "[shift_left_verify] SHIFT_LEFT_SKIP_INTEGRATION=1 — skipping integration smoke + e2e" >&2
  echo "[shift_left_verify] OK (planning gates only)" >&2
  exit 0
fi

echo "[shift_left_verify] (2/3) integration smoke → test/integration/first_run.sh" >&2
bash test/integration/first_run.sh

if [ "${SHIFT_LEFT_SKIP_E2E:-0}" = "1" ]; then
  echo "[shift_left_verify] SHIFT_LEFT_SKIP_E2E=1 — skipping Playwright e2e" >&2
  echo "[shift_left_verify] OK (planning gates + integration smoke)" >&2
  exit 0
fi

echo "[shift_left_verify] (3/3) Playwright e2e → mix kiln.e2e" >&2
mix kiln.e2e

echo "[shift_left_verify] OK — mix check + integration smoke + Playwright" >&2
