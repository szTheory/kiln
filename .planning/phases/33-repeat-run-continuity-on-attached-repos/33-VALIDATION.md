---
phase: 33
slug: repeat-run-continuity-on-attached-repos
status: planned
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 33 — Validation Strategy

> Nyquist validation contract for `CONT-01`: one known attached repo can be selected again from `/attach`, one same-repo continuity target is loaded and shown clearly, and the next run still re-checks mutable readiness before launch.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln/attach/continuity_test.exs test/kiln/runs/attached_continuity_test.exs test/kiln_web/live/attach_entry_live_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-120 seconds for focused suites; longer for repo precommit |

## Sampling Rate

- **After Wave 1 continuity-model work:** run continuity domain tests.
- **After Wave 2 `/attach` route-backed UX work:** run LiveView continuity tests.
- **After Wave 3 repeat-run launch wiring:** run continuity domain + run + LiveView suites together.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <30 seconds for focused continuity suites.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 33-01-01 | 01 | 1 | CONT-01 | Recent attached repos and same-repo continuity targets are selected from durable server-owned rows with explicit precedence | unit | `mix test test/kiln/attach/continuity_test.exs` | ⬜ | planned |
| 33-01-02 | 01 | 1 | CONT-01 | Continuity metadata orders “recent repos” without abusing `updated_at` | unit | `mix test test/kiln/attach/continuity_test.exs` | ⬜ | planned |
| 33-02-01 | 02 | 2 | CONT-01 | `/attach` can select a known repo via params, show one continuity card, and expose explicit carry-forward versus blank-start choices | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | planned |
| 33-02-02 | 02 | 2 | CONT-01 | Prefill never crosses repos and carried-forward fields are visible to the operator | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | planned |
| 33-03-01 | 03 | 3 | CONT-01 | Repeat-run start reuses durable repo/request identity but re-runs hydration, safety, and operator preflight before launch | unit | `mix test test/kiln/runs/attached_continuity_test.exs` | ⬜ | planned |
| 33-03-02 | 03 | 3 | CONT-01 | A continuity-selected repo can start blank or continue safely without creating cross-repo leakage | mixed | `mix test test/kiln/attach/continuity_test.exs test/kiln/runs/attached_continuity_test.exs test/kiln_web/live/attach_entry_live_test.exs` | ⬜ | planned |

*Status: ⬜ pending · ✅ existing/planned file · ❌ missing*

## Wave 0 Requirements

- [ ] `test/kiln/attach/continuity_test.exs` — continuity query, precedence, and metadata ordering coverage
- [ ] `test/kiln/runs/attached_continuity_test.exs` — repeat-run start and recheck coverage
- [x] `test/kiln_web/live/attach_entry_live_test.exs` — existing LiveView proof surface to extend for route-backed continuity
- [x] Existing `test/kiln/attach/workspace_manager_test.exs` and `test/kiln/attach/safety_gate_test.exs` remain owning proof layers for hydration and mutable readiness behavior

## Typed Human-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | CONT-01 | Phase 33 should close on deterministic domain and LiveView proof rather than manual repo walkthroughs | — |

## Validation Sign-Off

- [x] All planned tasks have automated verification commands
- [x] Sampling continuity is defined across all three plan waves
- [x] Wave 0 gaps are identified explicitly
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set in frontmatter
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** planned
