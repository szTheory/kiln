---
phase: 34-brownfield-preflight-and-narrowing-guardrails
plan: 02
subsystem: attach
tags: [attach, brownfield, github-cli, runs, specs]
requires:
  - phase: 34-brownfield-preflight-and-narrowing-guardrails
    provides: typed advisory report boundary and launchability helpers
provides:
  - same-repo overlap and breadth heuristics for attached requests
  - open-PR lane lookup and degraded lookup warning path
  - attach-side pre-start integration that preserves Runs as deterministic start authority
affects: [attach-liveview, runs, brownfield-safety]
tech-stack:
  added: []
  patterns: [bounded same-repo candidate reads, degraded external-check warning path]
key-files:
  created: []
  modified:
    - lib/kiln/attach/brownfield_preflight.ex
    - lib/kiln_web/live/attach_entry_live.ex
    - test/kiln/attach/brownfield_preflight_test.exs
key-decisions:
  - "Use same-repo drafts, promoted requests, runs, and open PRs as the only advisory candidate pool."
  - "Treat unavailable PR lookup as a warning, not a hidden skip or new hard block."
patterns-established:
  - "Evaluate brownfield advisory findings before launch, then defer final start authority to Runs."
  - "Prefer deterministic same-lane conflicts for fatals and lexical overlap for warnings."
requirements-completed: [SAFE-01, SAFE-02]
duration: resumed
completed: 2026-04-24
---

# Phase 34: Plan 02 Summary

**Same-repo overlap, open-PR, and breadth heuristics now shape attached-request preflight without teaching Runs any fuzzy new refusal states**

## Performance

- **Duration:** resumed from in-progress working tree
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added same-repo overlap, same-lane ambiguity, breadth, and degraded PR lookup findings to brownfield preflight.
- Wired advisory evaluation into the attach request submit path before deterministic start checks.
- Preserved `Runs.start_for_attached_request/3` as the final deterministic launch authority.

## Task Commits

This resumed execution completed in an already-dirty working tree, so task-level commits were not created during this run.

## Files Created/Modified
- `lib/kiln/attach/brownfield_preflight.ex` - same-repo candidate scoring and PR lookup handling
- `lib/kiln_web/live/attach_entry_live.ex` - advisory pre-start integration
- `test/kiln/attach/brownfield_preflight_test.exs` - overlap, fatal, and degraded lookup coverage

## Decisions Made

- Use bounded same-repo reads instead of cross-repo or semantic analysis.
- Keep degraded live PR lookup visible through a typed warning so launchability remains explicit.

## Deviations from Plan

None. The advisory layer stayed bounded and explainable.

## Issues Encountered

- The repository already contained overlapping uncommitted continuity changes, so execution stayed inline rather than dispatching isolated worktrees from an older commit base.

## User Setup Required

None.

## Next Phase Readiness

Plan 03 can render warning and narrowing UX directly from the advisory report without recomputing heuristics in the browser.

---
*Phase: 34-brownfield-preflight-and-narrowing-guardrails*
*Completed: 2026-04-24*
