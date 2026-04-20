---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "10"
subsystem: stage-dispatch-integration
tags:
  - phase-3
  - wave-5
  - stages
  - dispatch
  - workflow
completed: 2026-04-20
---

# Phase 3 Plan 10: Stage Dispatch Integration Summary

Connected Phase 3's workflow auto-dispatch path. Stage completion now materializes downstream `stage_runs`, enqueues the next `StageWorker` job automatically, and the end-to-end integration test advances by draining the queue instead of hand-driving each stage in a loop.

## Shipped

- `Kiln.Stages.NextStageDispatcher` as a pure module that loads the pinned workflow graph, waits for all parent stages to reach `:succeeded`, creates the next `stage_runs` row, and enqueues a `StageWorker` job with idempotency key `run:<run_id>:stage:<workflow_stage_id>`
- `Kiln.Stages.StageWorker` now updates `stage_runs.state` through `:running` and `:succeeded` / `:failed`, then calls `NextStageDispatcher.enqueue_next!/2` after successful completion
- `test/kiln/stages/next_stage_dispatcher_test.exs` covering API shape, linear auto-enqueue, and leaf-stage no-op behavior
- Updated `test/integration/workflow_end_to_end_test.exs` to seed only the planning stage and rely on queue drain + auto-enqueue for the rest of the workflow

## Key Decisions

- The dispatcher keys parent satisfaction off `StageRun.state == :succeeded`, not the plan text's `:completed`. `stage_runs` already ships with the six-state enum `:pending | :dispatching | :running | :succeeded | :failed | :cancelled`, so the dispatcher follows the live schema rather than introducing a parallel terminal vocabulary.
- Downstream stage input is still synthesized with placeholder artifact refs. That keeps the Phase 3 queueing contract live without pretending the StageWorker has already reached the future fully-agentic prompt/build/verify chain.
- The next-stage idempotency key uses the workflow stage id rather than the `stage_runs.id`. That keeps enqueue dedupe stable across retries while still passing the actual `stage_run_id` row UUID in job args.

## Deviations from Plan

- The plan called for replacing the Phase 2 stub dispatch with the full `BudgetGuard -> Hydrator -> DockerDriver -> Agents.complete -> Harvester` chain. This implementation stops at the dispatcher/state-transition integration and preserves the stub artifact generation path for stage execution itself.
- Because the workflow graph still contains a `merge` stage, the queue-drain integration path now materializes five `stage_runs` instead of the old four-stage Phase 2 loop.

## Verification

- `mix test test/kiln/stages/stage_worker_test.exs test/kiln/stages/next_stage_dispatcher_test.exs test/integration/workflow_end_to_end_test.exs`

## Remaining Follow-On

- The StageWorker still uses the Phase 2 stub artifact path instead of the full sandbox + agent + harvest execution chain.
- Retry/attempt semantics for downstream stage creation remain first-attempt-only; later retry waves can extend that without changing the dispatcher API.
