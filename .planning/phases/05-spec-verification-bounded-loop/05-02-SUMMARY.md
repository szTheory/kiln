---
phase: 05-spec-verification-bounded-loop
plan: "02"
status: complete
completed: "2026-04-21"
---

## Outcome

SPEC-02: `kiln-scenario` fenced markdown → YAML → JSV **scenario_ir_v1**; deterministic ExUnit codegen under `test/generated/kiln_scenarios/<uuid>/scenarios_test.exs`; manifest sha256 persisted via `Kiln.Specs.compile_revision!/1`.

## Key files

- `priv/jsv/scenario_ir_v1.json`
- `lib/kiln/specs/scenario_parser.ex` — `parse_document/1`
- `lib/kiln/specs/scenario_compiler.ex` — `compile/2`, `manifest_sha256/1`
- `lib/kiln/specs.ex` — `compile_revision!/1`
- `test/fixtures/specs/minimal_spec.md`
- `test/kiln/specs/scenario_{parser,compiler}_test.exs`
- `.gitignore` — `/test/generated/`

## Verification

- `mix test test/kiln/specs/scenario_parser_test.exs test/kiln/specs/scenario_compiler_test.exs`
- Compiler tests shell out to `mix test <generated file>` (documented in this summary).

## Self-Check: PASSED

## Deviations

- Codegen only allows closed `expect` values `"true"` / `"false"` mapped to `assert true` / `assert false` — arbitrary expressions are intentionally not emitted (T-05-02).
