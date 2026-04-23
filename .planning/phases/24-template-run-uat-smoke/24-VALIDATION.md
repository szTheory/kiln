---
phase: 24
slug: template-run-uat-smoke
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-23
---

# Phase 24 — Validation Strategy

> Nyquist validation contract for `UAT-03`: a narrow, deterministic Phoenix LiveView regression for the template -> run operator journey.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/kiln_web/live/templates_live_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-180 seconds for the focused test, longer for full precommit |

---

## Sampling Rate

- **After every task commit:** `mix test test/kiln_web/live/templates_live_test.exs`
- **After verification artifact + SSOT edits:** re-run the focused test and grep the exact evidence lines in `24-VERIFICATION.md`, `.planning/REQUIREMENTS.md`, and `.planning/ROADMAP.md`
- **Before `/gsd-verify-work`:** `bash script/precommit.sh`
- **Max feedback latency:** <30 seconds for the focused LiveView proof; longer for the final repo gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-01 | 01 | 1 | UAT-03 | T-24-01 / T-24-02 | Test setup satisfies onboarding readiness, proves `#templates-success-panel`, and follows navigation to `#run-detail` without widening into run internals | LiveView | `mix test test/kiln_web/live/templates_live_test.exs` | ✅ | ⬜ pending |
| 24-01-02 | 01 | 1 | UAT-03 | T-24-03 / T-24-04 | Verification cites the exact focused command, keeps the claim narrow, flips SSOT only after success, then runs the final repo gate | doc + grep + repo gate | `mix test test/kiln_web/live/templates_live_test.exs && grep -q 'targeted evidence for the template -> run journey' .planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md && grep -q 'does not replace the broader merge-authority suite from Phase 22' .planning/phases/24-template-run-uat-smoke/24-VERIFICATION.md && grep -q '| UAT-03 | Phase 24 | Complete |' .planning/REQUIREMENTS.md && grep -q '\[x\] \*\*Phase 24: Template → run UAT smoke\*\*' .planning/ROADMAP.md && bash script/precommit.sh` | ⬜ created in-plan | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing LiveView test infrastructure already exists in `test/kiln_web/live/templates_live_test.exs`.
- [x] Existing destination-shell analog exists in `test/kiln_web/live/run_detail_live_test.exs`.
- [x] Existing verification-writing analog exists in `.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | UAT-03 | The phase should be fully covered by focused LiveView proof plus document/grep checks | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity maintained across the phase
- [x] Wave 0 covers all needed analogs and infrastructure
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set for this plan-time validation contract
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** pending
