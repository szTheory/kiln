---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "10"
subsystem: web
tags: [liveview, pubsub, ui]

requirements-completed: [UI-07, UI-08, UI-09]

completed: 2026-04-21
---

# Phase 08 — Plan 10 Summary

Shipped global factory chrome: **`FactoryHeader`** in `Layouts.app` fed by **`factory:summary`** (debounced `Kiln.FactorySummaryPublisher` on `runs:board`), **`KilnWeb.FactorySummaryHook`** on the default `live_session`, **`RunProgress`** on run board cards and run detail header, and an **`agent_ticker`** stream on `/` only with rate-limited publishes from `Kiln.Runs.Transitions` via **`Kiln.AgentTickerRateLimiter`**.

Also synced `EventKind` tests/docs for the Phase 8 `:follow_up_drafted` append (35 kinds).

## Self-Check: PASSED

- `grep -n 'id="factory-header"' lib/kiln_web/components/factory_header.ex` — matches
- `grep -n "FactoryHeader" lib/kiln_web/components/layouts.ex` — matches
- `grep -n "factory:summary" lib/kiln_web/components/factory_header.ex` — matches
- `grep -n "RunProgress" lib/kiln_web/live/run_board_live.ex` — matches
- `grep -n "RunProgress" lib/kiln_web/live/run_detail_live.ex` — matches
- `grep -n "Not enough history" lib/kiln_web/components/run_progress.ex` — matches
- `grep -n 'id="agent-ticker"' lib/kiln_web/live/run_board_live.ex` — matches
- `grep -n "agent_ticker" lib/kiln_web/live/run_board_live.ex` — matches
- `grep -n "stream(:ticker_lines" lib/kiln_web/live/run_board_live.ex` — matches
- `mix compile --warnings-as-errors` — green
- `mix test test/kiln_web/live/run_board_live_test.exs test/kiln_web/components/factory_header_test.exs` — green
- `mix test` — green
