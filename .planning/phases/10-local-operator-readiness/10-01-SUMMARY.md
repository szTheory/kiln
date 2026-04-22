---
phase: 10-local-operator-readiness
plan: "01"
subsystem: infra
tags: [docker, compose, readme, operator-dx, integration]

requires:
  - phase: 09-dogfood-release-v0-1-0
    provides: Layered UAT (D-930–D-934), first_run.sh contract, README structure
provides:
  - README operator path + checklist aligned with compose and first_run.sh
  - mix integration.first_run as optional Mix-discoverable delegate to first_run.sh (D-1005)
  - first_run.sh prerequisite check includes mix on PATH; header documents SSOT
  - LOCAL-DX-AUDIT Runbook points at README + names integration commands
affects:
  - Phase 11 external dogfood (operator expects stable clone path)
  - Phase 12 containerized DX (README already defers)

tech-stack:
  added: []
  patterns:
    - "Integration smoke stays in bash; Mix aliases only shell-delegate (no duplicate compose logic)"

key-files:
  created:
    - .planning/phases/10-local-operator-readiness/10-01-SUMMARY.md
  modified:
    - README.md
    - mix.exs
    - test/integration/first_run.sh
    - .planning/research/LOCAL-DX-AUDIT.md

key-decisions:
  - "Added mix integration.first_run as optional discoverability; implementation is System.cmd to bash script only (D-1005b)."
  - "Jaeger manual UAT: follow README Traces (local); trivial action = load /health or /onboarding after OTEL_EXPORTER_OTLP_ENDPOINT set — confirm span in Jaeger UI (not run in this automated execution)."

patterns-established:
  - "Operator checklist + README quick start remain canonical; audit file is rationale + runbook pointer (D-1001)."

requirements-completed:
  - LOCAL-01
  - LOCAL-03
  - BLOCK-04

duration: 25min
completed: 2026-04-21
---

# Phase 10: Local operator readiness — Plan 01 summary

**Host Phoenix + Compose data plane path is documented with a scannable checklist, DTU timing, and a Mix-discoverable integration smoke that still shells to `first_run.sh` only.**

## Performance

- **Duration:** ~25 min (estimated)
- **Started:** 2026-04-21
- **Completed:** 2026-04-21
- **Tasks:** 5
- **Files modified:** 4 (+ this summary)

## Accomplishments

- Closed README ↔ `first_run.sh` gaps: fixed header typo, documented SSOT + optional Mix alias in script comments, added explicit `mix` to prerequisite checks.
- Added `mix integration.first_run` — one `System.cmd` to `bash test/integration/first_run.sh` (no duplicated Docker/migrate orchestration).
- README **Integration smoke** and **Operator checklist** reference both entry points; **LOCAL-DX-AUDIT** Runbook cites the same commands.
- **10-CONTEXT.md** already contained G1–G6 (D-1001–D-1006); no structural edits required.

## Task commits

Commits follow task boundaries in git history (search `10-01` or `integration.first_run`).

## Files created/modified

- `test/integration/first_run.sh` — README parity, `mix` on PATH check, D-1005 comment.
- `mix.exs` — `integration.first_run` alias.
- `README.md` — SSOT wording, Mix alias block, checklist bullet.
- `.planning/research/LOCAL-DX-AUDIT.md` — Runbook integration-command line.

## Decisions made

- Optional Jaeger path (D-1003): README **Traces (local)** remains the contract; this session did not start Jaeger in automation — operators validate once using `docker compose up -d otel-collector jaeger`, `export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317`, `mix phx.server`, then **GET `/health`** or open **`/onboarding`** and confirm a trace at `http://localhost:16686`.

## Deviations from plan

None — plan scope was largely already landed in README/audit; this execution tightened parity and added the D-1005 Mix delegate.

## Issues encountered

- `gsd-sdk query state.begin-phase --phase …` returned misparsed JSON; **`node $GSD_HOME/bin/gsd-tools.cjs state begin-phase --phase 10 --name local-operator-readiness --plans 1`** updated STATE successfully. Tooling quirk only.

## User setup required

None beyond existing README prerequisites (Docker, keys in `.env`).

## Next phase readiness

- Operator cold path and machine smoke SSOT are explicit; Phase 11 can assume README + `first_run.sh` + optional `mix integration.first_run`.

## Self-check: PASSED

- `mix compile --warnings-as-errors` succeeds after `mix.exs` change.

---
*Phase: 10-local-operator-readiness*
*Completed: 2026-04-21*
