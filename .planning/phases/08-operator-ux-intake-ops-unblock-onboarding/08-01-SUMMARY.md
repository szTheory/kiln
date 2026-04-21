---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "01"
subsystem: database
tags: [ecto, specs, inbox, audit]

requires: []
provides:
  - spec_drafts table and SpecDraft schema
  - Kiln.Specs draft CRUD + promote + archive
  - Audit kind spec_draft_promoted (34-taxonomy migration)

key-files:
  created:
    - priv/repo/migrations/20260421222250_create_spec_drafts.exs
    - priv/repo/migrations/20260421222251_extend_audit_event_kinds_p8_spec_draft_promoted.exs
    - lib/kiln/specs/spec_draft.ex
    - priv/audit_schemas/v1/spec_draft_promoted.json
    - test/kiln/specs/spec_draft_test.exs
  modified:
    - lib/kiln/specs.ex
    - lib/kiln/audit/event_kind.ex
    - test/kiln/audit/event_kind_test.exs
    - test/kiln/audit/append_test.exs

requirements-completed: [INTAKE-01, INTAKE-02]

completed: 2026-04-21
---

# Phase 8 Plan 08-01 Summary

**Persistent `spec_drafts` inbox plus transactional promote into `specs` / `spec_revisions` with `:spec_draft_promoted` audit in the same Postgres transaction.**

## Self-Check: PASSED

- `mix test test/kiln/specs/spec_draft_test.exs` and audit tests updated for 34 kinds.
