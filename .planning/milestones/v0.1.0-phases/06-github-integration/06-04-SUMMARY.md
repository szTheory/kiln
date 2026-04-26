---
phase: 06-github-integration
plan: "04"
subsystem: database
tags: [postgres, audit, transitions, elixir]

requires: []
provides:
  - runs.github_delivery_snapshot jsonb
  - Kiln.GitHub.Promoter.apply_check_result/2
  - Transition meta diagnostic → escalation_detail
affects: []

tech-stack:
  added: []
  patterns:
    - "Runs.promote_github_snapshot/2 for internal snapshot merges"

key-files:
  created:
    - priv/repo/migrations/20260421204731_runs_github_delivery_snapshot.exs
    - lib/kiln/github/promoter.ex
    - test/kiln/github/promoter_test.exs
    - test/integration/github_delivery_test.exs
  modified:
    - lib/kiln/runs/run.ex
    - lib/kiln/runs.ex
    - lib/kiln/runs/transitions.ex
    - priv/audit_schemas/v1/ci_status_observed.json
    - lib/kiln/audit.ex

key-decisions:
  - "ci_status_observed audit payload extended with optional predicate_pass + head_sha"
  - "Promoter writes :ci_status_observed only for non-pending audit statuses"

patterns-established:
  - "Verifier-equivalent promotion path verifying → merged | planning"

requirements-completed: [GIT-01, GIT-02, GIT-03, ORCH-07]

duration: 40min
completed: 2026-04-21
---

# Phase 6 Plan 04 Summary

Added `github_delivery_snapshot` on runs, a promoter that updates snapshot + audit + transitions, and an integration test proving PushWorker idempotency against completed ops.

## Self-Check: PASSED

- `mix test test/kiln/github/promoter_test.exs test/integration/github_delivery_test.exs` — PASS
