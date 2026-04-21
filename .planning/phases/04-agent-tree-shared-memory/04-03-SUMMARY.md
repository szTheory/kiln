---
phase: 04-agent-tree-shared-memory
plan: "03"
subsystem: infra
tags: [otp, supervisor, registry, work-units, agents]

requires:
  - phase: 04-02
    provides: Kiln.WorkUnits command surface and PubSub
provides:
  - per-run SessionSupervisor with seven fixed role GenServers
  - Kiln.Agents.Role behaviour + roles/* modules
  - RunSubtree hosts session supervisor; lived_child_pid targets session sup
affects: [04-04]

tech-stack:
  added: []
  patterns:
    - "Per-run {:via, Registry, {Kiln.RunRegistry, tuple}} naming for session + roles"
    - "Legacy empty Supervisor at __MODULE__ for incremental migration"

key-files:
  created:
    - lib/kiln/agents/role.ex
    - lib/kiln/agents/roles/mayor.ex
    - lib/kiln/agents/roles/planner.ex
    - lib/kiln/agents/roles/coder.ex
    - lib/kiln/agents/roles/tester.ex
    - lib/kiln/agents/roles/reviewer.ex
    - lib/kiln/agents/roles/uiux.ex
    - lib/kiln/agents/roles/qa_verifier.ex
    - test/kiln/agents/session_supervisor_test.exs
    - test/kiln/agents/session_supervisor_compatibility_test.exs
    - test/kiln/agents/role_test.exs
  modified:
    - lib/kiln/agents/session_supervisor.ex
    - lib/kiln/runs/run_subtree.ex
    - test/kiln/agents/adapter_contract_test.exs

key-decisions:
  - "Legacy global SessionSupervisor remains an empty Supervisor until 04-04 removes it from the app tree."
  - "Role workers poll + subscribe to run-scoped PubSub; Mayor seeds planner unit in init."

patterns-established:
  - "Fixed seven-role set under :one_for_one session supervisor; coordination only via WorkUnits."

requirements-completed: [AGENT-03]

duration: 45min
completed: 2026-04-21
---

# Phase 04 Plan 03 Summary

Per-run agent session supervision is real: `RunSubtree` hosts `SessionSupervisor`, which runs seven role workers registered in `Kiln.RunRegistry`, all coordinating through `Kiln.WorkUnits` instead of ad hoc `Repo` writes.

## Self-Check: PASSED

- `mix test test/kiln/agents/session_supervisor_test.exs test/kiln/agents/session_supervisor_compatibility_test.exs test/kiln/agents/role_test.exs test/kiln/agents/adapter_contract_test.exs test/kiln/application_test.exs`

## Task Commits

Single delivery commit bundles Task 1 (supervisor + RunSubtree) and Task 2 (roles + tests).
