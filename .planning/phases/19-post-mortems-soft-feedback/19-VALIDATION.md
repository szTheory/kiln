---
phase: 19
slug: post-mortems-soft-feedback
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (SELF-01, FEEDBACK-01).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `test/test_helper.exs` + `config/test.exs` |
| **Quick run command** | `mix test path/to/file.exs --max-failures 1` |
| **Full suite command** | `mix test test/kiln/audit/ test/kiln/runs/ test/kiln/stages/ test/kiln_web/live/run_detail_live_test.exs --max-failures 5` |
| **Estimated runtime** | ~60–120 seconds (project-dependent) |

---

## Sampling Rate

- **After every task commit:** Run the **quick command** for files touched by that task (see Per-Task map).
- **After every plan wave:** Run the **full suite command** scoped to Phase 19 modules.
- **Before `/gsd-verify-work`:** `mix test` green for listed paths + `mix compile --warnings-as-errors`.
- **Max feedback latency:** 120 seconds for full scoped suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | FEEDBACK-01 / SELF-01 prep | T-19-01 | No secrets in audit payloads | unit | `mix test test/kiln/audit/event_kind_test.exs --max-failures 1` | ✅ | ⬜ pending |
| 19-01-02 | 01 | 1 | FEEDBACK-01 / SELF-01 prep | T-19-02 | CHECK from `EventKind` only | integration | `MIX_ENV=test mix ecto.migrate --quiet` | ✅ | ⬜ pending |
| 19-02-01 | 02 | 1 | SELF-01 | T-19-03 | FK to runs, no orphan writes | unit | `mix test test/kiln/runs/post_mortem_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 19-03-01 | 02 | 2 | SELF-01 | T-19-04 | Async job, no PII in JSON | unit | `mix test test/kiln/oban/post_mortem_materialize_worker_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 19-04-01 | 04 | 2 | FEEDBACK-01 | T-19-05 | Rate limit + reject oversize | unit | `mix test test/kiln/operator_nudges_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 19-05-01 | 05 | 3 | SELF-01 + FEEDBACK-01 | T-19-06 | UI separation from BLOCK | LiveView | `mix test test/kiln_web/live/run_detail_live_test.exs --max-failures 1` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Existing infrastructure covers all phase requirements** — ExUnit + Ecto Sandbox + LiveViewTest already present; new test files created by plans 02–05.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | All behaviors mapped to automated commands above. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s for scoped suite
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes

**Approval:** pending
