---
phase: 17-template-library-onboarding-specs
plan: "02"
subsystem: database
tags: [specs, audit, templates, runs, migration]

requires: [phase-17-plan-01]
provides:
  - spec_drafts.source :template + migration
  - promote_draft/2 with optional template_id audit field
  - Specs.instantiate_template_promoted/1
  - Runs.create_for_promoted_template/2
affects: [phase-17-plan-03]

tech-stack:
  added: []
  patterns:
    - "Single-transaction template instantiate reuses promote_locked_open_draft/2"

key-files:
  created:
    - priv/repo/migrations/20260422185626_spec_drafts_source_template.exs
    - test/kiln/specs/template_instantiate_test.exs
  modified:
    - lib/kiln/specs/spec_draft.ex
    - priv/audit_schemas/v1/spec_draft_promoted.json
    - lib/kiln/specs.ex
    - lib/kiln/runs.ex

key-decisions:
  - "promote_draft/2 opts default [] keeps promote_draft/1 call sites valid"
  - "Run snapshots use Jason round-trip for caps_snapshot JSON compatibility"

requirements-completed: [WFE-01, ONB-01]

duration: 20min
completed: 2026-04-22
---

# Phase 17 Plan 02 Summary

Extended **spec draft** lifecycle for built-in templates: DB check constraint, **`promote_draft/2`** with audited **`template_id`**, **`instantiate_template_promoted/1`**, and **`Runs.create_for_promoted_template/2`** for queued runs.

## Task Commits

Single implementation commit: **`28793ec`**

## Self-Check: PASSED

- `mix test test/kiln/specs/template_instantiate_test.exs test/kiln/specs/spec_draft_test.exs`
- `mix compile --warnings-as-errors`

## Deviations

- Consolidated three plan tasks into one commit to keep `specs.ex` refactor atomic.
