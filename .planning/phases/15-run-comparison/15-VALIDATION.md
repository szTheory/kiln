---
phase: 15
slug: run-comparison
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-22
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for **PARA-02** (run comparison). Wave 0 satisfied by existing **ExUnit + Phoenix.LiveViewTest + LazyHTML**.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19+) |
| **Config file** | `test/test_helper.exs`, `test/support/conn_case.ex`, `test/support/data_case.ex` |
| **Quick run command** | `mix test test/kiln_web/live/run_compare_live_test.exs --max-failures 1` |
| **Full suite command** | `mix precommit` |
| **Estimated runtime** | ~30–120 seconds full suite (project-dependent) |

---

## Sampling Rate

- **After every task commit** touching compare LiveView: `mix test test/kiln_web/live/run_compare_live_test.exs --max-failures 1`
- **After every task commit** touching `Kiln.Runs` compare API: `mix test test/kiln/runs/run_compare_test.exs --max-failures 1` (path as implemented)
- **Before `/gsd-verify-work`:** `mix precommit` green
- **Max feedback latency:** 120s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | PARA-02 | T-15-01 | Read-only route registration | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ |
| 15-01-02 | 01 | 1 | PARA-02 | T-15-02 | UUID gate mirrors detail | live | `mix test test/kiln_web/live/run_compare_live_test.exs` | ✅ | ⬜ |
| 15-02-01 | 02 | 1 | PARA-02 | T-15-03 | No blob load in compare queries | unit | `mix test test/kiln/runs/run_compare_test.exs` | ✅ | ⬜ |
| 15-03-01 | 03 | 2 | PARA-02 | — | Stable selectors | live | `mix test test/kiln_web/live/run_compare_live_test.exs` | ✅ | ⬜ |

---

## Wave 0 Requirements

- [x] ExUnit + LiveViewTest — existing
- [x] `DataCase` / factories for runs — existing (`test/support/`)

**Note:** New test files are created in plans **01–03**; until then, “file exists” checks are planning placeholders.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual sticky header at `lg` | PARA-02 | Browser layout | Open `/runs/compare?…` in desktop width; confirm identity band sticks while scrolling spine. |

---

## Validation Sign-off

- [ ] All tasks have `<automated>` verify or compile/live test
- [ ] Sampling continuity maintained across waves
- [ ] No watch-mode flags in verify steps
- [ ] `mix precommit` green before phase verify-work

**Approval:** pending
