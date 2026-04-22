---
phase: 14-fair-parallel-runs
plan: "03"
subsystem: testing
tags: [oban, telemetry, documentation]

key-files:
  created:
    - test/kiln/runs/run_parallel_fairness_test.exs
  modified:
    - lib/kiln/stages/next_stage_dispatcher.ex
    - test/kiln/stages/next_stage_dispatcher_test.exs
    - README.md

requirements-completed: [PARA-01]

duration: 0min
completed: 2026-04-22
---

# Phase 14 Plan 03 Summary

**Stage Oban jobs now carry top-level `run_id` in `meta`, multi-run dwell telemetry is proven under contention without sleeps, and README documents fairness grain plus the three wait signals.**

## Accomplishments

- `NextStageDispatcher.enqueue_next!/2` merges `Telemetry.pack_meta()` with `%{"run_id" => run_id}` for `StageWorker` inserts.
- Extended dispatcher tests to assert `meta["run_id"]` and preserved `kiln_ctx`.
- Added `run_parallel_fairness_test.exs` (`async: false`) counting `[:kiln, :run, :scheduling, :queued, :stop]` across multiple `RunDirector.start_run/1` calls.
- README **Fair scheduling** section (RR grain, telemetry event name, `run_queued` dwell, Oban vs Ecto pool waits).

## Self-Check: PASSED

- `mix test test/kiln/stages/next_stage_dispatcher_test.exs test/kiln/runs/run_parallel_fairness_test.exs --max-failures 1`
- `mix check`
