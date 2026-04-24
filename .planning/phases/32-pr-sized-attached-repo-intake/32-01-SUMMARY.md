---
phase: 32-pr-sized-attached-repo-intake
plan: "01"
subsystem: api
tags: [ecto, postgres, attached-repo, spec-drafts, specs]
requires:
  - phase: 31-draft-pr-trust-ramp-and-attach-proof
    provides: attached repo resolution, durable attached_repos records, and attach delivery seams
provides:
  - bounded attached-repo intake contract validation
  - durable attached request fields on spec drafts
  - immutable attached request snapshots on spec revisions
affects: [phase-33-continuity, phase-35-draft-pr-handoff, attach-intake]
tech-stack:
  added: []
  patterns: [embedded schema intake validation, attach-owned draft creation, draft-to-revision request snapshot copy]
key-files:
  created:
    - lib/kiln/attach/intake_request.ex
    - lib/kiln/attach/intake.ex
    - priv/repo/migrations/20260424152214_add_attached_repo_intake_fields.exs
    - test/kiln/attach/intake_test.exs
    - test/kiln/specs/attach_request_draft_test.exs
  modified:
    - lib/kiln/specs/spec_draft.ex
    - lib/kiln/specs/spec_revision.ex
    - lib/kiln/specs.ex
key-decisions:
  - "Use an embedded schema for bounded attached intake so validation stays server-owned before draft persistence."
  - "Persist attached request metadata on spec_drafts and copy it into spec_revisions during promotion instead of inventing a parallel intake store."
patterns-established:
  - "Attach intake writes through Kiln.Attach.Intake -> Kiln.Specs.create_draft/1, never direct Repo calls from UI code."
  - "Promotion copies attached request fields from SpecDraft to SpecRevision inside the existing Specs transaction."
requirements-completed: [WORK-01]
duration: 8 min
completed: 2026-04-24
---

# Phase 32 Plan 01: PR-sized attached intake summary

**Embedded-schema attached intake validation with durable draft fields and immutable promoted request snapshots**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-24T15:19:08Z
- **Completed:** 2026-04-24T15:26:44Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added `Kiln.Attach.IntakeRequest` and `Kiln.Attach.Intake` so attached work now enters through a bounded, validated feature-or-bugfix contract.
- Extended `spec_drafts` and `spec_revisions` with `attached_repo_id`, request kind, summary, acceptance criteria, and out-of-scope fields.
- Kept attached intake inside the existing `Specs` lifecycle, with tests proving invalid requests are rejected and promotion preserves the request contract.

## Task Commits

1. **Task 1: Define the bounded attached-request contract and attach-owned intake boundary** - `c9ce844` (test), `fec9e5b` (feat)
2. **Task 2: Persist attached-request fields on drafts and freeze them on promotion** - `eda711e` (test), `21959a8` (feat), `dfe4523` (fix)

## Files Created/Modified

- `lib/kiln/attach/intake_request.ex` - embedded schema and normalization rules for bounded attached intake
- `lib/kiln/attach/intake.ex` - attach-owned draft creation boundary that resolves attached repos server-side
- `priv/repo/migrations/20260424152214_add_attached_repo_intake_fields.exs` - draft/revision field additions and attached intake source constraint update
- `lib/kiln/specs/spec_draft.ex` - persistent draft fields and attached-intake validation
- `lib/kiln/specs/spec_revision.ex` - immutable revision fields and attached-request validation
- `lib/kiln/specs.ex` - promotion copy path for attached request snapshots
- `test/kiln/attach/intake_test.exs` - bounded request validation and attach lookup coverage
- `test/kiln/specs/attach_request_draft_test.exs` - draft persistence and promotion snapshot coverage

## Decisions Made

- Chose `:attached_repo_intake` as a dedicated `spec_drafts.source` value so attached brownfield intake is distinguishable from freeform and follow-up drafts.
- Kept the operator-facing markdown body as a rendered view of the structured contract while storing the durable request facts in explicit draft and revision columns.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered

- `bash script/precommit.sh` still fails on an unrelated repo-level gate: `priv/workflows/_test_bogus_signature.yaml` violates `check_no_signature_block`. This file is outside Plan 32-01 scope and was not modified here.
- Repo-wide precommit output still includes the previously accepted sandbox ownership noise during some tests, but the targeted phase tests passed and the formatter issue introduced during this plan was fixed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 33 can reuse one stable attached request contract and durable attached repo link instead of inferring scope from freeform prose.
- Phase 35 can build draft-PR handoff copy from the same immutable promoted request snapshot.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/32-pr-sized-attached-repo-intake/32-01-SUMMARY.md`.
- Task commits found in git history: `c9ce844`, `fec9e5b`, `eda711e`, `21959a8`, `dfe4523`.

---
*Phase: 32-pr-sized-attached-repo-intake*
*Completed: 2026-04-24*
