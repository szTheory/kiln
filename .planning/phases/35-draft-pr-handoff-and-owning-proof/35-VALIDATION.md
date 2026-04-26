---
phase: 35
slug: draft-pr-handoff-and-owning-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 35 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with LiveViewTest and Oban/DataCase support |
| **Config file** | `mix.exs` plus standard `test/` support paths |
| **Quick run command** | `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/kiln/attach/brownfield_preflight_test.exs test/kiln/attach/continuity_test.exs test/mix/tasks/kiln.attach.prove_test.exs` |
| **Full suite command** | `MIX_ENV=test mix kiln.attach.prove` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/mix/tasks/kiln.attach.prove_test.exs`
- **After every plan wave:** Run `MIX_ENV=test mix kiln.attach.prove`
- **Before phase closure:** Full automated suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 35-01-01 | 01 | 1 | TRUST-04 | T-35-01 | Frozen draft PR body shows scoped summary, acceptance criteria, conditional out-of-scope, explicit verification citations, useful branch facts, and omits raw internal ids | unit/integration | `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/integration/github_delivery_test.exs` | ✅ | ⬜ pending |
| 35-02-01 | 02 | 2 | UAT-06 | T-35-02 | Owning proof command remains singular and delegates the locked proof layers needed for continuity plus representative refusal or warning coverage | task/unit/live | `MIX_ENV=test mix test test/mix/tasks/kiln.attach.prove_test.exs test/kiln/attach/continuity_test.exs test/kiln/attach/brownfield_preflight_test.exs test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/kiln/attach/delivery_test.exs` — lock the final PR-body contract, including omission of raw `attached_repo_id`
- [ ] `test/mix/tasks/kiln.attach.prove_test.exs` — update the delegated proof-layer list when Phase 35 changes the owning proof contract
- [ ] `test/kiln/attach/continuity_test.exs` and `test/kiln/attach/brownfield_preflight_test.exs` — include them in the owning proof path to make the continuity and representative warning/refusal claims literal

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
