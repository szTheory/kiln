---
phase: 32-pr-sized-attached-repo-intake
plan: "03"
subsystem: web
tags: [phoenix-liveview, attached-repo, runs, validation]
requires:
  - phase: 32-pr-sized-attached-repo-intake
    provides: bounded attached-request intake contract plus attach-aware run launch seams
provides:
  - ready-state attached request form with deterministic DOM ids
  - attach liveview submit path that promotes and starts one bounded attached run
  - validation map aligned with the shipped phase 32 proof surface
affects: [WORK-01, attach-entry, attached-run-launch]
tech-stack:
  added: []
  patterns: [to_form-backed liveview validation, server-held attached repo identity, injected launch seams for liveview proof]
key-files:
  created:
    - .planning/phases/32-pr-sized-attached-repo-intake/32-03-SUMMARY.md
  modified:
    - lib/kiln_web/live/attach_entry_live.ex
    - test/kiln_web/live/attach_entry_live_test.exs
    - .planning/phases/32-pr-sized-attached-repo-intake/32-VALIDATION.md
decisions:
  - "Keep attached request validation changeset-backed in the LiveView by reusing Kiln.Attach.IntakeRequest through to_form/2."
  - "Reuse the server-held attached repo assign from ready state instead of reposting repo identity through hidden request fields."
  - "Expose attach launch seams through runtime opts in tests so LiveView proof can assert the intake -> promote -> start sequence deterministically."
metrics:
  duration: 33 min
  completed: 2026-04-24
---

# Phase 32 Plan 03: PR-sized attached repo intake summary

**Ready-state `/attach` launch form that turns one bounded request into one started attached run**

## Performance

- **Duration:** 33 min
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Extended `KilnWeb.AttachEntryLive` so a ready attached repo now renders a bounded feature-or-bugfix request form with stable ids for request kind, title, summary, three acceptance rows, three out-of-scope rows, submit, and success state.
- Kept request validation changeset-backed through `Kiln.Attach.IntakeRequest`, passed repeated list params through unchanged, and started the attach launch path through `Kiln.Attach.Intake.create_draft/2`, `Kiln.Specs.promote_draft/2`, and `Kiln.Runs.start_for_attached_request/3`.
- Expanded LiveView coverage for ready, invalid, and successful submit flows, then aligned `32-VALIDATION.md` with the five shipped Phase 32 proof files and marked Wave 0 complete.

## Task Commits

1. **Task 1 RED:** `8e75c41` — failing LiveView coverage for bounded attach request rendering and submit paths
2. **Task 1 GREEN:** `18dc001` — ready-state request form, validation, and successful attached run launch flow
3. **Task 1 format cleanup:** `1282512` — `mix format` for the touched LiveView and test files
4. **Task 2:** `24a24a3` — validation map updated to the actual Phase 32 proof surface

## Decisions Made

- Validation stays server-owned in the LiveView: list normalization and vague-request rejection come from the intake contract, not ad hoc UI parsing.
- Ready attach state is now the only trusted launch source. The LiveView persists the resolved attached repo on the server and never asks the browser to resubmit repo identity.
- Successful UI state is gated on the full backend sequence finishing. Invalid and blocked paths stay on-form and do not render `#attach-run-started`.

## Deviations from Plan

None - plan executed as written.

## Known Stubs

None.

## Issues Encountered

- `bash script/precommit.sh` initially failed on formatter checks for the touched LiveView and test files. Those were fixed with `mix format` and recommitted in `1282512`.
- Full `bash script/precommit.sh` still reports unrelated existing repo-wide failures outside Plan 32-03 scope, including `priv/workflows/_test_bogus_signature.yaml` tripping `check_no_signature_block` and a failing `test/kiln/agents/role_test.exs:49` assertion during the broader test suite.

## Verification

- `mix test test/kiln_web/live/attach_entry_live_test.exs` — passed
- `rg -n "attach-request-form|attach-request-kind|attach-request-title|attach-request-acceptance-1|attach-request-acceptance-2|attach-request-acceptance-3|attach-request-out-of-scope-1|attach-request-out-of-scope-2|attach-request-out-of-scope-3|attach-request-submit|attach-run-started" lib/kiln_web/live/attach_entry_live.ex test/kiln_web/live/attach_entry_live_test.exs` — passed
- `rg -n "attach_request\\[acceptance_criteria\\]\\[\\]|attach_request\\[out_of_scope\\]\\[\\]" lib/kiln_web/live/attach_entry_live.ex test/kiln_web/live/attach_entry_live_test.exs` — passed
- `rg -n "test/kiln/attach/intake_test\\.exs|test/kiln/specs/attach_request_draft_test\\.exs|test/kiln/runs/attached_request_start_test\\.exs|test/integration/attached_repo_intake_test\\.exs|test/kiln_web/live/attach_entry_live_test\\.exs|wave_0_complete: true|bash script/precommit\\.sh" .planning/phases/32-pr-sized-attached-repo-intake/32-VALIDATION.md` — passed
- `bash script/precommit.sh` — failed on unrelated existing repo-wide checks noted above

## Self-Check: PASSED

- Summary file exists at `.planning/phases/32-pr-sized-attached-repo-intake/32-03-SUMMARY.md`.
- Task commits found in git history: `8e75c41`, `18dc001`, `1282512`, `24a24a3`.
