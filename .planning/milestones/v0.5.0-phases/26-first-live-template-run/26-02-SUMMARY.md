---
phase: 26-first-live-template-run
plan: "02"
subsystem: live-start
tags: [phoenix, liveview, operator-setup, runs, testing]
requires:
  - phase: 25-local-live-readiness-ssot
    provides: ordered readiness checklist, settings remediation SSOT
  - phase: 26-first-live-template-run
    plan: "01"
    provides: hello-kiln first-run templates surface
provides:
  - backend template-start seam with typed readiness blocking
  - deterministic settings redirect to the first missing blocker
  - settings return-context affordance back to the selected template path
affects: [templates-live, settings-live, runs, operator-setup]
tech-stack:
  added: []
  patterns: [backend-authoritative preflight, route-based remediation context, liveview stable-id recovery proof]
key-files:
  created:
    - .planning/phases/26-first-live-template-run/26-02-SUMMARY.md
  modified:
    - lib/kiln/operator_setup.ex
    - lib/kiln/runs.ex
    - lib/kiln_web/live/templates_live.ex
    - lib/kiln_web/live/settings_live.ex
    - test/kiln/runs/run_director_readiness_test.exs
    - test/kiln/specs/template_instantiate_test.exs
    - test/kiln_web/live/templates_live_test.exs
    - test/kiln_web/live/settings_live_test.exs
decisions:
  - "Blocked template starts return a typed readiness outcome that carries both the first blocker and a ready-to-navigate settings target."
  - "TemplatesLive no longer treats queued-run insertion as launch success; success now means the backend gate actually started the run."
  - "Settings owns remediation, but it now preserves a route-based return link to the same template path after the fix."
metrics:
  duration: "active execution completed in one session"
  completed_at: 2026-04-24
---

# Phase 26 Plan 02: First live template run Summary

**`Start run` now goes through a real backend preflight, blocked starts land on the first missing settings anchor, and `/settings` can send the operator back to the same template path afterward**

## Accomplishments

- Added `Runs.start_for_promoted_template/3` so the backend owns the create-and-start path and returns either a started run or a typed readiness block.
- Extended `OperatorSetup` with deterministic first-blocker lookup and settings-target construction using `/settings#settings-item-*` plus route-based return context.
- Updated `TemplatesLive` to consume backend preflight results, navigate blocked starts to `/settings?...#settings-item-*`, and keep calm guidance without reverting to disabled-only ownership.
- Added a return-context affordance in `SettingsLive` so remediation stays on `/settings` while the operator can resume the same template path directly.
- Tightened domain and LiveView tests around blocked recovery, successful start, and the shared `#templates-start-run-form` seam.

## Task Commits

1. Task 1: backend template-start seam
   - `d476e31` — `test(26-02): add live template preflight coverage`
   - `a1036af` — `feat(26-02): add backend template start preflight seam`
2. Task 2: TemplatesLive + settings recovery flow
   - `6bfa113` — `test(26-02): cover blocked template start recovery`
   - `1431e36` — `feat(26-02): route blocked template starts to settings`
3. Task 3: retire disabled-only ownership and tighten proof
   - `204f885` — `test(26-02): tighten live start guidance proof`
   - `5a53d0f` — `feat(26-02): keep live start guidance tied to preflight`
4. Follow-up formatting
   - `20123f9` — `style(26-02): format live template preflight changes`

## Verification

- Passed: `mix test test/kiln/runs/run_director_readiness_test.exs test/kiln/specs/template_instantiate_test.exs`
- Passed: `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/settings_live_test.exs`
- Passed: `mix test test/kiln/runs/run_director_readiness_test.exs test/kiln/specs/template_instantiate_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/settings_live_test.exs`
- Ran: `bash script/precommit.sh`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Caught provider-key blocking so the LiveView does not crash on start**
- **Found during:** Task 2 verification
- **Issue:** The new backend start seam surfaced `Kiln.Blockers.BlockedError` for `:missing_api_key`, which crashed `TemplatesLive` instead of letting the UI handle it as a non-readiness failure.
- **Fix:** `Runs.start_for_promoted_template/3` now rescues the typed blocker and returns `{:error, :missing_api_key}` so the UI can stay up and distinguish readiness blocking from other failures.
- **Files modified:** `lib/kiln/runs.ex`
- **Committed in:** `1431e36`

**2. [Execution note] Task 3’s first proof assertion passed immediately after Task 2**
- **Found during:** Task 3 RED phase
- **Issue:** The Task 2 seam had already removed the disabled-only start contract, so the new guidance-path test was mostly proving existing behavior.
- **Fix:** Added an explicit `#templates-start-run-guidance` seam and matching copy so Task 3 still shipped a concrete operator-facing improvement with its own proof.
- **Files modified:** `lib/kiln_web/live/templates_live.ex`, `test/kiln_web/live/templates_live_test.exs`
- **Committed in:** `204f885`, `5a53d0f`

## Issues Encountered

- `bash script/precommit.sh` still fails outside this plan’s scope on `ex_unit_kiln_scenarios` with 1 existing kiln-scenario failure.
- The same `precommit` run originally reported formatter drift on `lib/kiln/runs.ex` and `lib/kiln_web/live/templates_live.ex`; that was fixed and committed in `20123f9`.

## Known Stubs

None.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/26-first-live-template-run/26-02-SUMMARY.md`.
- Verified task commits exist: `d476e31`, `a1036af`, `6bfa113`, `1431e36`, `204f885`, `5a53d0f`, `20123f9`.
