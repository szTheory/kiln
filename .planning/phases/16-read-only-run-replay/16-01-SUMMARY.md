---
phase: 16-read-only-run-replay
plan: "01"
subsystem: ui
tags: [liveview, phoenix, audit, routing]

requires: []
provides:
  - GET /runs/:run_id/replay route ordered before /runs/:run_id
  - RunReplayLive shell with UUID gate matching RunDetailLive
affects: []

tech-stack:
  added: []
  patterns: [read-only LiveView spine; stream for audit rows]

key-files:
  created:
    - lib/kiln_web/live/run_replay_live.ex
  modified:
    - lib/kiln_web/router.ex

key-decisions:
  - "Invalid path UUID uses same flash + redirect as RunDetailLive"
  - "Initial spine uses Audit.replay/1 limit 500 (superseded by replay_page in 16-03)"

patterns-established:
  - "Run-scoped replay route registered as literal segment before dynamic run id"

requirements-completed: [REPL-01]

duration: 25min
completed: 2026-04-22
---

# Phase 16 Plan 01 Summary

**Operators can open a dedicated read-only replay route with the first audit spine window and stable shell ids.**

## Self-Check: PASSED

- `mix compile --warnings-as-errors`
- Route ordering verified via grep acceptance in plan

## Deviations

- Plan 16-03 replaced the initial `Audit.replay/1` spine with `replay_page/1`; plan 01 acceptance for the first slice is preserved in git history.
