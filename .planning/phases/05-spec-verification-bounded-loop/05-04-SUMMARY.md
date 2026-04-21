---
phase: 05-spec-verification-bounded-loop
plan: "04"
subsystem: database
tags: [holdout, postgres, repo]

requires: []
provides:
  - "kiln_app REVOKE on holdout_scenarios + kiln_verifier narrow read path"
  - "VerifierReadRepo + integration tests"
  - "NextStageDispatcher holdout manifest filtering helper + tests"
affects: []

tech-stack:
  added: []
  patterns:
    - "Defense in depth: SQL privileges + read repo + pure allowlist for stage inputs"

key-files:
  created:
    - priv/repo/migrations/20260422000004_holdout_privileges.exs
    - lib/kiln/repo/verifier_read_repo.ex
    - test/kiln/specs/holdout_priv_test.exs
    - test/kiln/specs/holdout_manifest_test.exs
  modified:
    - config/runtime.exs
    - lib/kiln/stages/next_stage_dispatcher.ex

key-decisions: []

patterns-established: []

requirements-completed: [SPEC-04]

duration: 0min
completed: 2026-04-21
---

# Phase 05 Plan 04 Summary

**Holdout rows are blocked from the app role at the database layer while verifier code keeps a narrow read path; dispatcher-level tests prove holdout digests never enter non-verifier stage input maps.**

## Verification

- `mix test test/kiln/specs/holdout_priv_test.exs test/kiln/specs/holdout_manifest_test.exs`

## Self-Check: PASSED

Migration + repos + tests were already present; execute-phase re-ran the plan verification suite successfully.
