# Spike: Game Boy emulator as first external dogfood spec

**Phase slot:** Backlog **999.2** (feeds **Phase 11**).  
**Date:** 2026-04-22

## Why Game Boy (not Star Fox / SNES)

- **Deterministic acceptance:** CPU/timer/PPU behaviour is well documented; many **open test ROMs** (Blargg, Mooneye, etc.) yield clear pass/fail.
- **Smaller surface than SNES:** No Super FX, no mode-7 stress; faster iteration for Kiln’s first external repo.
- **Star Fox-class** targets are a **later** stress test (coprocessor, real-time constraints, asset pipeline).

## Language and sandbox toolchain

| Option | Pros | Cons |
|--------|------|------|
| **Rust** (`cargo test`, `clippy`) | Strong test harness; fits existing “library + tests” mental model | Sandbox image must include stable `rustc` + `cargo`; larger container pull |
| **C + make** | Minimal deps; easy `cc` in container | Less ergonomic BDD unless wrapped in a tiny test runner |
| **Zig** | Single toolchain | Less familiar default in presets; validate `Kiln.ModelRegistry` / workflow presets |

**Recommendation:** Prefer **Rust** for the vertical slice unless the default Kiln sandbox image is Elixir-only — then either extend the stage **image** in workflow YAML (per SAND-01) or add a **v0.2 plan task** to publish a `kiln/sandbox-rust` base.

**Action for Phase 11:** Confirm which `ContainerSpec` / image resolver path Kiln uses today for non-Elixir projects (grep `sandbox` workflow fixtures).

## Git and GitHub policy

- Use a **throwaway repository** under the operator’s account (e.g. `github.com/<you>/kiln-dogfood-gb`); do **not** use `szTheory/kiln` as the generated workspace.
- **Minimum:** personal fork + `GH_TOKEN` with `repo` scope for push/PR if the workflow includes PR stages.
- **Optional:** local bare remote for loop-back testing without GitHub (skips GIT-02/03 until enabled).

## Minimal vertical slice (acceptance bar)

Ship a repo that:

1. Parses a minimal boot header / executes a **tight subset** of opcodes (enough to run one Blargg-style test or a self-contained “fake ROM” test harness).
2. **`cargo test`** (or chosen runner) passes in CI **without** any copyrighted retail ROM.
3. At least **one** BDD scenario in the Kiln spec maps 1:1 to a **deterministic** shell command (e.g. `cargo test --test cpu_smoke`).

**Explicit non-goals for slice v1:** audio perfection, full PPU game compatibility, RTC, link cable.

## Test ROMs and legal

- Use only **permissively licensed** or **original test** ROMs committed to the dogfood repo, or generated binaries from assembly in-repo.
- **Never** commit Nintendo retail ROMs or rip copyrighted assets into Kiln fixtures.

## Workflow and model preset

- Reuse an existing workflow shape close to “library + verify” (see `priv/workflows/*.yaml` in Kiln).
- Map **Planner/Coder/Verifier** roles to models via an existing **model profile** (`rust`-friendly profile if present, else `bugfix_critical` / custom YAML overrides) — validate in Phase 11 that `BudgetGuard` caps are set for first live token spend.

## Open questions (resolve in `/gsd-discuss-phase 11`)

1. Does the operator require **PR merge** as success, or is **verifying** state enough for the first dogfood?
2. Which **workflow YAML** is the template fork (name + path in Kiln repo)?
3. DTU / egress: does the emulator build need **crates.io** during the stage? If yes, sandbox egress policy must allow only that path (DTU mock vs real registry) per product policy.

## References

- `.planning/research/LOCAL-DX-AUDIT.md` — host vs Compose layout  
- `.planning/PROJECT.md` — **DOGFOOD-01**  
- Mooneye / Blargg test ROM documentation (external; do not vendor without license check)
