# Game Boy vertical slice — Kiln dogfood (Phase 11)

Kiln-side spec stub for the **external Rust Game Boy emulation slice**: planning, workflow binding, and **argv-only shell** scenarios that prove the scenario oracle bridge in CI **before** the throwaway clone exists.

**ROM policy:** open / test ROMs only — see `.planning/phases/11-gameboy-dogfood-vertical-slice/GB-SPIKE.md`.

**Workflow:** `priv/workflows/rust_gb_dogfood_v1.yaml` (`rust_gb_dogfood_v1`).

**External workspace (D-1105):** set `KILN_DOGFOOD_WORKSPACE` to the absolute path of the operator-owned clone. Scenario `argv` will move from `mix …` (in-repo oracle) to `cargo test …` with `cwd` under that workspace once the Rust tree is linked; the canonical external parity command is documented in `README.md`.

```kiln-scenario
scenarios:
  - id: mix_oracle_smoke
    description: Mix is on PATH — smoke oracle before external repo exists
    steps:
      - kind: shell
        argv: ["mix", "--version"]
        cwd: "."

  - id: compile_gate
    description: Project compiles — gate for Kiln tree health
    steps:
      - kind: shell
        argv: ["mix", "compile"]
        cwd: "."

  - id: scenario_runner_gate
    description: Scenario parser tests still pass — regression on IR + fences
    steps:
      - kind: shell
        argv: ["mix", "test", "test/kiln/specs/scenario_parser_test.exs", "--max-failures", "1"]
        cwd: "."
```
