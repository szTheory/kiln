---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "06"
subsystem: model-routing-and-budget
tags:
  - phase-3
  - wave-2
  - pricing
  - model-registry
  - budget-guard
  - telemetry
  - agent-02
  - agent-05
  - ops-02
completed: 2026-04-20
---

# Phase 3 Plan 06: Model Registry, Pricing, BudgetGuard, Telemetry Summary

Recovered and finished the Wave 2 routing-and-budget work from the interrupted worktree output. The committed worktree base shipped pricing and model registry; the final recovery pass on `main` completed `BudgetGuard`, telemetry fallback auditing, and the audit-schema/test updates.

## Shipped

- `Kiln.Pricing` with provider pricing tables in `priv/pricing/v1/*.exs`
- `Kiln.ModelRegistry` and `Kiln.ModelRegistry.Preset` with six preset files in `priv/model_registry/*.exs`
- `mix kiln.registry.show <preset>` for operator-visible role-to-model resolution
- `Kiln.Agents.BudgetGuard.check!/2` enforcing the seven-step per-call budget pre-flight
- `Kiln.Agents.TelemetryHandler` converting adapter stop telemetry into `model_routing_fallback` audit rows
- Updated `budget_check_passed` and `budget_check_failed` audit schemas to the payload shape actually emitted by `BudgetGuard`
- 52 targeted tests passing across pricing, model registry, budget guard, telemetry handler, and audit append validation

## Key Decisions

- `Kiln.ModelRegistry.next/3` is deterministic by role order so fallback selection is stable and auditable.
- Unknown pricing models fall back to zero-cost estimation rather than crashing the run path.
- `BudgetGuard` has no escape hatch; on breach it writes audit first, then raises `Kiln.Blockers.BlockedError` with `reason: :budget_exceeded`.
- `BudgetGuard` only attempts desktop notification when `Kiln.Notifications` is loaded and the dedup ETS table is actually live. This preserves the current Phase 3/11 wiring contract instead of crashing before the notification cache is supervised.
- `TelemetryHandler` only emits fallback audit rows on `:stop` events where `requested_model != actual_model_used`; `:start` and `:exception` are accepted but remain no-op in Phase 3.

## Recovery Notes

- The interrupted worktree held a clean committed base plus uncommitted follow-up files.
- Recovery merged the committed base, then finished the remaining `BudgetGuard` / telemetry / schema / test work directly on `main`.
- The recovered branch passed targeted tests before and after transplant, with one real integration bug fixed: notification dedup state must exist before `BudgetGuard` can call the notification surface.

## Verification

- `mix test --max-cases 1 test/kiln/pricing_test.exs test/kiln/model_registry_test.exs test/kiln/model_registry/presets_test.exs test/kiln/agents/budget_guard_test.exs test/kiln/agents/telemetry_handler_test.exs test/kiln/audit/append_test.exs`
- Result: `52 tests, 0 failures`
