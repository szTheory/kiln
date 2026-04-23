---
phase: 19-post-mortems-soft-feedback
plan: "01"
subsystem: database
tags: [audit, json-schema, migration]
requirements-completed: [FEEDBACK-01]
---

## Self-Check: PASSED

- Added `:operator_feedback_received` and `:post_mortem_snapshot_stored` to `Kiln.Audit.EventKind` (append-only).
- JSON Schemas under `priv/audit_schemas/v1/` for both kinds.
- Migration `extend_audit_event_kinds_p19_operator_feedback_post_mortem` regenerates CHECK from `EventKind.values_as_strings/0`.
- `Kiln.Audit.SchemaRegistry` loads schemas by convention from filenames — no `audit.ex` registry edits required.

## key-files.created

- `priv/audit_schemas/v1/operator_feedback_received.json`
- `priv/audit_schemas/v1/post_mortem_snapshot_stored.json`
- `priv/repo/migrations/20260422234015_extend_audit_event_kinds_p19_operator_feedback_post_mortem.exs`

## key-files.modified

- `lib/kiln/audit/event_kind.ex`
- `test/kiln/audit/event_kind_test.exs`
- `test/kiln/audit/append_test.exs`
