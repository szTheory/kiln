---
phase: 32-pr-sized-attached-repo-intake
plan: "02"
subsystem: api
tags: [ecto, runs, attached-repo, specs, integration-testing]
requires:
  - phase: 32-pr-sized-attached-repo-intake
    provides: bounded attached-request draft intake plus promoted spec/revision snapshots
provides:
  - durable run links from attached runs to attached_repos, specs, and spec_revisions
  - attach-aware Runs create/start seams with template-style blocked-start handling
  - integration proof that one promoted attached request can launch a durable attached run
affects: [phase-33-continuity, phase-35-draft-pr-handoff, brownfield-run-launch]
tech-stack:
  added: []
  patterns: [run-owned attached launch seam, explicit run foreign keys for brownfield continuity]
key-files:
  created:
    - priv/repo/migrations/20260424152932_add_attached_request_run_links.exs
    - test/kiln/runs/attached_request_start_test.exs
    - test/integration/attached_repo_intake_test.exs
  modified:
    - lib/kiln/runs.ex
    - lib/kiln/runs/run.ex
key-decisions:
  - "Model attached launch identity as first-class foreign keys on runs instead of hiding repo/spec linkage inside JSON snapshots."
  - "Reuse the existing Runs blocked-start contract and shipped workflow loading path for attached requests rather than adding a LiveView-owned launcher."
patterns-established:
  - "Attached brownfield work starts through Kiln.Runs with a promoted %{spec, revision} contract plus attached_repo_id."
  - "Repeated attached-request launches must keep explicit attached_repo_id, spec_id, and spec_revision_id on every created run row."
requirements-completed: [WORK-01]
duration: 17 min
completed: 2026-04-24
---

# Phase 32 Plan 02: PR-sized attached run launch summary

**Attach-aware run launch through Kiln.Runs with durable repo/spec/revision links and end-to-end intake-to-run proof**

## Performance

- **Duration:** 17 min
- **Started:** 2026-04-24T15:29:00Z
- **Completed:** 2026-04-24T15:46:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added explicit `attached_repo_id`, `spec_id`, and `spec_revision_id` linkage on `runs` so attached launches remain traceable after promotion.
- Introduced `Runs.create_for_attached_request/2` and `Runs.start_for_attached_request/3` with the same blocked-start discipline and workflow checksum capture used by template launches.
- Added unit and integration proof for `Attach.Intake -> Specs.promote_draft -> Runs.start_for_attached_request`, including a repeated-start linkage check.

## Task Commits

1. **Task 1: Add run-schema linkage and an attach-aware start seam under `Kiln.Runs`** - `aaca39b` (feat)
2. **Task 2: Prove the bounded intake can promote and start one attached run** - `2f64636` (test)
3. **Formatting follow-up for plan verification** - `ee84993` (style)

## Files Created/Modified

- `priv/repo/migrations/20260424152932_add_attached_request_run_links.exs` - adds attached repo, spec, and spec revision foreign keys to `runs`
- `lib/kiln/runs/run.ex` - exposes the new run linkage fields and constraints on the schema
- `lib/kiln/runs.ex` - adds attach-aware queued-run creation and typed blocked start behavior
- `test/kiln/runs/attached_request_start_test.exs` - unit coverage for persisted linkage, blocked returns, and workflow checksum loading
- `test/integration/attached_repo_intake_test.exs` - integration proof for intake promotion and attached run launch linkage

## Decisions Made

- Kept attached launch identity on the `runs` row itself because later continuity and review flows need simple joins, not snapshot parsing.
- Bound attached starts to the shipped `elixir_phoenix_feature` workflow for now so brownfield requests follow the same checksum and dispatcher discipline as the existing template path.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `bash script/precommit.sh` initially failed on formatting for the new launcher and test files; `mix format` fixed those changes and the targeted plan tests passed afterward.
- Repo-wide `precommit` still fails on unrelated existing issues outside Plan 32-02 scope: the known `priv/workflows/_test_bogus_signature.yaml` signature-block gate and a broader set of pre-existing sandbox/repo startup failures during unit tests.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 33 can query explicit run-to-attached-repo and run-to-promoted-request links instead of inferring continuity from snapshots.
- Phase 35 can build review and draft-PR handoff copy from one durable attached run identity anchored to the promoted request.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/32-pr-sized-attached-repo-intake/32-02-SUMMARY.md`.
- Task commits found in git history: `aaca39b`, `2f64636`, `ee84993`.

---
*Phase: 32-pr-sized-attached-repo-intake*
*Completed: 2026-04-24*
