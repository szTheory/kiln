---
phase: 04-agent-tree-shared-memory
plan: "02"
subsystem: api
tags: [ecto, pubsub, jsonl, transactions]

requires:
  - phase: 04-01
    provides: work_units + work_unit_events schemas
provides:
  - Kiln.WorkUnits transactional command API
  - ReadyQuery + perf proof (1000 rows, partial index, <20ms)
  - PubSub topic contract + JsonlAdapter export stub
affects: [04-03, 04-04]

tech-stack:
  added: []
  patterns: ["Repo.transact + conditional update_all for claims", "post-commit PubSub"]

key-files:
  created:
    - lib/kiln/work_units.ex
    - lib/kiln/work_units/ready_query.ex
    - lib/kiln/work_units/pubsub.ex
    - lib/kiln/work_units/jsonl_adapter.ex
    - docs/pubsub-topics-phase-04.md
    - test/kiln/work_units_test.exs
    - test/kiln/work_units/ready_query_test.exs
    - test/kiln/work_units/ready_query_perf_test.exs
    - test/kiln/work_units/pubsub_test.exs
    - test/kiln/work_unit_claim_race_test.exs
    - test/kiln/work_units_cli_safety_test.exs
  modified: []

key-decisions:
  - "claim_next_ready/2 locks the global ready set (not role-filtered in SQL) then returns `:role_mismatch` when the locked row’s `agent_role` differs."
  - "Conditional `update_all` on `updated_at` prevents lost updates when sandboxed tests cannot rely on cross-connection row locks."

patterns-established:
  - "Broadcast only after successful `Repo.transact/2`; tuple `{:work_unit, %{id, run_id, event}}`."

requirements-completed: [AGENT-04]

duration: 45min
completed: 2026-04-20
---

# Phase 04 Plan 02 Summary

Implemented `Kiln.WorkUnits` as the sole mutation path (seed, create, claim, block/unblock, close, handoff), query helpers, post-commit PubSub fan-out, and an export-only JSONL adapter with documentation for the topic contract.

## Self-Check: PASSED

- `mix test test/kiln/work_units_test.exs test/kiln/work_units/ test/kiln/work_unit_claim_race_test.exs test/kiln/work_units_cli_safety_test.exs`

## Task Commits

_(Single squashed commit in-session — split locally if you prefer atomic task SHAs.)_
