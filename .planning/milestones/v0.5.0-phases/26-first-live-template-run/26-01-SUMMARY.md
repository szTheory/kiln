---
phase: 26-first-live-template-run
plan: "01"
subsystem: ui
tags: [phoenix, liveview, templates, onboarding, testing]
requires:
  - phase: 17-template-library-onboarding-specs
    provides: templates catalog routes, template detail flow, and use/start seams
  - phase: 24-template-run-uat-smoke
    provides: liveview regression seam for /templates -> /runs/:id
provides:
  - single hello-kiln first-run hero on /templates
  - secondary scenario framing with honest non-hero role labels
  - stable-id route proof for the templates index and hello-kiln detail
affects: [phase-26-plan-02, phase-26-plan-03, templates-live, route-smoke]
tech-stack:
  added: []
  patterns: [single-recommendation hero, secondary scenario guidance, stable-id liveview route proof]
key-files:
  created: [.planning/phases/26-first-live-template-run/26-01-SUMMARY.md]
  modified: [lib/kiln_web/live/templates_live.ex, test/kiln_web/live/templates_live_test.exs, test/kiln_web/live/route_smoke_test.exs]
key-decisions:
  - "Keep hello-kiln in the hero only and leave the lower catalog for honest next-step templates."
  - "Replace recommendation badges with explicit role labels so gameboy and markdown paths stay visible without reading as equal first-run defaults."
  - "Use route-smoke assertions on stable ids instead of old scenario-copy wording."
patterns-established:
  - "Templates recommendation pattern: one primary first-run hero plus a visible browseable catalog below."
  - "Scenario pattern: explain what comes after the first run rather than controlling the starter recommendation."
requirements-completed: [LIVE-01, LIVE-03]
duration: 6min
completed: 2026-04-24
---

# Phase 26 Plan 01: First live template run Summary

**`/templates` now presents `hello-kiln` as the single first live run, with secondary scenario guidance and honest role labels for the other built-ins**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-24T01:35:50Z
- **Completed:** 2026-04-24T01:40:22Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Reframed `/templates` around a dedicated `hello-kiln` first-run hero that teaches readiness -> use template -> start run -> inspect proof on `/runs/:id`.
- Demoted scenario framing to “after the first run” guidance and replaced rank-like badges with honest role labels for the non-hero templates.
- Extended the route smoke to assert the new stable hero surface and preserve the hello-kiln detail seam.

## Task Commits

Each task was committed atomically:

1. **Task 1: Reframe `/templates` around a single `hello-kiln` first-run hero** - `f0fc320` (test), `670cbd7` (feat), `3cdb984` (style)
2. **Task 2: Update template-surface proof for the new recommendation contract** - `f85371b` (test)

## Files Created/Modified

- `lib/kiln_web/live/templates_live.ex` - Adds the single first-run hero, secondary scenario framing, honest role labels, and detail-page copy updates.
- `test/kiln_web/live/templates_live_test.exs` - Proves the hero and secondary-scenario contract by stable ids.
- `test/kiln_web/live/route_smoke_test.exs` - Adds broad render checks for the new templates hero and preserved hello-kiln detail surface.

## Decisions Made

- Kept `hello-kiln` out of the lower catalog so the page has one unambiguous starter without hiding the rest of the template library.
- Used role labels like `Dogfood depth` and `Edit first path` instead of badge-driven ranking signals.
- Shifted detail-page guidance toward run detail as the first proof surface, with the run board framed as the broader follow-up view.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed duplicate role-label DOM ids introduced by the hero/catalog split**
- **Found during:** Task 1 (Reframe `/templates` around a single `hello-kiln` first-run hero)
- **Issue:** The first implementation reused `template-role-*` ids in both the hero sidebar and lower catalog, which breaks LiveView DOM targeting.
- **Fix:** Kept stable ids only on the lower catalog cards and rendered the hero sidebar labels without duplicate ids.
- **Files modified:** `lib/kiln_web/live/templates_live.ex`
- **Verification:** `mix test test/kiln_web/live/templates_live_test.exs`
- **Committed in:** `670cbd7`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary correctness fix. No scope creep.

## Issues Encountered

- `bash script/precommit.sh` failed outside this plan’s scope on existing test-suite issues:
  - generated scenario compile error in `test/generated/kiln_scenarios/019dbc56-f4bf-7463-94c2-c136b61df85d/scenarios_test.exs` (`{:error, :enoent}`)
  - `Kiln.BootChecksTest` deadlock failure in `test/kiln/boot_checks_test.exs`
- These failures were not introduced by the templates changes. Focused verification for this plan passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 26 Plan 02 can build the backend-authoritative start/preflight path on top of a stable single-template recommendation surface.
- The templates UI now has stable ids for hero and role-label assertions that later phases can reuse.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/26-first-live-template-run/26-01-SUMMARY.md`.
- Verified task commits exist: `f0fc320`, `670cbd7`, `3cdb984`, `f85371b`.

---
*Phase: 26-first-live-template-run*
*Completed: 2026-04-24*
