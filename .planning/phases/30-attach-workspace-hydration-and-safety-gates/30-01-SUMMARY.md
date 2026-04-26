---
phase: 30-attach-workspace-hydration-and-safety-gates
plan: "01"
subsystem: ui
tags: [attach, liveview, github, git, validation]
requires:
  - phase: 29-attach-entry-surfaces
    provides: "/attach route, attach entry copy, and stable page ids for the brownfield entry path"
provides:
  - "Canonical attach source contract for local paths and GitHub URLs"
  - "Attach boundary used by LiveView instead of ad hoc source parsing"
  - "Real /attach intake form with untouched, resolved, and typed error states"
affects: [attach, workspace hydration, trust gates, liveview]
tech-stack:
  added: []
  patterns: ["Thin LiveView -> domain boundary delegation", "Canonical resolved-source contract before workspace hydration"]
key-files:
  created: [lib/kiln/attach.ex, lib/kiln/attach/source.ex, test/kiln/attach/source_test.exs]
  modified: [lib/kiln_web/live/attach_entry_live.ex, test/kiln_web/live/attach_entry_live_test.exs]
key-decisions:
  - "Represent resolved attach input as one struct with stable fields for kind, repo identity, canonical root, and remote metadata placeholders."
  - "Treat existing clones as the normal local-path success path instead of creating a separate branch of attach logic."
patterns-established:
  - "Attach parsing belongs in Kiln.Attach/Kiln.Attach.Source, not in LiveView event handlers."
  - "Typed remediation feedback should flow from the domain boundary to the /attach UI without starting workspace mutation."
requirements-completed: [ATTACH-02]
duration: 7min
completed: 2026-04-24
---

# Phase 30 Plan 01: Attach Source Intake Summary

**Canonical attach-source resolution for local repos and GitHub URLs, wired into a real `/attach` intake flow with typed validation feedback**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-24T11:52:35Z
- **Completed:** 2026-04-24T11:59:43Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added `Kiln.Attach` and `Kiln.Attach.Source` so local paths, existing clones, and GitHub URLs resolve into one reusable contract.
- Replaced the static `/attach` page with a form-driven LiveView that renders untouched, resolved, and typed remediation states.
- Locked the new boundary and UI behavior with focused unit and LiveView tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a typed attach source resolver boundary for local paths and GitHub URLs** - `4f2c037` (test), `9174c7a` (feat)
2. **Task 2: Turn `/attach` into a real source submission surface with typed validation feedback** - `6618091` (test), `de8bf82` (feat)

**Plan metadata:** recorded in the final docs commit for this plan

_Note: TDD tasks used RED -> GREEN commits._

## Files Created/Modified
- `lib/kiln/attach.ex` - Public attach boundary used by the LiveView and later workspace plans.
- `lib/kiln/attach/source.ex` - Canonical source resolver for local repo roots and GitHub URLs.
- `lib/kiln_web/live/attach_entry_live.ex` - Real `/attach` intake surface with typed state rendering.
- `test/kiln/attach/source_test.exs` - Domain coverage for local paths, existing clones, GitHub URLs, and typed failures.
- `test/kiln_web/live/attach_entry_live_test.exs` - LiveView coverage for untouched guidance, success, and typed validation feedback.

## Decisions Made

- Used a dedicated `%Kiln.Attach.Source{}` struct so later plans can reuse resolved repo identity without reparsing operator input.
- Left `remote_metadata` fields as explicit placeholders (`default_branch`, `head_sha`) so workspace hydration can enrich the contract later without changing the shape.
- Kept `/attach` honest about scope: source resolution now works, but hydration, dirty-worktree refusal, branch creation, and PR orchestration remain deferred.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized unit tests around canonical repo roots on macOS**
- **Found during:** Task 1 (typed attach source resolver boundary)
- **Issue:** Git returns a canonical repo root that resolves `/var` temp paths to `/private/var`, so the initial assertions were too path-literal for this host.
- **Fix:** Updated the tests to assert against canonicalized repo roots and derived repo names instead of temp-path literals.
- **Files modified:** `test/kiln/attach/source_test.exs`
- **Verification:** `mix test test/kiln/attach/source_test.exs`
- **Committed in:** `9174c7a`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix kept the resolver contract portable without widening scope.

## Issues Encountered

- `bash script/precommit.sh` surfaced one existing repo-level failure outside this plan: `check_no_signature_block` flags `priv/workflows/_test_bogus_signature.yaml`. This file was not touched by 30-01, so it remains out of scope for this execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `Kiln.Attach.resolve_source/2` now returns one typed source contract that later attach plans can consume directly.
- `/attach` already captures operator input and renders validation output, so the next plan can focus on writable workspace preparation and safety gates.
- Remaining repo-wide `precommit` noise is unrelated to this plan’s files.

## Self-Check: PASSED

- Found summary file: `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-01-SUMMARY.md`
- Found task commits: `4f2c037`, `9174c7a`, `6618091`, `de8bf82`

---
*Phase: 30-attach-workspace-hydration-and-safety-gates*
*Completed: 2026-04-24*
