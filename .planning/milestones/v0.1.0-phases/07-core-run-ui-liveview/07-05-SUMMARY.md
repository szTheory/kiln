---
phase: 07-core-run-ui-liveview
plan: "05"
status: complete
completed_at: 2026-04-21
---

# Plan 07-05 Summary

## Delivered

- `Kiln.CostRollups` with `by_run/1`, `by_workflow/1`, `by_agent_role/1`, `by_provider/1` (UTC window).
- `CostLive` at `/costs` with tabs, summary strip, empty copy, `allow?` hook.

## Verification

- `mix test test/kiln/cost_rollups_test.exs test/kiln_web/live/cost_live_test.exs`

## Self-Check: PASSED
