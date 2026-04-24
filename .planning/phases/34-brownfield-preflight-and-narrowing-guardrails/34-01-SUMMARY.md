---
phase: 34-brownfield-preflight-and-narrowing-guardrails
plan: 01
subsystem: attach
tags: [attach, brownfield, preflight, safety, testing]
requires:
  - phase: 33-repeat-run-continuity-on-attached-repos
    provides: same-repo continuity facts and attached repo identity reuse
provides:
  - typed brownfield advisory report boundary under Kiln.Attach
  - fatal, warning, and info finding helpers with launchability policy
  - attach seam for advisory preflight evaluation
affects: [attach-liveview, attached-request-start, brownfield-safety]
tech-stack:
  added: []
  patterns: [hard-gate then advisory-report layering, typed finding contract]
key-files:
  created:
    - lib/kiln/attach/brownfield_preflight.ex
    - test/kiln/attach/brownfield_preflight_test.exs
  modified:
    - lib/kiln/attach.ex
    - lib/kiln/specs.ex
key-decisions:
  - "Keep SafetyGate deterministic and place fuzzy brownfield logic in a sibling advisory module."
  - "Use typed fatal/warning/info findings with explicit evidence instead of a score blob."
patterns-established:
  - "Expose advisory brownfield evaluation through Kiln.Attach so LiveView stays server-authoritative."
  - "Treat warning-only findings as launchable by policy; only fatal findings block."
requirements-completed: [SAFE-01, SAFE-02]
duration: resumed
completed: 2026-04-24
---

# Phase 34: Plan 01 Summary

**Attach-side brownfield preflight now returns a typed advisory report with explicit severity, evidence, and launchability helpers**

## Performance

- **Duration:** resumed from in-progress working tree
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added `Kiln.Attach.BrownfieldPreflight` as the attach-owned advisory boundary separate from `SafetyGate`.
- Introduced typed finding and report helpers so warnings stay advisory while fatal findings block.
- Added focused domain tests that lock the report contract, degradation behavior, and narrowing policy.

## Task Commits

This resumed execution completed in an already-dirty working tree, so task-level commits were not created during this run.

## Files Created/Modified
- `lib/kiln/attach/brownfield_preflight.ex` - typed report model, finding helpers, and advisory evaluation
- `lib/kiln/attach.ex` - public `evaluate_brownfield_preflight/3` seam
- `lib/kiln/specs.ex` - bounded same-repo draft and promoted-request query helpers
- `test/kiln/attach/brownfield_preflight_test.exs` - advisory contract coverage

## Decisions Made

- Keep the report as explicit maps and helpers instead of introducing another persistence layer or cache.
- Let the attach boundary own advisory evaluation so later UI work can consume one server-side report.

## Deviations from Plan

None. The shipped boundary follows the planned hard-gate versus advisory split.

## Issues Encountered

- Execution resumed on top of existing uncommitted Phase 33 continuity work, so implementation proceeded inline on the main worktree instead of isolated worktrees.

## User Setup Required

None.

## Next Phase Readiness

Plan 02 can add same-repo heuristics and open-PR checks on top of the typed report contract without changing the boundary shape.

---
*Phase: 34-brownfield-preflight-and-narrowing-guardrails*
*Completed: 2026-04-24*
