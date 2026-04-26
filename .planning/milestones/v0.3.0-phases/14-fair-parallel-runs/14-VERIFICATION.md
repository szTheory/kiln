---
phase: 14-fair-parallel-runs
status: passed
verified: 2026-04-22
---

# Phase 14 Verification — Fair parallel runs (PARA-01)

## Must-haves

| Item | Evidence |
|------|----------|
| Queued dwell telemetry event name + ms duration + safe metadata | `lib/kiln/runs/scheduling_telemetry.ex`, `test/kiln/runs/run_scheduling_telemetry_test.exs` |
| Emit only on successful `:queued` exit | `SchedulingTelemetry` guard + call from `transition_ok/4` after audit append |
| Fair RR ordering + cursor in RunDirector | `lib/kiln/runs/fair_round_robin.ex`, `lib/kiln/runs/run_director.ex`, tests |
| Oban `meta` includes `run_id` | `lib/kiln/stages/next_stage_dispatcher.ex`, `test/kiln/stages/next_stage_dispatcher_test.exs` |
| Multi-run contention telemetry test | `test/kiln/runs/run_parallel_fairness_test.exs` |
| README operator documentation | `README.md` § Fair scheduling |
| CI gate | `mix check` (includes `mix test` after Dialyzer — `.check.exs` `deps: [:dialyzer]` on `ex_unit`) |

## Commands run

```bash
mix check
```

## Human verification

None required for this phase.

## Gaps

None.
