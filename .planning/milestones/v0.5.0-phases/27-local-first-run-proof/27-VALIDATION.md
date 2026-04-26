---
phase: 27
slug: local-first-run-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/mix/tasks/kiln.first_run.prove_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest task-local automated command from the Per-Task Verification Map
- **After every plan wave:** Run `mix kiln.first_run.prove`
- **Before phase closure:** Full automated suite must be green via `bash script/precommit.sh`
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | UAT-04 | T-27-01 | Proof command delegates only `integration.first_run` then the focused LiveView file list in that order | unit | `mix test test/mix/tasks/kiln.first_run.prove_test.exs` | ❌ W0 | ⬜ pending |
| 27-01-02 | 01 | 1 | UAT-04 | T-27-03 | Setup-ready story stays anchored on stable `/settings`, `/templates`, and `/runs/:id` seams | liveview | `mix test test/kiln_web/live/settings_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs` | ✅ | ⬜ pending |
| 27-01-03 | 01 | 1 | UAT-04 | T-27-02 | Verification artifact cites only the owning Mix command and transparently lists delegated layers | docs | `rg -n "mix kiln\\.first_run\\.prove|mix integration\\.first_run|templates_live_test\\.exs|run_detail_live_test\\.exs" .planning/phases/27-local-first-run-proof/27-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 27-01-04 | 01 | 1 | UAT-04 | T-27-04 | Real local topology proof still succeeds under the documented `.env` + Compose + host Phoenix contract | integration | `mix kiln.first_run.prove` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/mix/tasks/kiln.first_run.prove_test.exs` — task-level delegation lock for the owning proof command
- [ ] `.planning/phases/27-local-first-run-proof/27-VERIFICATION.md` — exact top-level command citation with delegated-layer transparency
- [ ] `lib/mix/tasks/kiln.first_run.prove.ex` — proof-owning task implementation

---

## Typed Human-Only Verifications

All phase behaviors have automated verification; no human UAT required for closure.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
