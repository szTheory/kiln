---
phase: 04-agent-tree-shared-memory
plan: "01"
subsystem: database
tags: [postgres, ecto, work-units, immutability]

requires:
  - phase: 03
    provides: runs/stage_runs patterns and audit immutability reference
provides:
  - work_units + work_unit_dependencies tables with grants and CHECKs
  - append-only work_unit_events with D-12-style immutability
  - Ecto schemas under Kiln.WorkUnits.*
affects: [04-02]

tech-stack:
  added: []
  patterns: ["uuidv7 PK + read_after_writes", "append-only ledger + REVOKE + trigger + RULE"]

key-files:
  created:
    - priv/repo/migrations/20260421000001_create_work_units.exs
    - priv/repo/migrations/20260421000002_create_work_unit_events.exs
    - priv/repo/migrations/20260421000003_work_unit_events_immutability.exs
    - lib/kiln/work_units/work_unit.ex
    - lib/kiln/work_units/dependency.ex
    - lib/kiln/work_units/work_unit_event.ex
    - test/kiln/work_units/work_unit_test.exs
    - test/kiln/repo/migrations/work_unit_events_immutability_test.exs
  modified: []

key-decisions:
  - "Ready-queue application semantics use only `:open` and `:blocked` with `blockers_open_count == 0` (partial DB index still matches the broader predicate for future use)."

patterns-established:
  - "Work-unit read model + separate event ledger, mirroring runs vs audit_events."

requirements-completed: [AGENT-04]

duration: 25min
completed: 2026-04-20
---

# Phase 04 Plan 01 Summary

Shipped the durable Postgres floor for work units: mutable `work_units`, structural `work_unit_dependencies`, and append-only `work_unit_events` with the same three-layer immutability posture as `audit_events`.

## Self-Check: PASSED

- `mix test test/kiln/work_units/work_unit_test.exs test/kiln/repo/migrations/work_unit_events_immutability_test.exs`

## Task Commits

1. **Task 1** — `2ae298e` feat(04-01): add work_units and dependency migrations with schemas
2. **Task 2** — `ebb6ab2` feat(04-01): append-only work_unit_events ledger with immutability tests
