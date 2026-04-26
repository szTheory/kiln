---
phase: 30-attach-workspace-hydration-and-safety-gates
plan: "03"
subsystem: attach
tags: [attach, git, github, liveview, safety]
requires:
  - phase: 30-attach-workspace-hydration-and-safety-gates
    provides: "Canonical attach source resolution and managed workspace hydration"
provides:
  - "Typed attach safety preflight for dirty, detached, auth, and topology refusal states"
  - "Honest `/attach` blocked-vs-ready UX after hydration and preflight"
  - "Attach readiness that now means workspace hydration and safety checks both passed"
affects: [attach, trust gates, liveview, github delivery]
tech-stack:
  added: []
  patterns: ["Typed preflight refusal contract", "Hydrate-then-preflight attach submit flow"]
key-files:
  created: [lib/kiln/attach/safety_gate.ex, test/kiln/attach/safety_gate_test.exs]
  modified: [lib/kiln/attach.ex, lib/kiln_web/live/attach_entry_live.ex, test/kiln_web/live/attach_entry_live_test.exs]
decisions:
  - "Attach safety checks inspect both the operator source repo and the managed workspace so local-path attaches cannot hide dirty or detached state behind a clean mirror clone."
  - "GitHub auth remediation reuses the existing operator-setup vocabulary instead of inventing attach-specific copy."
  - "The `/attach` submit path now resolves, hydrates, persists, and preflights in one flow; only a passed preflight renders the ready panel."
metrics:
  duration: 27min
  completed: 2026-04-24
  tasks: 2
  files: 5
---

# Phase 30 Plan 03: Attach Safety Gates Summary

**Typed attach safety preflight and honest `/attach` blocked-vs-ready rendering before any later branch or draft-PR mutation path begins**

## Performance

- **Duration:** 27 min
- **Completed:** 2026-04-24
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `Kiln.Attach.SafetyGate` and exposed it through `Kiln.Attach.preflight_workspace/3`, with typed refusal states for dirty worktrees, detached HEADs, missing GitHub CLI readiness, and missing GitHub remote topology.
- Changed `/attach` submit handling from source-only resolution into the real attach path: resolve source, hydrate workspace, persist attached repo metadata, then preflight before showing readiness.
- Replaced the old false-ready resolved panel with stable `#attach-ready`, `#attach-ready-summary`, `#attach-blocked`, and `#attach-remediation-summary` states.

## Task Commits

1. **Task 1: Add a typed attach safety preflight for repo state and GitHub prerequisites**
   - `ac1e352` — RED: failing preflight tests
   - `11cd06a` — GREEN: attach safety preflight implementation
2. **Task 2: Render refusal and remediation states on `/attach` with exact operator guidance**
   - `97fdba5` — RED: failing LiveView blocked/ready tests
   - `665a0f1` — GREEN: `/attach` blocked and ready UX implementation

## Verification

- `mix test test/kiln/attach/safety_gate_test.exs` — passed
- `mix test test/kiln_web/live/attach_entry_live_test.exs` — passed
- `rg -n "dirty|detached|gh auth|blocked|remediation|attach-ready|attach-blocked" lib/kiln/attach.ex lib/kiln/attach/safety_gate.ex lib/kiln/operator_setup.ex lib/kiln_web/live/attach_entry_live.ex test/kiln/attach/safety_gate_test.exs test/kiln_web/live/attach_entry_live_test.exs` — matched expected preflight and UI surfaces
- `bash script/precommit.sh` — attach changes passed formatter, Dialyzer, and focused tests after fixes, but the repo-wide run still surfaces the pre-existing `check_no_signature_block` failure on `priv/workflows/_test_bogus_signature.yaml`, which is outside this plan

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed test helper temp-path collisions across separate Mix invocations**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** The new attach tests reused temp directory names across separate `mix test` processes, which made helper repo initialization flaky when old temp repos still existed on disk.
- **Fix:** Switched both new test helpers to process-independent temp paths using `System.os_time/1` plus monotonic unique integers.
- **Files modified:** `test/kiln/attach/safety_gate_test.exs`, `test/kiln_web/live/attach_entry_live_test.exs`

**2. [Rule 1 - Bug] Tightened repo-scope helper matches to satisfy Dialyzer**
- **Found during:** Repo-level precommit
- **Issue:** `Kiln.Attach.SafetyGate` included unreachable `:github_cli` branches in the dirty/detached repo-scope label logic, which Dialyzer correctly flagged.
- **Fix:** Narrowed the repo-scope helper to the only reachable scopes (`:source_repo`, `:attached_workspace`) and reran formatting plus precommit.
- **Files modified:** `lib/kiln/attach/safety_gate.ex`

## Known Stubs

None.

## Threat Flags

None.

## Issues Encountered

- The repo-wide `precommit` flow still reports the existing signature-block fixture violation in `priv/workflows/_test_bogus_signature.yaml`. This file was not touched by plan `30-03`.

## Self-Check: PASSED

- Found summary file: `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-03-SUMMARY.md`
- Found task commits: `ac1e352`, `11cd06a`, `97fdba5`, `665a0f1`
