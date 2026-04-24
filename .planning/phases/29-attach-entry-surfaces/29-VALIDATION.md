---
phase: 29
slug: attach-entry-surfaces
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 29 — Validation Strategy

> Nyquist validation contract for `ATTACH-01`: make attach-to-existing a first-class, honest entry path from onboarding and the start surface without regressing the validated template-first journey.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` + Playwright route/onboarding smoke |
| **Config file** | `test/test_helper.exs`, `.check.exs`, Playwright config already in repo |
| **Quick run command** | `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/route_smoke_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-180 seconds for focused LiveView/browser checks; longer for full precommit |

---

## Sampling Rate

- **After Wave 1 structural work:** run the focused LiveView suite for `/attach`, onboarding, templates, and route smoke.
- **After Wave 2 copy/browser alignment:** rerun the focused LiveView suite, then `npx playwright test test/e2e/tests/onboarding.spec.ts test/e2e/tests/routes.spec.ts`.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <30 seconds for focused LiveView checks; browser and precommit may take longer.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 29-01-01 | 01 | 1 | ATTACH-01 | T-29-01 / T-29-03 / T-29-04 | `/attach` mounts under the default shell with required ids and honest Phase 29-only guidance | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/route_smoke_test.exs` | ❌ W0 | ⬜ pending |
| 29-01-02 | 01 | 1 | ATTACH-01 | T-29-01 / T-29-02 / T-29-04 | `/onboarding` and `/templates` expose attach as an additive route-backed branch while preserving template-first seams and `hello-kiln` emphasis | LiveView | `mix test test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs` | ✅ | ⬜ pending |
| 29-02-01 | 02 | 2 | ATTACH-01 | T-29-06 / T-29-07 | `/onboarding`, `/templates`, and `/attach` use one coherent template-vs-attach copy contract with explicit next-phase honesty | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs` | ❌ W0 | ⬜ pending |
| 29-02-02 | 02 | 2 | ATTACH-01 | T-29-08 | Browser proofs cover the onboarding attach CTA and `/attach` route matrix without widening into Phase 30/31 repo mechanics | browser + repo gate | `npx playwright test test/e2e/tests/onboarding.spec.ts test/e2e/tests/routes.spec.ts && bash script/precommit.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Phase context, UI contract, research, and pattern map exist in `.planning/phases/29-attach-entry-surfaces/`.
- [x] Existing LiveView tests already cover onboarding, templates, and route smoke seams that Phase 29 extends.
- [x] Existing Playwright route and onboarding specs exist and can absorb the attach branch proof.
- [ ] `test/kiln_web/live/attach_entry_live_test.exs` must be added as the owning focused proof for the new route.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | ATTACH-01 | Phase 29 should be fully covered by focused LiveView checks, route smoke, browser route/onboarding smoke, and the repo precommit gate | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity is defined across both plan waves
- [x] Wave 0 prerequisites are identified
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set for this plan-time validation contract
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** pending
