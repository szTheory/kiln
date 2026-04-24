---
phase: 27-local-first-run-proof
plan: "01"
status: superseded
superseded_by: 28-first-run-proof-runtime-closure
subsystem: testing
tags: [mix, phoenix-liveview, verification, local-first, uat]
requires:
  - phase: 25-local-live-readiness-ssot
    provides: /settings readiness ssot and return-context surface
  - phase: 26-first-live-template-run
    provides: hello-kiln first-run path and /runs/:id proof surface
provides:
  - Dedicated `mix kiln.first_run.prove` wrapper task
  - Delegation-order lock for the two proof layers
  - Setup-ready `/settings` to `hello-kiln` to run-detail proof seam
  - Exact Phase 27 verification command artifact
affects: [phase-27-verification, local-first-proof, operator-journey]
tech-stack:
  added: []
  patterns: [thin mix wrappers, focused liveview proof seams, exact command verification docs]
key-files:
  created:
    - lib/mix/tasks/kiln.first_run.prove.ex
    - test/mix/tasks/kiln.first_run.prove_test.exs
    - .planning/phases/27-local-first-run-proof/27-VERIFICATION.md
    - .planning/phases/27-local-first-run-proof/27-01-SUMMARY.md
  modified:
    - test/kiln_web/live/templates_live_test.exs
key-decisions:
  - "Kept `mix kiln.first_run.prove` as a thin wrapper that delegates only `integration.first_run` and the focused LiveView files."
  - "Made the setup-ready story explicit inside `templates_live_test.exs` so the wrapper's file list proves the operator journey without adding a new harness."
patterns-established:
  - "Proof-owner wrapper tasks should cite one top-level command and list delegated layers underneath."
  - "Phase-owned LiveView proofs should assert stable route and DOM-id seams across readiness, launch, and run-detail boundaries."
requirements-completed: []
duration: 3m 28s
completed: 2026-04-24
---

# Phase 27 Plan 01: Local first-run proof Summary

**Dedicated `mix kiln.first_run.prove` wrapper with locked delegation order, setup-ready LiveView proof continuity, and exact verification-command documentation**

## Performance

- **Duration:** 3m 28s
- **Started:** 2026-04-24T02:42:34Z
- **Completed:** 2026-04-24T02:46:02Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added `mix kiln.first_run.prove` as the explicit Phase 27 proof command, delegating only the two locked proof layers in order.
- Added a focused task test that pins the wrapper to `integration.first_run` first and the targeted LiveView files second.
- Extended the focused LiveView proof so the setup-ready `/settings` return context resumes `hello-kiln` and lands on the stable run-detail shell.
- Wrote `27-VERIFICATION.md` to cite only the top-level proof command while transparently listing its delegated subcommands.
- Phase 28 later became the requirement-owning closure slice after the milestone audit found the delegated runtime boot still failing on `oban_jobs`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the dedicated proof command and lock its delegation contract** - `3e321fe` (feat)
2. **Task 2: Make the setup-ready operator story explicit in the focused LiveView proof** - `298f097` (test)
3. **Task 3: Record the proof honestly in the phase verification artifact** - `c5cd963` (docs)

## Files Created/Modified

- `lib/mix/tasks/kiln.first_run.prove.ex` - thin wrapper task for the two-step proof command
- `test/mix/tasks/kiln.first_run.prove_test.exs` - delegation-order lock for the wrapper task
- `test/kiln_web/live/templates_live_test.exs` - setup-ready `/settings` to `hello-kiln` to `/runs/:id` proof seam
- `.planning/phases/27-local-first-run-proof/27-VERIFICATION.md` - exact command citation and delegated-layer explanation
- `.planning/phases/27-local-first-run-proof/27-01-SUMMARY.md` - execution summary for this plan

## Decisions Made

- Used a process-local runner override in the task test so the production task stays thin while the test can lock exact task names, order, and arguments.
- Kept `/settings` as supporting readiness coverage while moving the owning happy-path story into `templates_live_test.exs`, which is one of the files executed by the wrapper command.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Initial verification attempts were obscured by stale local `mix setup` / first-run processes and an expired Hex auth refresh prompt inside the shell-wrapped integration step.
- The final fix was to make the shell-wrapped proof layers non-interactive and run the focused test layer via `MIX_ENV=test mix test ...`, after which `mix kiln.first_run.prove` completed successfully end to end.

## User Setup Required

None - no external service configuration required.

## Historical Outcome

- Phase 27 successfully introduced the explicit proof command and focused LiveView proof seam.
- Final `UAT-04` closure moved to Phase 28 after the runtime-role repair and rerun.
