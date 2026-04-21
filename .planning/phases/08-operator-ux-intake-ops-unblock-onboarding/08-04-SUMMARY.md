---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "04"
subsystem: database
tags: [intake, specs, external_operations, liveview]

requires:
  - phase: 01
    provides: spec_drafts table
provides:
  - Idempotent follow-up drafts from merged runs
  - Run detail "File as follow-up" action
affects: [operator-ux]

key-files:
  created:
    - priv/repo/migrations/20260421224334_spec_drafts_follow_up_fields.exs
    - priv/repo/migrations/20260421224335_extend_audit_event_kinds_p8_follow_up_drafted.exs
    - priv/audit_schemas/v1/follow_up_drafted.json
    - test/kiln/specs/follow_up_draft_test.exs
  modified:
    - lib/kiln/specs.ex
    - lib/kiln/specs/spec_draft.ex
    - lib/kiln/artifacts.ex
    - lib/kiln/audit/event_kind.ex
    - lib/kiln_web/live/run_detail_live.ex
    - test/kiln_web/live/run_detail_live_test.exs
    - test/kiln/audit/append_test.exs

requirements-completed: [INTAKE-03]

completed: 2026-04-21
---

# Phase 08 — Plan 04 Summary

Merged runs can file a follow-up inbox draft once per LiveView correlation id; duplicates reuse the same draft via `external_operations` idempotency keys and return the existing row when the op is already `:completed`.

## Self-Check: PASSED

- `grep -n "follow_up_draft" lib/kiln/specs.ex` — matches
- `grep -n "ExternalOperations" lib/kiln/specs.ex` — matches
- `grep -n "File as follow-up"` / `phx-click="follow_up"` in `run_detail_live.ex` — matches
- `mix test test/kiln/specs/follow_up_draft_test.exs test/kiln_web/live/run_detail_live_test.exs` — green
