---
phase: 30
slug: attach-workspace-hydration-and-safety-gates
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 30 — Validation Strategy

> Nyquist validation contract for `ATTACH-02`, `ATTACH-03`, and `TRUST-02`: resolve one attach source into one safe writable workspace and refuse unsafe repo states before any later coding run mutates git state.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln/attach test/kiln_web/live/attach_entry_live_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~30-180 seconds for focused suites; longer for full precommit |

---

## Sampling Rate

- **After Wave 1 source-resolution work:** run focused attach domain tests plus `/attach` LiveView tests.
- **After Wave 2 workspace hydration work:** rerun attach domain tests plus any repo-workspace integration tests.
- **After Wave 3 refusal gates:** rerun attach domain tests, `/attach` LiveView tests, and any GitHub prerequisite tests.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <30 seconds for focused attach suites.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | ATTACH-02 | T-30-01 / T-30-02 | Local path and GitHub URL inputs normalize into one typed attach-source contract with exact validation failures | unit | `mix test test/kiln/attach/source_test.exs` | ❌ W0 | ⬜ pending |
| 30-01-02 | 01 | 1 | ATTACH-02 | T-30-01 / T-30-03 | `/attach` submits a real form and renders resolved-source or validation state without mutating git state | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ⬜ pending |
| 30-02-01 | 02 | 2 | ATTACH-03 | T-30-04 / T-30-05 | Kiln creates or reuses one writable workspace under a managed root and persists repo metadata needed for later runs | unit + integration | `mix test test/kiln/attach/workspace_manager_test.exs test/integration/attach_workspace_hydration_test.exs` | ❌ W0 | ⬜ pending |
| 30-02-02 | 02 | 2 | ATTACH-03 | T-30-04 | Reuse logic is deterministic and does not escape the configured workspace root | unit | `mix test test/kiln/attach/workspace_manager_test.exs` | ❌ W0 | ⬜ pending |
| 30-03-01 | 03 | 3 | TRUST-02 | T-30-06 / T-30-07 | Dirty worktrees, detached HEADs, and missing GitHub prerequisites are refused with typed reasons before later run execution | unit | `mix test test/kiln/attach/safety_gate_test.exs` | ❌ W0 | ⬜ pending |
| 30-03-02 | 03 | 3 | TRUST-02 | T-30-06 / T-30-08 | `/attach` renders explicit remediation guidance for refusal cases and does not offer a false-ready success path | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kiln/attach/source_test.exs` — source normalization / validation regression coverage
- [ ] `test/kiln/attach/workspace_manager_test.exs` — workspace root, hydrate, and reuse tests
- [ ] `test/kiln/attach/safety_gate_test.exs` — dirty / detached / prerequisite refusal coverage
- [ ] `test/integration/attach_workspace_hydration_test.exs` — one higher-level attach workspace proof

---

## Typed Human-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | ATTACH-02 / ATTACH-03 / TRUST-02 | The phase should be closed by deterministic attach-domain tests, LiveView proof, and repo gates rather than manual operator walkthroughs | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity is defined across all three plans
- [x] Wave 0 gaps are identified explicitly
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set in frontmatter
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** pending
