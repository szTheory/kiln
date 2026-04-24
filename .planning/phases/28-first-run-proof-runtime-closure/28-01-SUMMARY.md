---
phase: 28-first-run-proof-runtime-closure
plan: "01"
subsystem: runtime-proof
tags: [oban, postgres, runtime-role, integration, verification]
requires:
  - phase: 27-local-first-run-proof
    provides: top-level proof command and focused LiveView proof seam
provides:
  - Durable Oban runtime privilege repair for existing repositories
  - Explicit `kiln_app` runtime-role activation in the delegated first-run proof
  - Phase 28 verification artifact owning final `UAT-04` closure
  - Reconciled roadmap and requirements truth after the rerun
affects: [uat-04, first-run-proof, oban-runtime, planning-ssot]
tech-stack:
  added: []
  patterns: [forward-only repair migrations, restricted runtime proof, superseded verification artifacts]
key-files:
  created:
    - priv/repo/migrations/20260424080355_grant_oban_runtime_privileges.exs
    - priv/repo/migrations/20260424080559_add_oban_met_runtime_function.exs
    - test/kiln/repo/migrations/oban_runtime_privileges_test.exs
    - .planning/phases/28-first-run-proof-runtime-closure/28-VERIFICATION.md
    - .planning/phases/28-first-run-proof-runtime-closure/28-01-SUMMARY.md
  modified:
    - test/integration/first_run.sh
    - config/config.exs
    - .planning/phases/27-local-first-run-proof/27-VERIFICATION.md
    - .planning/phases/27-local-first-run-proof/27-01-SUMMARY.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
key-decisions:
  - "Kept `mix kiln.first_run.prove` as the owning proof command and repaired the runtime seam underneath it instead of inventing a replacement harness."
  - "Granted `kiln_app` the Oban table, sequence, peer, and estimate-function access needed for real runtime boot."
  - "Made Phase 28 the closure authority for `UAT-04` and downgraded Phase 27 artifacts to explicit historical context."
patterns-established:
  - "Repository-level proof closure lives in the phase that carries the final rerun-backed verification artifact, not whichever phase first introduced the wrapper command."
requirements-completed: [UAT-04]
completed: 2026-04-24
---

# Phase 28 Plan 01: First-run proof runtime closure Summary

## Accomplishments

- Added a forward-only Oban privilege repair for existing repositories, including the Oban Met estimate function required by restricted runtime boot.
- Added a focused regression proving `kiln_app` can exercise the Oban runtime surfaces that previously failed before `/health`.
- Updated `test/integration/first_run.sh` so the delegated proof boots Phoenix as `kiln_app` instead of silently inheriting an unrestricted session.
- Re-ran `mix kiln.first_run.prove`, recorded the successful closure in Phase 28, and reconciled Phase 27, `ROADMAP.md`, and `REQUIREMENTS.md`.

## Verification

- `mix test test/kiln/repo/migrations/oban_runtime_privileges_test.exs`
- `mix integration.first_run`
- `mix kiln.first_run.prove`
- `bash script/precommit.sh`

## Outcome

`UAT-04` is now closed on current repository evidence, and the planning SSOT no longer contradicts the runtime proof result.
