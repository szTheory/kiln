# Phase 11: Game Boy emulator dogfood vertical slice - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in **11-CONTEXT.md** — this log preserves alternatives considered.

**Date:** 2026-04-22
**Phase:** 11 — gameboy-dogfood-vertical-slice
**Areas discussed:** Terminal success & observable output; stack (Rust vs Phoenix); workflow YAML; sandbox egress & Rust deps; benchmark template / DX

**Mode:** User selected **all** gray areas and requested parallel subagent research (pros/cons, ecosystem lessons, coherent recommendations). Prior “plans exist” gate treated as **continue and replan** implied by proceeding with full context capture.

---

## 1. Terminal success & observable output (“play the ROM”)

| Option | Description | Selected |
|--------|-------------|----------|
| Headless `cargo test` only | Maximum determinism; weak default “visibility” | Partial — **oracle** |
| WASM / static web + same Rust core | Human play + single implementation truth | ✓ **presentation default** |
| Native SDL primary | Great local dev; poor CI / remote operator default | Dev-only optional |
| Second Phoenix app in dogfood | LiveView in external repo | ✗ default |
| Artifact-backed visibility (JSON, PNG, hashes) | “See it” without GUI | ✓ |

**User's choice (synthesized):** Success includes **seeing** output: reports/artifacts in Kiln, plus a path to **play** a permissive ROM; shift-left ROM smoke; repo is a **benchmark template**.

**Notes:** Research drew on emulator ecosystem patterns (headless harness, golden tests without PNG rot, pin toolchains). WASM/JS must be **glue**, not a second emu core.

---

## 2. Rust vs Phoenix (“wrong direction?”)

| Option | Description | Selected |
|--------|-------------|----------|
| Rust external workspace | `cargo test`, core library, CI oracle | ✓ **default dogfood repo** |
| Phoenix LiveView in **Kiln** | Operator dashboard | ✓ **unchanged** |
| Phoenix in **external** dogfood | Second web app | ✗ **not Phase 11 default** |

**User's choice (synthesized):** Clarified architecture: **Phoenix was never replaced**—spike Rust applies to the **external** Game Boy benchmark repo only.

---

## 3. Workflow YAML template

| Option | Description | Selected |
|--------|-------------|----------|
| Fork DAG, new file + honest tags | Same kinds, new `id` / metadata / model_profile | ✓ |
| Reuse `phoenix_saas_feature` name/profile | Misleading for Rust | ✗ |
| Duplicate stages for “toolchain” | Schema has no per-stage image field | ✗ |

**User's choice (synthesized):** New workflow YAML mirroring **`elixir_phoenix_feature`** structure; **model_profile** for economics, not language; acknowledge **scenario → external shell** may need product work.

---

## 4. Sandbox / crates.io / network

| Option | Description | Selected |
|--------|-------------|----------|
| Host prefetch + vendor / offline sandbox | Matches SAND-02, deterministic | ✓ **default** |
| Allowlist crates.io in sandbox | DX short-term, policy/ACL debt | ✗ default |
| Full DTU mock registry | High engineering cost | Deferred |

**User's choice (synthesized):** **Two-phase** dependency materialization on **trusted host**, **`cargo test --locked`**, **`--offline`** when vendor present; defer DTU registry mock unless scoped.

---

## 5. Single-command parity & caps

**User's choice (synthesized):** One canonical command string shared across Kiln spec, external CI, and docs; tune caps for cold **Rust** compile so timeouts read as **budget** outcomes.

---

## Claude's Discretion

- Exact workflow id string; whether `play/` builds every run or only verify; initial cap numbers; SDL helper optional vs documented only.

## Deferred Ideas

- DTU-as-crates.io for its own sake.
- Dogfood Phoenix app for integration-only future phase.
- Allowlisted sandbox egress as explicit non-default escape hatch.
