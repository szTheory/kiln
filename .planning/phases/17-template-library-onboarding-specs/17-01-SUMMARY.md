---
phase: 17-template-library-onboarding-specs
plan: "01"
subsystem: testing
tags: [templates, manifest, workflows, mix]

requires: []
provides:
  - Built-in template packs under priv/templates with JSON manifest
  - Kiln.Templates list/fetch/read API (allow-list only)
  - mix templates.verify + precommit / mix check wiring
affects: [phase-17-plan-02, phase-17-plan-03]

tech-stack:
  added: []
  patterns:
    - "Manifest is sole authority for template_id; paths joined only after fetch/1"

key-files:
  created:
    - priv/templates/manifest.json
    - priv/templates/hello-kiln/spec.md
    - lib/kiln/templates.ex
    - lib/kiln/templates/manifest.ex
    - lib/mix/tasks/templates.verify.ex
    - test/kiln/templates_manifest_test.exs
  modified:
    - mix.exs
    - .check.exs

key-decisions:
  - "Three templates: hello-kiln (elixir_phoenix_feature), gameboy-vertical-slice (rust_gb_dogfood_v1), markdown-spec-stub (elixir_phoenix_feature)"
  - "Authoring workflow YAML under each pack mirrors priv/workflows for mix templates.verify + dispatcher parity"

patterns-established:
  - "Kiln.Templates.shipped_workflow_yaml_path/1 for priv/workflows access"

requirements-completed: [WFE-01, ONB-01]

duration: 25min
completed: 2026-04-22
---

# Phase 17 Plan 01 Summary

Shipped git-versioned **built-in template library** infrastructure: manifest, three vetted packs (including Hello Kiln), **`Kiln.Templates`** allow-list API, and **`mix templates.verify`** integrated into **`mix precommit`** and **`.check.exs`**.

## Performance

- **Tasks:** 3 (atomic commits)
- **Files:** manifest + 3 template dirs + Elixir modules + Mix task + tests + gate wiring

## Task Commits

1. **Task 1: Directory layout + manifest** — `ff85ca2`
2. **Task 2: Kiln.Templates API** — `3440819`
3. **Task 3: mix templates.verify + CI** — `ca30a00`

## Self-Check: PASSED

- `mix templates.verify` — OK
- `mix test test/kiln/templates_manifest_test.exs` — green
- `mix compile --warnings-as-errors` — green

## Deviations

- None.
