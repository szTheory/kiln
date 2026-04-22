---
phase: 16-read-only-run-replay
plan: "02"
subsystem: database
tags: [ecto, audit, keyset, pubsub]

requires: []
provides:
  - Kiln.Audit.replay_page/1 forward keyset + :tail anchor
  - PubSub broadcast audit:run:<id> after successful inserts with run_id
affects: [RunReplayLive]

tech-stack:
  added: []
  patterns: [keyset pagination with limit+1 truncated probe]

key-files:
  created:
    - test/kiln/audit_replay_test.exs
  modified:
    - lib/kiln/audit.ex

key-decisions:
  - "truncated means at least one more row exists in forward order"
  - "Tail anchor returns latest N rows ascending with truncated flag for older rows"

patterns-established:
  - "Composite cursor (occurred_at, id) with ORDER BY occurred_at ASC, id ASC"

requirements-completed: [REPL-01]

duration: 30min
completed: 2026-04-22
---

# Phase 16 Plan 02 Summary

**Audit replay gains a bounded keyset/tail read API plus optional per-run PubSub tails after append.**

## Self-Check: PASSED

- `mix test test/kiln/audit_replay_test.exs`
- `mix compile --warnings-as-errors`

## Deviations

- `page_ending_at/3` windowing for deep `at=` links lives in `RunReplayLive` (plan 03) while `replay_page/1` covers forward pages and tail anchor per plan 02 contract.
