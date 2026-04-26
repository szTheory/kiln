---
phase: 07-core-run-ui-liveview
status: clean
reviewed_at: 2026-04-21
depth: quick
---

# Phase 07 Code Review

## Summary

Operator-facing LiveViews and read-only dashboards were added with `allow?`
stubs, PubSub-aligned run board streams, and snapshot/cost/audit query paths.
No blocking security regressions identified in quick review.

## Findings

- **Advisory:** `Kiln.Workflows.persist_snapshot_from_disk/2` is skipped when
  `:skip_workflow_snapshot_persist` is true (test config). Production relies on
  `Kiln.Workflows.load/1` — direct `Loader.load/1` bypasses snapshots by design.
- **Advisory:** `RunDetailLive` uses `String.to_existing_atom/1` for audit
  `event_kind` filters only after allowlist check against `EventKind.values/0`.

## Self-check

- `mix test` (557 tests) — green at review time.
