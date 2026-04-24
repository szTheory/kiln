---
phase: 14-fair-parallel-runs
plan: "01"
subsystem: testing
tags: [telemetry, runs, ecto]

key-files:
  created:
    - lib/kiln/runs/scheduling_telemetry.ex
    - test/kiln/runs/run_scheduling_telemetry_test.exs
  modified:
    - lib/kiln/runs/transitions.ex

requirements-completed: [PARA-01]

duration: 0min
completed: 2026-04-22
---

# Phase 14 Plan 01 Summary

**Queued dwell is now a first-class `:telemetry` signal on successful exit from `:queued`, with ExUnit coverage and no new Prometheus label cardinality.**

## Accomplishments

- Added `Kiln.Runs.SchedulingTelemetry.emit_queued_dwell_stop/2` emitting `[:kiln, :run, :scheduling, :queued, :stop]` with integer ms duration and whitelisted metadata.
- Hooked emission from `Transitions.transition_ok/4` after successful audit append, using the pre-update `%Run{}` while still `:queued`.
- Documented wall-clock vs monotonic semantics and the “do not tag `run_id` on metrics” rule in module docs.

## Self-Check: PASSED

- `mix test test/kiln/runs/run_scheduling_telemetry_test.exs --max-failures 1`
- `mix compile --warnings-as-errors`
