---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "09"
subsystem: dtu-sidecar
tags:
  - phase-3
  - wave-4
  - sandboxes
  - dtu
  - sand-03
completed: 2026-04-20
---

# Phase 3 Plan 09: DTU Sidecar Summary

Closed the DTU Wave 4 gap by pairing the already-committed `priv/dtu/` sidecar project with the missing host-side support modules and tests. The repo now has both halves of the Phase 3 DTU surface: the standalone mock service and the Kiln-side health/callback/contract-test scaffolding.

## Shipped

- `priv/dtu/` mini Mix project with Bandit, Plug router, pinned GitHub contract snapshot, six GitHub handler families, chaos middleware, and a contract refresh Mix task
- `Kiln.Sandboxes.DTU.Supervisor` supervising `Kiln.Sandboxes.DTU.HealthPoll` and the loopback `Kiln.Sandboxes.DTU.CallbackRouter`
- `Kiln.Sandboxes.DTU.HealthPoll` polling `http://172.28.0.10:80/healthz`, emitting `:dtu_health_degraded` audit events after three consecutive misses, and broadcasting `{:dtu_unhealthy, :consecutive_misses}` on the `"dtu_health"` topic
- `Kiln.Sandboxes.DTU.CallbackRouter` accepting best-effort `POST /internal/dtu/event` callbacks and translating them into `:external_op_completed` audit events
- `Kiln.Sandboxes.DTU.ContractTest` as the Phase 3 Oban worker stub on the `:dtu` queue
- Targeted tests for the health poll, callback router, contract-test worker metadata, and DTU supervisor child shape

## Key Decisions

- The host-side DTU files were left untracked during the paused Wave 4 run even though the `priv/dtu/` project itself had already landed on `main`. This summary treats the final plan outcome as the union of both pieces because neither half is useful alone.
- `CallbackRouter` records the callback payload directly as an `:external_op_completed` audit payload. That preserves the “best-effort telemetry only” contract without creating a second DTU-only audit vocabulary.
- The contract-test worker remains unscheduled. The tests assert queue placement and the absence of a cron registration so the Phase 3 scaffold stays inert until Phase 6 activates drift checks.

## Deviations from Plan

- The DTU supervisor test originally compared child specs through the aliased `Kiln.Sandboxes.DTU.Supervisor` module, which shadowed `Elixir.Supervisor`. The final test now checks against `Elixir.Supervisor.child_spec/2`.
- The docker-gated DTU case template exists in `test/support/dtu_case.ex`, but the focused verification for this closeout stayed on the host-side unit/integration slice. The actual sidecar-in-container path still depends on an explicit docker-tagged run.

## Verification

- `mix compile --warnings-as-errors`
- `mix test test/kiln/sandboxes/dtu/health_poll_test.exs test/kiln/sandboxes/dtu/router_test.exs test/kiln/sandboxes/dtu/contract_test_test.exs --max-failures=1`

## Remaining Follow-On

- `Kiln.Sandboxes.DTU.Supervisor` and the DTU callback endpoint are not yet wired into the live application tree. Plan 03-11 owns that integration.
- Docker-tagged DTU end-to-end coverage remains opt-in through `Kiln.DtuCase`; it was not exercised in this Wave 4 recovery pass.
