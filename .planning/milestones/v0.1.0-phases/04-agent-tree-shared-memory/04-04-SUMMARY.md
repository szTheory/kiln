---
phase: 04-agent-tree-shared-memory
plan: "04"
subsystem: infra
tags: [otp, integration, rehydration, work-units]

requires:
  - phase: 04-03
    provides: per-run SessionSupervisor + role tree
provides:
  - application tree without global SessionSupervisor
  - integration tests for role crash isolation, handoff, and concurrency
  - RehydrationCase helper to sandbox-allow role workers
affects: []

tech-stack:
  added: []
  patterns:
    - "allow_session_roles_for_run/1 for tests driving RunDirector-spawned subtrees"

key-files:
  created:
    - test/integration/agent_role_crash_test.exs
    - test/integration/agent_tree_shared_memory_test.exs
  modified:
    - lib/kiln/application.ex
    - test/kiln/application_test.exs
    - test/integration/run_subtree_crash_test.exs
    - test/integration/rehydration_test.exs
    - test/kiln/runs/run_director_test.exs
    - test/support/rehydration_case.ex

key-decisions:
  - "Infra child count drops from 14 to 13 with global session scaffold removed."
  - "Integration handoff test uses WorkUnits APIs + PubSub assertions (no Repo shortcuts after setup)."

patterns-established:
  - "RunSubtree crash tests allow role pids in sandbox after boot_scan."

requirements-completed: [AGENT-03, AGENT-04]

duration: 40min
completed: 2026-04-21
---

# Phase 04 Plan 04 Summary

Removed the global `SessionSupervisor` from `Kiln.Application`, refreshed supervision-tree expectations, and added integration coverage for cross-run role crash isolation, blocker/unblock PubSub, and concurrent claim serialization.

## Self-Check: PASSED

- `mix test test/kiln/application_test.exs test/kiln/runs/run_director_test.exs test/integration/run_subtree_crash_test.exs test/integration/rehydration_test.exs test/integration/agent_role_crash_test.exs test/integration/agent_tree_shared_memory_test.exs --include integration`

## Task Commits

Single delivery commit bundles Task 1 (app + director tests + rehydration helper) and Task 2 (integration suite).
