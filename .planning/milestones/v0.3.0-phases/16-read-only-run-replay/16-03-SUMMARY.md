---
phase: 16-read-only-run-replay
plan: "03"
subsystem: ui
tags: [liveview, pubsub, lazyhtml, routing]

requires:
  - plan 01 routing + shell
  - plan 02 replay_page + broadcast
provides:
  - URL-driven scrub via at query + push_patch
  - Range scrubber, first/prev/next/last, jump to latest buffer
  - Terminal vs in-flight subscription gating with debounced refresh
  - Run detail Timeline link; Open in Audit deep link
affects: []

tech-stack:
  added: []
  patterns: [debounced PubSub coalescing in LiveView]

key-files:
  created:
    - test/kiln_web/live/run_replay_live_test.exs
  modified:
    - lib/kiln_web/live/run_replay_live.ex
    - lib/kiln_web/live/run_detail_live.ex

key-decisions:
  - "Spine window size 200 for replay_page calls"
  - "Unknown at= UUID falls back to tail with inline warning + flash info"

patterns-established:
  - "Read-only replay: no Audit.append / Repo mutations in RunReplayLive"

requirements-completed: [REPL-01]

duration: 45min
completed: 2026-04-22
---

# Phase 16 Plan 03 Summary

**Replay is URL-addressable with scrub controls, live tail coalescing for in-flight runs, and navigation from run detail and audit.**

## Self-Check: PASSED

- `mix test test/kiln_web/live/run_replay_live_test.exs`
- `mix test test/kiln/audit_replay_test.exs`
- `mix compile --warnings-as-errors`

## Deviations

- `page_ending_at/3` is implemented as a private helper in `RunReplayLive` rather than extending `replay_page/1`, to keep the audit module API aligned with plan 02 while still satisfying the must-have that the LiveView uses `replay_page/1` for tail/forward pages.
