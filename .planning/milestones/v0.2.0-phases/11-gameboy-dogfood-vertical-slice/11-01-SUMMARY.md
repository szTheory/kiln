---
phase: 11-gameboy-dogfood-vertical-slice
plan: "01"
subsystem: testing
tags: [scenario-ir, jsv, workflows, dogfood, argv-only]

requires:
  - phase: 10-local-operator-readiness
    provides: Operator readiness baseline for dogfood runs
provides:
  - Scenario IR v1 with discriminated assert vs shell steps
  - ScenarioCompiler codegen for argv-only System.cmd/3
  - rust_gb_dogfood_v1 workflow on disk
  - Canonical GB slice spec stub under priv/dogfood
affects:
  - phase-11-external-rust-workspace

tech-stack:
  added: []
  patterns:
    - "Shell oracle: no shell string; argv list only; cwd optional relative to File.cwd!/0"

key-files:
  created:
    - priv/workflows/rust_gb_dogfood_v1.yaml
    - priv/dogfood/gb_vertical_slice_spec.md
    - test/kiln/dogfood/gb_vertical_slice_spec_test.exs
  modified:
    - priv/jsv/scenario_ir_v1.json
    - lib/kiln/specs/scenario_parser.ex
    - lib/kiln/specs/scenario_compiler.ex
    - test/kiln/specs/scenario_parser_test.exs
    - test/kiln/specs/scenario_compiler_test.exs
    - test/kiln/workflows/compiler_test.exs
    - README.md
    - .formatter.exs

key-decisions:
  - "model_profile `elixir_lib` for rust_gb_dogfood_v1 — honest non-Phoenix-deceptive label per D-1103b (not phoenix_saas_feature)"
  - "Generated shell code uses `[program | args] = argv` instead of Enum.at!/2 (not available in Elixir 1.19)"

patterns-established:
  - "Parser validates shell argv for ; and newlines after JSV pass"

requirements-completed: [DOGFOOD-01, UAT-01, UAT-02]

duration: 45min
completed: 2026-04-22
---

# Phase 11 Plan 01 Summary

Kiln now accepts **shell** steps in scenario IR, compiles them to **argv-only** `System.cmd/3`, ships **`rust_gb_dogfood_v1`** with honest caps and tags, and holds a **three-scenario** dogfood spec that runs `mix` oracles in CI until the external Rust workspace exists.

## Performance

- **Tasks:** 5 (4 automated in-session; Task 5 README done in same pass)
- **Commits:** `b13024b`, `3d2c2e8`, `e296b0c` (+ docs commit for SUMMARY/VERIFICATION)

## Accomplishments

- JSON Schema **oneOf** discriminates `kind: assert` vs `kind: shell` with argv bounds (ASVS note).
- **D-1105** operator path: `KILN_DOGFOOD_WORKSPACE`, workflow id, canonical **`cargo test --workspace --locked`** string for future external CI parity.
- Formatter excludes **`test/generated/**`** so SPEC-02 generated modules do not fail `mix format --check-formatted`.

## Self-Check: PASSED

- `mix test test/kiln/specs/scenario_parser_test.exs test/kiln/specs/scenario_compiler_test.exs test/kiln/workflows/compiler_test.exs test/kiln/dogfood/gb_vertical_slice_spec_test.exs --max-failures=1` → exit 0.

## Manual / operator follow-ups

- **`/workflows` LiveView:** Not verified in this session (no running server). After deploy, confirm **`rust_gb_dogfood_v1`** appears when disk workflows are listed; if UI is DB-only, capture refresh/seed gap in a follow-up plan.
- **Full `mix check`:** Run locally with real `DATABASE_URL` / Postgres (CI parity); agent sandbox lacked DB for full gate.

## Deviations

- Plan text referenced `Enum.at!(argv, 0)`; implementation uses **`[program | args] = argv`** for Elixir 1.19 compatibility.
