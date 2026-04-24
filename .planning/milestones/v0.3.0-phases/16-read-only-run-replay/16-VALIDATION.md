---
phase: 16
slug: read-only-run-replay
status: complete
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
updated: 2026-04-23
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19+) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `mix precommit` |
| **Estimated runtime** | ~2–8 minutes (project-dependent) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors` and any **new** test file for that task via `mix test path/to/file.exs`
- **After every plan wave:** Run `mix test test/kiln_web/live/run_replay_live_test.exs test/kiln/audit_replay_test.exs` (paths per actual artifacts from plans)
- **Before `/gsd-verify-work`:** `mix precommit` must exit 0
- **Max feedback latency:** 600 seconds (CI upper bound)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 1 | REPL-01 | T-16-01 | Router-only change; no user HTML | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 16-01-02 | 01 | 1 | REPL-01 | T-16-02 | UUID gate matches detail | liveview | `mix test test/kiln_web/live/run_replay_live_test.exs` | ❌ W0→✅ | ⬜ pending |
| 16-02-01 | 02 | 1 | REPL-01 | T-16-03 | Read-only SELECT queries | unit | `mix test test/kiln/audit_replay_test.exs` | ❌ W0→✅ | ⬜ pending |
| 16-03-01 | 03 | 2 | REPL-01 | T-16-04 | No mutations in LiveView | liveview | `mix test test/kiln_web/live/run_replay_live_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] ExUnit + Phoenix.LiveViewTest — existing
- [x] LazyHTML — existing

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Range slider debounce feel | REPL-01 | Pointer timing | Open `/runs/:run_id/replay`, drag scrubber, confirm ≤1 patch burst per drag |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 600s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** signed off 2026-04-23 (`16-VERIFICATION.md`, `16-01-SUMMARY.md`, `16-02-SUMMARY.md`, `16-03-SUMMARY.md`; closed with Nyquist waiver per D-2313 and D-2321)

## Nyquist waiver

- Scope: Nyquist compliance for this VALIDATION.md artifact only
- Reason: Residual manual-only `Range slider debounce feel` remains operator-judgment UX signal rather than a runtime correctness gap
- Owner: @jon
- Review-by: 2026-05-23
- Exit criteria: Replace the manual-only scrubber-feel caveat with an automated or clearly non-blocking observation that no longer conflicts with `nyquist_compliant: true`
- Operator impact: Replay routing, pagination, mutation safety, and live-tail behavior are verified; only scrubber feel still depends on human perception today
- Evidence: `16-VERIFICATION.md`, `16-01-SUMMARY.md`, `16-02-SUMMARY.md`, `16-03-SUMMARY.md`
