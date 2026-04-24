---
phase: 15-run-comparison
plan: "01"
subsystem: ui
tags: [liveview, phoenix, routing, uuid]

requires: []
provides:
  - "/runs/compare route ordered before /runs/:run_id"
  - "RunCompareLive shell with UUID param gate and Layouts.app"
affects: []

tech-stack:
  added: []
  patterns:
    - "Invalid UUID query mirrors RunDetailLive (flash + redirect /)"

key-files:
  created:
    - lib/kiln_web/live/run_compare_live.ex
  modified:
    - lib/kiln_web/router.ex

key-decisions:
  - "Use static route string for push_patch swap/query to avoid verified-route query quirks in tests"

patterns-established:
  - "Compare assigns use {:ok, binary} tuples from Ecto.UUID.cast for snapshot wiring"

requirements-completed: [PARA-02]

duration: 30min
completed: 2026-04-22
---

# Phase 15 — Plan 01 Summary

**Compare route and LiveView shell ship before read model — `/runs/compare` is stable and UUID-gated.**

## Self-Check: PASSED

- `mix compile --warnings-as-errors`
- `mix format --check-formatted`

## Accomplishments

- Registered `live "/runs/compare", RunCompareLive, :index` immediately above the dynamic run route.
- Added `RunCompareLive` with `handle_params/3`, `Layouts.app`, and `#run-compare` shell.
