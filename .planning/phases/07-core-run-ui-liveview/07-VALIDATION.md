---
phase: 07
slug: core-run-ui-liveview
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest + LazyHTML |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln_web/ --max-failures=5` |
| **Full suite command** | `mix check` |
| **Estimated runtime** | ~3–8 minutes (full `mix check` with Dialyzer) |

---

## Sampling Rate

- **After every task commit:** Run the `<automated>` command from the active task
- **After every plan wave:** `mix test test/kiln_web/ --max-failures=5`
- **Before `/gsd-verify-work`:** `mix check` must be green
- **Max feedback latency:** 300 seconds (CI ceiling)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | UI-06 | T-07-01 | No secrets in layout; fonts from trusted URLs only | LV test | `mix test test/kiln_web/live/run_board_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | UI-06 | T-07-02 | Nav links are path helpers only | LV test | `mix test test/kiln_web/live/run_board_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 2 | UI-01 | T-07-03 | PubSub payload is Run struct only — no env | LV test | `mix test test/kiln_web/live/run_board_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 2 | UI-01 | T-07-04 | `handle_event` calls `allow?/1` | LV test | `mix test test/kiln_web/live/run_board_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-03-01 | 03 | 3 | UI-02 | T-07-05 | Invalid `stage_id` in URL does not leak other runs’ data | LV test | `mix test test/kiln_web/live/run_detail_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-03-02 | 03 | 3 | UI-02 | T-07-06 | Diff body streamed from CAS — not logged at `:info` | LV test | `mix test test/kiln_web/live/run_detail_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-04-01 | 04 | 3 | UI-03 | T-07-07 | No POST routes mutate YAML | LV test | `mix test test/kiln_web/live/workflow_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-05-01 | 05 | 3 | UI-04 | T-07-08 | SQL aggregates only `stage_runs` — no raw user SQL | unit | `mix test test/kiln/cost_rollups_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 07-06-01 | 06 | 3 | UI-05 | T-07-09 | Audit LiveView has no `handle_event` that INSERTs audit | LV test | `mix test test/kiln_web/live/audit_live_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] ExUnit, LiveViewTest, Finch-less repo tests — existing Kiln test stack.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| Board p95 latency & heap under 10+ runs | UI-01 / ROADMAP SC1 | Needs sustained load + browser | Local k6 or manual spawn 10 runs, observe LiveDashboard memory; document baseline in SUMMARY |
| `stream_async/4` YAML > 1MB | UI-02 / UI-SPEC | Large fixture binary | Generate large YAML in dev, confirm first paint and cancellation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter after execution

**Approval:** pending
