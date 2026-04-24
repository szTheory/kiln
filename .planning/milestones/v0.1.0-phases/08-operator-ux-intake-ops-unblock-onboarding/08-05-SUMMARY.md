---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "05"
subsystem: ui
tags: [liveview, ops, telemetry, secrets]

requires:
  - phase: 03
    provides: CostRollups, Secrets.present?, adapter model prefixes
provides:
  - Provider health dashboard at /providers
  - ModelRegistry.provider_health_snapshots/0
affects: [operator-ux]

tech-stack:
  added: []
  patterns: [ETS-backed provider counters for poll-visible health without exposing keys]

key-files:
  created:
    - lib/kiln_web/live/provider_health_live.ex
    - test/kiln_web/live/provider_health_live_test.exs
  modified:
    - lib/kiln/model_registry.ex
    - lib/kiln_web/router.ex
    - lib/kiln_web/components/layouts.ex

key-decisions:
  - "Degraded / red RAG takes precedence over API-key-missing when recent_error_rate >= 0.5 so operators see incident state first."
  - "Per-provider spend today is bucketed from CostRollups.by_provider model keys via model-id prefix routing."

patterns-established:
  - "Named ETS :kiln_provider_health_counters seeded on first snapshot; tests and future telemetry can bump ok/error without secrets."

requirements-completed: [OPS-01]

duration: 20min
completed: 2026-04-21
---

# Phase 08: operator-ux — Plan 05 Summary

**Operators get a polled `/providers` grid with RAG borders, key-presence booleans, spend and error-rate signals—no raw secrets.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-04-21
- **Tasks:** 2

## Accomplishments

- Added `ModelRegistry.provider_health_snapshots/0` plus test hooks `provider_health_record_ok/1` and `provider_health_record_error/1`.
- Shipped `KilnWeb.ProviderHealthLive` with `handle_info(:tick, …)` refresh, `id="provider-health"`, and navbar **Providers** link.

## Self-Check: PASSED

- `mix test test/kiln_web/live/provider_health_live_test.exs` — green
- `mix compile --warnings-as-errors` — green

## Deviations

- `token_budget_remaining_today` and live rate-limit headroom are nil/placeholder until a global budget source and adapter response hooks land; UI shows "—".
