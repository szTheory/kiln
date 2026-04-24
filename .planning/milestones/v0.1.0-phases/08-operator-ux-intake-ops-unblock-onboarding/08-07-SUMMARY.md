---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "07"
subsystem: ops
tags: [diagnostics, zip, liveview]

requirements-completed: [OPS-05]

completed: 2026-04-21
---

# Phase 08 — Plan 07 Summary

Added `Kiln.Diagnostics.Snapshot.build_zip/1` (manifest + redacted log slice), a browser `GET` download endpoint, and a **Bundle last 60 minutes** control on run detail that flashes success then navigates to the zip URL.

## Self-Check: PASSED

- `grep -n "defmodule Kiln.Diagnostics.Snapshot" lib/kiln/diagnostics/snapshot.ex` — matches
- `grep -n "redact" lib/kiln/diagnostics/snapshot.ex` — matches
- `grep -n "Bundle last 60 minutes" lib/kiln_web/live/run_detail_live.ex` — matches
- `grep -n "allow?" lib/kiln_web/live/run_detail_live.ex` — matches (bundle handler gated)
- `mix test test/kiln/diagnostics/snapshot_test.exs test/kiln_web/controllers/diagnostics_zip_controller_test.exs test/kiln_web/live/run_detail_live_test.exs` — green

## Deviations

- Phoenix 1.8 in this workspace has no `Phoenix.LiveView.send_download/3`; download is served via `KilnWeb.DiagnosticsZipController` + `push_navigate` from the LiveView event.
