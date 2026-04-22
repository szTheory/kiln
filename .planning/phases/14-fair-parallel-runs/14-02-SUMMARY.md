---
phase: 14-fair-parallel-runs
plan: "02"
subsystem: infra
tags: [runs, genservers, fairness]

key-files:
  created:
    - lib/kiln/runs/fair_round_robin.ex
    - test/kiln/runs/fair_round_robin_test.exs
    - test/kiln/runs/run_director_fairness_test.exs
  modified:
    - lib/kiln/runs/run_director.ex

requirements-completed: [PARA-01]

duration: 0min
completed: 2026-04-22
---

# Phase 14 Plan 02 Summary

**RunDirector now orders `Runs.list_active/0` with deterministic round-robin (stable `inserted_at` + `id` tie-break) and persists `fair_cursor` after each successful subtree spawn.**

## Accomplishments

- Pure `Kiln.Runs.FairRoundRobin.order/2` with rotation after cursor and stale-cursor fallback.
- `RunDirector` state extended with `fair_cursor`; `do_scan/1` applies fair ordering before the spawn reduce loop.
- ExUnit coverage for ordering invariants plus a DB-backed parity check against `list_active/0`.

## Self-Check: PASSED

- `mix test test/kiln/runs/fair_round_robin_test.exs test/kiln/runs/run_director_fairness_test.exs test/kiln/application_test.exs --max-failures 1`
