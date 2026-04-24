---
phase: 25
slug: local-live-readiness-ssot
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-23
---

# Phase 25 — Validation Strategy

> Nyquist validation contract for `SETUP-01`, `SETUP-02`, and `DOCS-09`: make local live readiness trustworthy, operator-facing, and documented as one canonical path.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` + docs/grep verification |
| **Config file** | `test/test_helper.exs`, `script/precommit.sh`, `README.md`, planning artifacts |
| **Quick run command** | `mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs test/kiln_web/live/settings_live_test.exs test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs -x` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-180 seconds for the focused test set; longer for full precommit |

---

## Sampling Rate

- **After every task commit:** run the smallest command that proves the touched backend/UI/docs contract.
- **After Wave 1:** re-run backend readiness contract tests plus `settings_live_test`.
- **After Wave 2:** re-run the readiness-aware LiveView surface tests.
- **After Wave 3 docs edits:** run the focused test set, then the README/planning grep checks, then `bash script/precommit.sh`.
- **Before `/gsd-verify-work`:** `25-VERIFICATION.md` must exist and `bash script/precommit.sh` must be green unless blocked by unrelated repo failures.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-01 | 01 | 1 | SETUP-01 / SETUP-02 | T-25-01 / T-25-02 / T-25-05 | Fresh or reset readiness state does not read as falsely ready; summary contract stays names-only and action-oriented | backend | `mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs -x` | ✅ | ⬜ pending |
| 25-01-02 | 01 | 1 | SETUP-01 / SETUP-02 | T-25-03 / T-25-04 | `/settings` is the canonical remediation page with stable ids and explicit next actions | LiveView | `mix test test/kiln_web/live/settings_live_test.exs -x` | ✅ | ⬜ pending |
| 25-02-01 | 02 | 2 | SETUP-01 / SETUP-02 | T-25-06 / T-25-07 / T-25-08 | Shell CTA target and `/onboarding` + `/providers` disconnected-state guidance align to `/settings` | LiveView | `mix test test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs -x` | ✅ | ⬜ pending |
| 25-02-02 | 02 | 2 | SETUP-01 / SETUP-02 | T-25-09 / T-25-10 | `/templates` and `/` stay explorable in live mode while honestly routing recovery to `/settings` | LiveView | `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs -x` | ✅ | ⬜ pending |
| 25-03-01 | 03 | 3 | DOCS-09 | T-25-11 / T-25-12 / T-25-13 | README and planning docs describe one canonical local path and do not over-claim Phase 26/27 behavior | doc + grep | `rg -n '/settings|host Phoenix|Compose data plane|Optional: Dev Container' README.md && ! rg -n 'onboarding.*canonical readiness|recommended first live template|first live run proof is complete' README.md` | ✅ | ⬜ pending |
| 25-03-02 | 03 | 3 | SETUP-01 / SETUP-02 / DOCS-09 | T-25-11 / T-25-12 / T-25-13 | Verification artifact cites exact commands, SSOT updates follow passing evidence, and final repo gate runs | focused tests + doc grep + repo gate | `mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs test/kiln_web/live/settings_live_test.exs test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs -x && bash script/precommit.sh` | ⬜ created in-plan | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing readiness tests exist for backend gating and readiness-aware LiveViews.
- [x] Existing docs verification pattern exists in recent phases.
- [x] Existing final repo gate is `bash script/precommit.sh`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | SETUP-01 / SETUP-02 / DOCS-09 | This phase should be fully covered by focused backend/UI tests plus docs/grep checks | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity is defined across all three waves
- [x] Wave 0 prerequisites are satisfied
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set for this plan-time validation contract
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** pending
