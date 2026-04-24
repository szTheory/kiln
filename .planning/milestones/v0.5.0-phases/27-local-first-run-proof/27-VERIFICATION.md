---
status: superseded
phase: 27-local-first-run-proof
verified: 2026-04-24
superseded_by: 28-first-run-proof-runtime-closure
requirements: []
---

# Phase 27 Verification

## Owning Proof Command

`mix kiln.first_run.prove`

Phase 27 introduced this command, but it no longer owns `UAT-04` closure.
Phase 28 reran the same command after the runtime-role repair and now carries the
final verification authority.

## Delegated Layers

1. `mix integration.first_run`
   Proves the real local topology contract: `.env`, Docker Compose data plane, host Phoenix boot, and `/health`.
2. `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`
   Proves the operator-visible setup-ready path: `/settings` return context into `hello-kiln`, `Start run`, and arrival on `/runs/:id` with the stable `#run-detail` proof surface.

## Scope

This command is the Phase 27 proof for the setup-ready local first-run journey only.
It does not claim to replace the broader merge-authority suite, `mix shift_left.verify`, or direct shell ownership of `test/integration/first_run.sh`.

## Historical Note

The command and focused LiveView seam landed in Phase 27. The original
completion claim was later contradicted by the milestone audit, which found the
delegated integration layer still failing on `oban_jobs` before `/health`.
Phase 28 repaired that runtime seam and reran the same top-level command, so
this artifact is retained as historical context only.
