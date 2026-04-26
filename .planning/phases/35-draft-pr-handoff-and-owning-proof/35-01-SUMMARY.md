---
phase: 35-draft-pr-handoff-and-owning-proof
plan: 01
subsystem: attach
tags: [attach, delivery, draft-pr, trust]
requires:
  - phase: 34-brownfield-preflight-and-narrowing-guardrails
    provides: attach safety and narrowing boundaries
provides:
  - reviewer-facing draft PR summary and acceptance sections from durable request fields
  - conditional out-of-scope rendering with compact branch/base and kiln-run context
  - verification section anchored to the owning proof command
affects: [attach-delivery, draft-pr-handoff, trust-copy]
tech-stack:
  added: []
  patterns: [durable spec_revision framing for PR body, compact reviewer-first sections]
key-files:
  created: []
  modified:
    - lib/kiln/attach/delivery.ex
    - test/kiln/attach/delivery_test.exs
    - test/integration/github_delivery_test.exs
key-decisions:
  - "Attach delivery now preloads run.spec_revision and derives reviewer copy from durable request fields."
  - "Visible PR body omits raw internal identifiers while preserving branch/base facts plus one kiln-run marker."
patterns-established:
  - "Draft PR body sections are Summary -> Acceptance criteria -> optional Out of scope -> Verification -> Branch context."
  - "Snapshot replay keeps the exact frozen body/title once promoted to github_delivery_snapshot."
requirements-completed: [TRUST-04]
duration: resumed
completed: 2026-04-24
---

# Phase 35: Plan 01 Summary

**Attached draft PR handoff now reads like a bounded feature/bugfix PR built from durable request fields instead of generic attach placeholder copy**

## Performance

- **Duration:** resumed from in-progress working tree
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Reworked `Kiln.Attach.Delivery` to build title/body from `run.spec_revision` request fields.
- Added compact reviewer-facing sections with conditional `Out of scope` behavior and one `kiln-run:` footer.
- Locked the new body contract via delivery seam and integration coverage.

## Task Commits

This resumed execution completed in an already-dirty working tree, so task-level commits were not created during this run.

## Files Created/Modified
- `lib/kiln/attach/delivery.ex` - frozen draft PR title/body assembly from durable request fields
- `test/kiln/attach/delivery_test.exs` - section-level assertions and omission checks
- `test/integration/github_delivery_test.exs` - frozen snapshot contract assertions for persisted PR body/title

## Decisions Made

- Keep body framing compact and reviewer-first while preserving replay-safe freezing.
- Treat `run.spec_revision` as the source of truth for `Summary`, `Acceptance criteria`, and optional `Out of scope`.

## Deviations from Plan

None. Plan objectives and validation checks landed as specified.

## Issues Encountered

- Execution resumed against pre-existing local edits; verification relied on targeted phase tests instead of per-task fresh commits.

## User Setup Required

None.

## Next Phase Readiness

Plan 02 can now make proof-layer citations literal by syncing `mix kiln.attach.prove` delegated files with the same reviewer-visible verification copy.

---
*Phase: 35-draft-pr-handoff-and-owning-proof*
*Completed: 2026-04-24*
