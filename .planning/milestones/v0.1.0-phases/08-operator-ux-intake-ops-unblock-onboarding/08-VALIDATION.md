---
phase: 08
slug: operator-ux-intake-ops-unblock-onboarding
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for Phase 8 (Operator UX). Elixir / ExUnit / LiveViewTest.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest + LazyHTML |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test --max-failures=1` on touched `test/**/*_test.exs` |
| **Full suite command** | `mix precommit` |
| **Estimated runtime** | ~3–8 minutes (full); < 60s incremental per plan |

---

## Sampling Rate

- **After every task commit:** `mix test` on files listed in that plan's `<verification>`
- **After every plan wave:** `mix test test/kiln_web/live/` subset for Wave N + `mix compile --warnings-as-errors`
- **Before `/gsd-verify-work`:** `mix precommit` green
- **Max feedback latency:** 120s for incremental LiveView suites

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | INTAKE-01, INTAKE-02 | T-08-01 | No plaintext secrets in draft rows | unit | `mix test test/kiln/specs/` | ❌ W0 | ⬜ |
| 08-02-01 | 02 | 2 | INTAKE-01 | T-08-02 | URL injection-safe GitHub client | unit | `mix test test/kiln/specs/github_issue_importer_test.exs` | ❌ W0 | ⬜ |
| 08-03-01 | 03 | 3 | INTAKE-01, INTAKE-02 | T-08-03 | CSRF + `allow?` on events | LV | `mix test test/kiln_web/live/inbox_live_test.exs` | ❌ W0 | ⬜ |
| 08-04-01 | 04 | 4 | INTAKE-03 | T-08-04 | Idempotent follow-up intent | integration | `mix test test/kiln/specs/follow_up_test.exs` | ❌ W0 | ⬜ |
| 08-05-01 | 05 | 2 | OPS-01 | T-08-05 | Poll-only; no credential echo | LV | `mix test test/kiln_web/live/provider_health_live_test.exs` | ❌ W0 | ⬜ |
| 08-06-01 | 06 | 3 | OPS-04 | T-08-06 | Read-only cost aggregates | LV | `mix test test/kiln_web/live/cost_live_test.exs` | ✅ | ⬜ |
| 08-07-01 | 07 | 3 | OPS-05 | T-08-07 | Redacted zip bytes | unit | `mix test test/kiln/diagnostics/snapshot_test.exs` | ❌ W0 | ⬜ |
| 08-08-01 | 08 | 4 | BLOCK-02 | T-08-08 | Typed playbook only; auth on retry | LV | `mix test test/kiln_web/live/run_detail_live_test.exs` | ✅ | ⬜ |
| 08-09-01 | 09 | 5 | BLOCK-04 | T-08-09 | Plug + domain double-gate | LV+unit | `mix test test/kiln_web/live/onboarding_live_test.exs` | ❌ W0 | ⬜ |
| 08-10-01 | 10 | 5 | UI-07, UI-08, UI-09 | T-08-10 | Bounded PubSub topics | LV | `mix test test/kiln_web/live/run_board_live_test.exs` + new ticker/header tests | ✅ | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [ ] New test modules stubbed when plan 01 creates `test/kiln/specs/` paths
- [ ] `Mox` definitions for `gh`/HTTP if importer tests need determinism

*Wave 0 completes when first migration lands and `mix ecto.migrate` succeeds in dev.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| Real GitHub token fetch | INTAKE-01(c) | Secrets + network | Dev: import known public issue; confirm inbox row |
| Live provider outage color flip | OPS-01 | Needs real 429/5xx | Staging: force adapter error; card red ≤ one poll |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity maintained across waves
- [ ] No watch-mode flags in commands
- [ ] `nyquist_compliant: true` set after first green full suite

**Approval:** pending
