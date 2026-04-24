---
phase: 33-repeat-run-continuity-on-attached-repos
plan: 01
subsystem: attach
tags: [attach, continuity, ecto, runs, specs]
requires:
  - phase: 32-pr-sized-attached-repo-intake
    provides: attached repo identity, attached request promotion, attached run linkage
provides:
  - repo-centric continuity read model over attached repos, drafts, promoted requests, and runs
  - explicit recent-usage metadata for attached repos
  - same-repo continuity precedence rules for carry-forward selection
affects: [attach-liveview, repeat-run, brownfield-safety]
tech-stack:
  added: []
  patterns: [repo-scoped continuity boundary, explicit usage timestamps]
key-files:
  created:
    - lib/kiln/attach/continuity.ex
    - priv/repo/migrations/20260424161109_add_attached_repo_continuity_metadata.exs
    - test/kiln/attach/continuity_test.exs
  modified:
    - lib/kiln/attach.ex
    - lib/kiln/attach/attached_repo.ex
    - lib/kiln/specs.ex
    - lib/kiln/runs.ex
key-decisions:
  - "Continuity stays anchored on attached_repo_id and same-repo joins instead of browser state or snapshot parsing."
  - "Recent repo ordering uses last_selected_at and last_run_started_at rather than updated_at."
patterns-established:
  - "Expose continuity reads and metadata writes through Kiln.Attach instead of letting LiveView assemble joins."
  - "Choose carry-forward targets with one precedence boundary: explicit draft, open draft, promoted request, linked run, blank."
requirements-completed: [CONT-01]
duration: resumed
completed: 2026-04-24
---

# Phase 33: Plan 01 Summary

**Repo-scoped continuity reads and explicit attached-repo usage timestamps now let Kiln treat one attached repo as durable repeat-work context**

## Performance

- **Duration:** resumed from in-progress working tree
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added `Kiln.Attach.Continuity` plus public `Kiln.Attach` entry points for recent attached repos and one selected repo continuity payload.
- Added `last_selected_at` and `last_run_started_at` to attached repos so recency is explicit and queryable.
- Proved precedence and same-repo scoping with focused continuity tests.

## Task Commits

This resumed execution completed in an already-dirty working tree, so task-level commits were not created during this run.

## Files Created/Modified
- `lib/kiln/attach/continuity.ex` - continuity query boundary and metadata update helpers
- `priv/repo/migrations/20260424161109_add_attached_repo_continuity_metadata.exs` - explicit continuity usage timestamps
- `test/kiln/attach/continuity_test.exs` - precedence, ordering, and same-repo proof
- `lib/kiln/attach.ex` - public continuity entry points

## Decisions Made

- Keep continuity same-repo only through `attached_repo_id` joins.
- Shape continuity data server-side for the UI instead of exposing raw draft/request/run assembly.

## Deviations from Plan

None. The shipped boundary and tests match the plan intent.

## Issues Encountered

- Execution resumed from existing uncommitted Phase 33 work, so this summary documents verified in-place completion rather than fresh task commits.

## User Setup Required

None.

## Next Phase Readiness

Plan 02 can consume one server-owned continuity payload on `/attach` without reimplementing precedence or recency rules.

---
*Phase: 33-repeat-run-continuity-on-attached-repos*
*Completed: 2026-04-24*
