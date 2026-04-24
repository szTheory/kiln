---
phase: 29-attach-entry-surfaces
plan: "02"
subsystem: ui
tags: [phoenix, liveview, onboarding, templates, attach, playwright, verification]
requires:
  - phase: 29-attach-entry-surfaces
    plan: "01"
    provides: route-backed attach surface and additive entry-point branch structure
provides:
  - Coherent templates-vs-attach copy across `/onboarding`, `/templates`, and `/attach`
  - Browser proof that onboarding hands off explicitly to `/attach`
  - Route-matrix coverage for `/attach` plus preserved template-first journey proof
affects: [onboarding, templates, attach-entry, e2e, ATTACH-01]
tech-stack:
  added: []
  patterns: [copy-contract alignment, route-backed attach handoff, browser route matrix verification]
key-files:
  created: []
  modified:
    - lib/kiln_web/live/attach_entry_live.ex
    - lib/kiln_web/live/onboarding_live.ex
    - lib/kiln_web/live/templates_live.ex
    - test/e2e/tests/onboarding.spec.ts
    - test/e2e/tests/routes.spec.ts
key-decisions:
  - "Attach copy now repeats the same contract on every first-use surface: templates are the fastest proof path, attach is the bounded real-project branch."
  - "Browser proof for attach is route truth and handoff choreography only; attach does not inherit onboarding scenario query state."
patterns-established:
  - "Onboarding attach CTAs prove direct `/attach` navigation by href and URL, not by carrying demo-scenario params into attach."
  - "Phase 29 verification for Playwright must run from `test/e2e` with a live Phoenix server held open during the suite."
requirements-completed: [ATTACH-01]
duration: 9min
completed: 2026-04-24
---

# Phase 29 Plan 02: Attach Entry Surfaces Summary

**Operator-facing attach-vs-template copy aligned across the first-use surfaces, with browser proof that `/attach` is real without weakening the `hello-kiln` first-run path**

## Performance

- **Duration:** 9 min
- **Completed:** 2026-04-24T09:39:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Tightened `/onboarding`, `/templates`, and `/attach` so they all tell the same Phase 29 story: built-in templates remain the fastest way to learn Kiln or prove the first run, while `Attach existing repo` is the bounded one-repo branch for code the operator already owns.
- Kept `hello-kiln` as the top recommendation while making source-type scope explicit across attach-facing copy: local path, existing clone, and GitHub URL, with validation and workspace safety clearly deferred to the next phase.
- Extended Playwright proof so onboarding explicitly hands off to `/attach`, the route matrix includes `/attach`, and the existing template-first journey assertions remain intact.

## Task Commits

1. **Task 1: Harmonize attach-vs-template copy across the first-use surfaces** - `f5eac88` (`feat`)
2. **Task 2: Extend browser-level proof coverage for the attach branch and preserved template journey** - `221bbb9` (`test`)

## Files Created/Modified

- `lib/kiln_web/live/attach_entry_live.ex` - Reframed the attach route as the bounded real-project branch while explicitly contrasting it with built-in templates and repeating the next-phase validation boundary.
- `lib/kiln_web/live/onboarding_live.ex` - Tightened the onboarding recommendation card so attach is clearly secondary to the template-first proof path but still explicit about supported source types and next-step safety checks.
- `lib/kiln_web/live/templates_live.ex` - Brought the peer attach module into exact alignment with the attach route and preserved `hello-kiln` as the recommended first proof.
- `test/e2e/tests/onboarding.spec.ts` - Added browser proof that the onboarding attach CTA is visible, points directly to `/attach`, and does not leak scenario query state into the attach route.
- `test/e2e/tests/routes.spec.ts` - Added `/attach` to the LiveView route matrix and updated the route count documentation.

## Verification

- `mix test test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/attach_entry_live_test.exs` — passed
- `npx playwright test tests/onboarding.spec.ts tests/routes.spec.ts` (run from `test/e2e` with Phoenix held open in a TTY session) — passed
- `rg -n "Attach existing repo|Built-in templates|local path|existing clone|GitHub URL|validation" lib/kiln_web/live/attach_entry_live.ex lib/kiln_web/live/onboarding_live.ex lib/kiln_web/live/templates_live.ex test/e2e/tests/onboarding.spec.ts test/e2e/tests/routes.spec.ts` — passed
- `bash script/precommit.sh` — passed

## Decisions Made

- Phase 29 browser proof should assert direct attach-route choreography and explicit CTA truth, not a scenario-state carryover contract that the attach route does not own.
- Copy alignment stays additive to the Wave 1 structure: no `/` shortcut, no settings reframing, and no Phase 30/31 attach mechanics pulled forward.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Ran Playwright from the repo’s `test/e2e` package instead of the repo root**
- **Found during:** Task 2 verification
- **Issue:** The plan’s root-level `npx playwright test ...` invocation loaded the wrong Playwright context in this repo layout because the Playwright package and config live under `test/e2e`.
- **Fix:** Re-ran the exact spec pair from `test/e2e` using `npx playwright test tests/onboarding.spec.ts tests/routes.spec.ts`.
- **Files modified:** None
- **Verification:** The adjusted command passed after the server was held open.
- **Committed in:** None (execution-only deviation)

**2. [Rule 3 - Blocking] Held Phoenix open in a TTY session for browser verification**
- **Found during:** Task 2 verification
- **Issue:** `script/e2e_boot.sh` successfully seeded and booted Phoenix, but the spawned server did not remain reachable after the shell command returned in this execution environment.
- **Fix:** Started `mix phx.server` in a persistent TTY session, reran the Playwright suite against that live process, then continued with the remaining verification gates.
- **Files modified:** None
- **Verification:** The two-spec Playwright suite passed in all four browser projects.
- **Committed in:** None (execution-only deviation)

## Known Stubs

None.

## Self-Check: PASSED

