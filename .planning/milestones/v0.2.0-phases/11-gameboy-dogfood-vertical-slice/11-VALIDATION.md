---
phase: 11
slug: gameboy-dogfood-vertical-slice
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Kiln) + `cargo test` (external dogfood workspace) |
| **Config file** | `mix.exs` / `test/test_helper.exs` (Kiln); `Cargo.toml` (external) |
| **Quick run command** | `mix test test/kiln/specs/scenario_parser_test.exs test/kiln/specs/scenario_compiler_test.exs --max-failures=1` |
| **Full suite command** | `mix check` |
| **Estimated runtime** | ~120–600 seconds (host; first compile in sandbox higher — budgeted separately) |

## Sampling Rate

- **After every task commit:** Run the **quick run command** when the task touched `lib/kiln/specs/` or `priv/jsv/scenario_ir_v1.json`; otherwise run the narrowest `mix test path/to/file.exs` listed in that task’s `<verify>`.
- **After every plan wave:** Run **`mix check`** before declaring the wave done.
- **Before `/gsd-verify-work`:** `mix check` green; external workspace command (documented in plan) green in CI parity.
- **Max feedback latency:** 600 seconds for full `mix check` (operator machine baseline per Phase 10).

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | DOGFOOD-01 | T-11-01 | Workflow IDs non-deceptive | unit | `mix test test/kiln/workflows/compiler_test.exs --max-failures=1` | ⬜ W0 | ⬜ pending |
| 11-01-02 | 01 | 1 | UAT-01 | T-11-02 | No arbitrary shell; argv-only | unit | `mix test test/kiln/specs/scenario_parser_test.exs test/kiln/specs/scenario_compiler_test.exs` | ⬜ W0 | ⬜ pending |
| 11-01-03 | 01 | 1 | UAT-02 | — | Typed caps / no secret logging | unit | `mix test` scoped files TBD in plan | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `priv/jsv/scenario_ir_v1.json` — extended step schema documented in RESEARCH
- [ ] `test/kiln/specs/scenario_compiler_test.exs` — covers new `shell` step emission
- [ ] `priv/workflows/rust_gb_dogfood_v1.yaml` — loads via existing workflow loader tests or new minimal test

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| LiveView start-run against real throwaway GitHub remote | DOGFOOD-01 | Needs `GH_TOKEN` + network | Follow **11-01-PLAN** UAT checklist after automated gates green |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency within budget above
- [ ] `nyquist_compliant: true` set in frontmatter when execution proves sampling

**Approval:** pending
