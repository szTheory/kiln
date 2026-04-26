---
phase: 29-attach-entry-surfaces
plan: "01"
subsystem: ui
tags: [phoenix, liveview, onboarding, templates, attach, routing, tdd]
requires:
  - phase: 26-first-live-template-run
    provides: hello-kiln-first-run template contract and `/templates` hero semantics
  - phase: 27-local-first-run-proof
    provides: proof-first template journey boundaries that attach must not displace
provides:
  - Dedicated `/attach` LiveView under the default operator shell
  - Additive attach CTAs on `/onboarding` and `/templates`
  - Regression coverage for attach routing and first-use discoverability
affects: [onboarding, templates, route-smoke, attach-entry, ATTACH-01]
tech-stack:
  added: []
  patterns: [route-backed LiveView branching, attach-specific ids, additive TDD for entry surfaces]
key-files:
  created:
    - lib/kiln_web/live/attach_entry_live.ex
    - test/kiln_web/live/attach_entry_live_test.exs
  modified:
    - lib/kiln_web/router.ex
    - lib/kiln_web/live/onboarding_live.ex
    - lib/kiln_web/live/templates_live.ex
    - test/kiln_web/live/onboarding_live_test.exs
    - test/kiln_web/live/templates_live_test.exs
    - test/kiln_web/live/route_smoke_test.exs
key-decisions:
  - "Attach stays on its own `/attach` route and never reuses scenario or template resume state."
  - "The `hello-kiln` hero remains the single recommended first proof path while attach is surfaced as the real-project branch."
patterns-established:
  - "Entry-surface branching uses route-backed LiveView navigation with surface-specific ids."
  - "Attach copy stays honest about Phase 30 ownership for validation and workspace safety."
requirements-completed: [ATTACH-01]
duration: 5min
completed: 2026-04-24
---

# Phase 29 Plan 01: Attach Entry Surfaces Summary

**Dedicated `/attach` orientation LiveView with additive onboarding/templates attach branches that preserve the `hello-kiln` proof-first path**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-24T09:24:49Z
- **Completed:** 2026-04-24T09:29:40Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added `/attach` as a dedicated operator-shell LiveView with supported-source framing, explicit Phase 30 boundary copy, and back-links to templates/setup.
- Added `Attach existing repo` as a secondary branch on `/onboarding` and a first-class peer module on `/templates` without touching template apply/start plumbing.
- Locked the structural slice with focused LiveView tests plus route-smoke coverage for `/attach`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the dedicated `/attach` route and orientation-only LiveView** - `479c0e0` (`test`), `5d76fa2` (`feat`)
2. **Task 2: Add attach-vs-template branching to onboarding and templates without disturbing the proof-first template path** - `6473379` (`test`), `989e367` (`feat`)

## Files Created/Modified

- `lib/kiln_web/live/attach_entry_live.ex` - New route-backed attach orientation surface with attach-specific ids and honest Phase 29 framing.
- `lib/kiln_web/router.ex` - Registers `live "/attach", AttachEntryLive, :index` in the default LiveView session.
- `lib/kiln_web/live/onboarding_live.ex` - Adds the secondary onboarding attach CTA and attach path note beside the existing template CTA cluster.
- `lib/kiln_web/live/templates_live.ex` - Adds the start-choice panel and attach peer module above the catalog while keeping the `hello-kiln` hero primary.
- `test/kiln_web/live/attach_entry_live_test.exs` - Covers `/attach` mount, stable ids, and scope-copy boundaries.
- `test/kiln_web/live/onboarding_live_test.exs` - Verifies onboarding exposes the attach branch without treating it as scenario state.
- `test/kiln_web/live/templates_live_test.exs` - Verifies templates exposes the attach module while preserving the `hello-kiln` recommendation.
- `test/kiln_web/live/route_smoke_test.exs` - Extends the route matrix to include `/attach`.

## Decisions Made

- Attach routing is explicit and separate from the template/scenario system, matching the phase boundary and threat mitigations around spoofed entry semantics.
- The templates page remains the primary start surface; attach is peer-level discovery, not a replacement for the recommended first proof.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the documented precommit shell fallback because `just` was unavailable**
- **Found during:** Final verification
- **Issue:** `just precommit` could not run because `just` is not installed in this execution environment.
- **Fix:** Ran `bash script/precommit.sh`, which the repo documents as the equivalent fallback.
- **Files modified:** None
- **Verification:** `script/precommit.sh` completed successfully, including compiler, formatter, audit, sobelow, dialyzer, tests, and boot-check gates.
- **Committed in:** None (execution-only deviation)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep. The fallback was repo-documented and preserved the intended verification coverage.

## Issues Encountered

- `just` was not present locally; the fallback script resolved the verification gate without code changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `/attach`, `/onboarding`, and `/templates` now expose the attach-vs-template information architecture required for `ATTACH-01`.
- Later phases can add repo validation, hydration, and safety checks behind `/attach` without unwinding any template-specific state or ids.

## Self-Check: PASSED

---
*Phase: 29-attach-entry-surfaces*
*Completed: 2026-04-24*
