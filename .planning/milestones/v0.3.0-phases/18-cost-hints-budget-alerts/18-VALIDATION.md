---
phase: 18
slug: cost-hints-budget-alerts
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-22
---

# Phase 18 — Validation Strategy

> Nyquist validation contract for COST-01 + COST-02 (advisory hints + soft budget alerts).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Phoenix `ConnCase` / `LiveViewCase` where applicable) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/kiln/budget_alerts_test.exs test/kiln_web/live/run_detail_live_test.exs --max-failures 3` (paths finalized when files exist) |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60–120 seconds full suite (project baseline) |

---

## Sampling Rate

- **After every task commit:** `mix format --check-formatted` + targeted `mix test` for files touched by the task
- **After every plan wave:** `mix test` for Phase 18 directories + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** Full `mix test` green
- **Max feedback latency:** 120 seconds for targeted runs

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | COST-02 | T-18-01 | Threshold math uses `Decimal`; no shell | unit | `mix test test/kiln/budget_alerts_test.exs` | ⬜ W0 | ⬜ pending |
| 18-01-02 | 01 | 1 | COST-02 | T-18-02 | New audit kind passes schema + CHECK | integration | `mix test test/kiln/audit/event_kind_test.exs` (or equivalent) | ⬜ W0 | ⬜ pending |
| 18-02-01 | 02 | 2 | COST-02 | T-18-03 | `raise_block` rejects soft reasons | unit | `mix test test/kiln/blockers/reason_test.exs` | ✅ | ⬜ pending |
| 18-02-02 | 02 | 2 | COST-02 | T-18-04 | Desktop stub path audit | integration | `mix test test/kiln/notifications_test.exs` | ✅ | ⬜ pending |
| 18-03-01 | 03 | 2 | COST-01 | — | Disclaimer chips in DOM | LiveView | `mix test test/kiln_web/live/run_detail_live_test.exs` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green*

---

## Wave 0 Requirements

- [ ] `test/kiln/budget_alerts_test.exs` — stubs for threshold ladder (created in Plan 01)
- [ ] Existing infrastructure covers notification + audit integration tests — extend, do not fork

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| macOS desktop banner | COST-02 | OS GUI | Local: trigger crossing in dev with stub run; confirm one notification |

---

## Validation Sign-off

- [ ] All tasks have `<automated>` verify or documented Wave 0 dependency
- [ ] Sampling continuity maintained across waves
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` in frontmatter

**Approval:** pending
