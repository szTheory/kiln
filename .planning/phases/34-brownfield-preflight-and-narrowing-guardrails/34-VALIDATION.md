---
phase: 34
slug: brownfield-preflight-and-narrowing-guardrails
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 34 — Validation Strategy

> Nyquist validation contract for `SAFE-01` and `SAFE-02`: attached brownfield work is checked for deterministic safety first, then surfaced through typed same-repo preflight findings and narrowing guidance before coding begins.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln/attach/brownfield_preflight_test.exs test/kiln/runs/attached_request_start_test.exs test/kiln_web/live/attach_entry_live_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-120 seconds for focused suites; longer for full precommit |

## Sampling Rate

- **After Wave 1 advisory-boundary work:** run `mix test test/kiln/attach/brownfield_preflight_test.exs`.
- **After Wave 2 heuristic/start-seam work:** run `mix test test/kiln/attach/brownfield_preflight_test.exs test/kiln/runs/attached_request_start_test.exs`.
- **After Wave 3 `/attach` UX work:** run the full focused suite.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <45 seconds for focused suites.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-01-01 | 01 | 1 | SAFE-01 / SAFE-02 | T-34-01 / T-34-02 | Advisory preflight emits typed findings and preserves warning-only launchability without widening `SafetyGate`. | unit | `mix test test/kiln/attach/brownfield_preflight_test.exs` | ❌ W0 | ⬜ pending |
| 34-01-02 | 01 | 1 | SAFE-01 / SAFE-02 | T-34-03 | Fatal, warning, and info findings carry structured evidence and next actions for later UI rendering. | unit | `mix test test/kiln/attach/brownfield_preflight_test.exs` | ❌ W0 | ⬜ pending |
| 34-02-01 | 02 | 2 | SAFE-01 | T-34-04 / T-34-05 | Same-repo overlap, open-PR lane checks, and degraded live lookup stay bounded, explainable, and non-silent. | unit | `mix test test/kiln/attach/brownfield_preflight_test.exs` | ❌ W0 | ⬜ pending |
| 34-02-02 | 02 | 2 | SAFE-01 / SAFE-02 | T-34-06 | Attach-side advisory evaluation shapes start preparation without changing `Runs.start_for_attached_request/3` deterministic blocked/error authority. | unit | `mix test test/kiln/runs/attached_request_start_test.exs` | ✅ | ⬜ pending |
| 34-03-01 | 03 | 3 | SAFE-01 / SAFE-02 | T-34-07 / T-34-09 | `/attach` renders blocked vs warning states distinctly with evidence, inspect actions, and narrowing guidance. | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ⬜ pending |
| 34-03-02 | 03 | 3 | SAFE-02 | T-34-08 | Warning acceptance narrows or edits the request, then final launch still flows through the existing backend start seam. | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ existing/planned file · ❌ missing Wave 0 file · ⚠️ flaky*

## Wave 0 Requirements

- [ ] `test/kiln/attach/brownfield_preflight_test.exs` — typed report contract, same-repo overlap findings, degraded PR lookup behavior, and breadth-warning coverage
- [x] `test/kiln/runs/attached_request_start_test.exs` — existing deterministic start-authority proof surface to extend
- [x] `test/kiln_web/live/attach_entry_live_test.exs` — existing `/attach` proof surface to extend for warning/narrowing UX
- [x] Existing `test/kiln/attach/safety_gate_test.exs` remains the owning proof layer for deterministic hard blockers

## Typed Human-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | SAFE-01 / SAFE-02 | Phase 34 should close on deterministic domain and LiveView proof rather than manual brownfield walkthroughs | — |

## Validation Sign-Off

- [x] All planned tasks have automated verification commands
- [x] Sampling continuity is defined across all three plan waves
- [x] Wave 0 gaps are identified explicitly
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set in frontmatter
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** planned
