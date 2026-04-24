---
phase: 25-local-live-readiness-ssot
plan: "01"
subsystem: testing
tags: [phoenix, liveview, operator-readiness, ecto]
requires:
  - phase: 24-template-run-uat-smoke
    provides: readiness-aware LiveView proof style and narrow verification language
provides:
  - pessimistic-by-default operator readiness state
  - singleton upsert behavior for readiness probes
  - `/settings` proof for missing-readiness remediation controls
affects: [settings, run gating, operator setup]
tech-stack:
  added: []
  patterns: [pessimistic readiness defaults, singleton insert-or-update probe persistence]
key-files:
  created: []
  modified:
    - lib/kiln/operator_readiness.ex
    - test/kiln/operator_readiness_test.exs
    - test/kiln/runs/run_director_readiness_test.exs
    - test/kiln_web/live/settings_live_test.exs
    - priv/repo/migrations/20260423215049_backfill_operator_readiness_false_defaults.exs
key-decisions:
  - "Fresh or reset readiness state must be unreadied until probes are explicitly verified."
  - "Singleton readiness writes use insert_or_update so `/settings` can recover from a missing row."
patterns-established:
  - "Readiness tests should delete the singleton row when proving fresh-machine behavior."
requirements-completed: [SETUP-01, SETUP-02]
duration: 20min
completed: 2026-04-23
---

# Phase 25 Plan 01 Summary

**Operator readiness now defaults to not-ready on a fresh machine, persists safely via singleton upsert behavior, and has focused test coverage for `/settings` missing-state remediation.**

## Performance

- **Duration:** 20 min
- **Completed:** 2026-04-23
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Removed the optimistic missing-row fallback from `Kiln.OperatorReadiness`.
- Added a forward migration so a fresh database no longer seeds operator readiness as fully ready.
- Proved the false-ready regression and `/settings` missing-state path with narrow tests.

## Task Commits

No commit was created in this run because the phase was executed in an already-dirty working tree.

## Deviations from Plan

Added a follow-up migration to correct the stored database default, because runtime-only changes would not fix fresh databases created from the existing schema.
