# Phase 11 — Technical Research

**Phase:** 11 — Game Boy emulator dogfood vertical slice  
**Question:** What do we need to know to **plan** this phase well?  
**Status:** Ready for planning

## Summary

Phase 11 is Kiln’s first **external** workspace dogfood: a **Rust** Game Boy emulation **slice** with **open test ROMs only**, driven by the same **run FSM** (`planning → … → merge`) as `elixir_phoenix_feature`, but with **honest** workflow metadata (`model_profile`, `tags`) and **sandbox/toolchain** policy aligned to **no default crates.io egress** (host prefetch / `cargo vendor` / offline test per **11-CONTEXT** D-1104).

The largest **product** gap is **UAT-01 alignment**: today’s **scenario IR v1** only defines `kind: assert` with `expect` in `true`/`false`, and `ScenarioCompiler` emits trivial `assert true/false` tests — **not** shell oracles. A **small, typed extension** (e.g. `kind: shell` + `argv[]` + optional `cwd_env`) is the lowest-friction bridge to “Given/When/Then → `cargo test …`” without pretending YAML alone satisfies BDD.

## Workflow packaging

- **Template:** `priv/workflows/elixir_phoenix_feature.yaml` — same stage **kinds** and DAG; new file `priv/workflows/rust_gb_dogfood_v1.yaml` (working name; executor may adjust `id` to match filename stem).
- **`model_profile`:** Prefer **`elixir_lib`** or **`bugfix_critical`** over `phoenix_saas_feature` unless economics deliberately choose the Phoenix preset (**D-1103b**).
- **Loader:** `Kiln.Workflows` resolves `priv/workflows/<workflow_id>.yaml` from `run.workflow_id`; no code registry change beyond adding the file + `mix test` / compiler coverage.

## Sandbox + Rust

- **Image:** Default Kiln sandbox image may be Elixir-centric; **GB-SPIKE** calls out verifying `ContainerSpec` / image path for `rustc` + `cargo`. Plan must grep `docker_driver` / workflow fixtures and either document **stage image override** in YAML metadata (if supported) or a **follow-up** image publish task.
- **Egress:** D-1104 — **two-phase**: host-trusted `cargo fetch` / `cargo vendor` with caps and logs; stage runs `cargo test --locked` and **`--offline`** when vendor tree is present in the mounted workspace.
- **Caps:** First compile can exceed naive `max_stage_duration_seconds`; tune per **ORCH-06** so timeouts read as budget outcomes.

## Scenario / BDD bridge (critical)

| Approach | Fit | Risk |
|----------|-----|------|
| **A. Extend scenario IR + compiler** (`shell` step → generated `System.cmd`) | Matches “deterministic oracle” narrative; keeps `mix check` as umbrella | Must constrain **argv** (no shell interpolation); document **`KILN_DOGFOOD_WORKSPACE`** or equivalent |
| **B. Manual / doc-only oracle** | Fast | Violates **UAT-01** spirit for Phase 11 |
| **C. Separate non-ExUnit runner** | Flexible | Duplicates CI entrypoints; harder to gate in `mix check` |

**Recommendation:** **A** — minimal schema + compiler extension + tests; three scenarios in the dogfood spec mapping to three `cargo test` invocations (or one workspace command + scoped tests).

## GitHub / workspace

- **Throwaway repo** + scoped token per **GB-SPIKE**; `Kiln.GitHub` / `PushWorker` already validates `workspace_dir` against `:github_workspace_root` — plan tasks should reference **existing** env and **not** log remote URLs at `:info`.

## Legal / ROMs

- Only **permissively licensed** or **in-repo generated** test ROMs; never retail ROMs (**GB-SPIKE**, **PROJECT.md**).

---

## Validation Architecture

Phase 11 validation is **two-tier**:

1. **Kiln host (always):** `mix test` for changed modules (`ScenarioParser`, `ScenarioCompiler`, `Workflows` compiler tests, any new tests under `test/kiln/specs/`). After each task commit touching Elixir, run the **narrowest** test file first, then `mix test test/kiln/workflows/compiler_test.exs` when workflow YAML changes.
2. **External dogfood workspace (CI + Kiln verify stage):** Canonical command string documented in **both** the external repo’s CI and Kiln spec (**D-1105**), e.g. `cargo test --workspace --locked` from repo root with `RUSTFLAGS`/`CARGO_NET_OFFLINE` as decided in implementation.

**Sampling:**

- After **schema/compiler** tasks: `mix test test/kiln/specs/scenario_parser_test.exs test/kiln/specs/scenario_compiler_test.exs`
- After **workflow file** task: workflow compile tests + grep that new `id` appears in snapshot or loader test if present
- **Before phase sign-off:** `mix check` (project standard)

**Nyquist / Dimension 8:** No three consecutive tasks without an automated `mix test` (or documented `cargo test` for tasks that only touch external repo docs — prefer touching Kiln tests in the same commit to preserve sampling continuity).

---

## RESEARCH COMPLETE

Next: executable plans in `11-01-PLAN.md` (+ `11-VALIDATION.md`).
