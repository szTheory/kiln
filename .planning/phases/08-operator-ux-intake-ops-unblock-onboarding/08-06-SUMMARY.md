---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "06"
subsystem: ui
tags: [costs, intel, liveview]

provides:
  - CostLive Summary vs Intel surfaces with period/pivot query params
  - Advisory line when aggregates show spend > 0
requirements-completed: [OPS-04]

completed: 2026-04-21
---

# Phase 08 — Plan 06 Summary

Extended `CostLive` with **Summary | Intel** navigation, `period=` (day/week/month) and `pivot=` rollups on Intel, and a deterministic advisory string when spend exists. Legacy `?tab=run` URLs still map to Summary + that pivot.

## Self-Check: PASSED

- `grep -n 'tab=intel\|"intel"' lib/kiln_web/live/cost_live.ex` — matches
- `grep -n "You're spending" lib/kiln_web/live/cost_live.ex` — matches
- `mix test test/kiln_web/live/cost_live_test.exs` — green
- `mix compile --warnings-as-errors` — green

## Notes

- LiveView HTML-escapes apostrophes in advisory text; tests assert with a regex that accepts `'` or `&#39;`.
