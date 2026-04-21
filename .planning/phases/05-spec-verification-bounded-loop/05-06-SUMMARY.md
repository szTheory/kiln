---
phase: 05-spec-verification-bounded-loop
plan: "06"
subsystem: ui
tags: [liveview, uat, mix-task]

requires: []
provides:
  - "Operator `/specs/:id/edit` LiveView with debounced validation + Cmd/Ctrl+S colocated hook"
  - "`mix check_no_manual_qa_gates` scanning lib/kiln + lib/kiln_web with priv/qa_gate_allowlist.txt"
  - "CI `.check.exs` second ExUnit entry: `mix test --include kiln_scenario`"
affects: []

tech-stack:
  added: []
  patterns:
    - "Scenario body validation uses ScenarioParser before append-only revision insert"

key-files:
  created:
    - lib/kiln_web/live/spec_editor_live.ex
    - lib/kiln_web/live/spec_editor_live.html.heex
    - test/kiln_web/live/spec_editor_live_test.exs
    - priv/qa_gate_allowlist.txt
  modified:
    - lib/kiln_web/router.ex
    - lib/kiln/specs.ex
    - lib/mix/tasks/check_no_manual_qa_gates.ex
    - .check.exs

key-decisions:
  - "UAT-01: default `mix test` still excludes `:kiln_scenario`; CI runs an explicit second gate that includes the tag (documented in `.check.exs`)."

patterns-established: []

requirements-completed: [SPEC-01, UAT-01, UAT-02]

duration: 40min
completed: 2026-04-21
---

# Phase 05 Plan 06 Summary

**Operators get a coal-toned spec editor with JSV-backed saves, and CI enforces both compiled scenario tests and a grep gate against manual-QA escape hatches in application code.**

## Verification

- `mix test test/kiln_web/live/spec_editor_live_test.exs`
- `mix check_no_manual_qa_gates`
- `mix test --include kiln_scenario test/kiln/specs/ --max-failures=1`

## Self-Check: PASSED
