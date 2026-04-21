---
phase: 05
slug: spec-verification-bounded-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (Elixir / ExUnit / Mix).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.x) |
| **Config file** | `test/test_helper.exs`, `mix.exs` |
| **Quick run command** | `mix test test/kiln/specs/ --max-failures=1` (after plan 02 lands paths) |
| **Full suite command** | `mix check` (includes credo, dialyzer, xref, scenario suite once wired in plan 06) |
| **Estimated runtime** | ~120–300 seconds full `mix check` (local; CI may vary) |

---

## Sampling Rate

- **After every task commit:** Run the `<automated>` command on the touched test file(s) from that task’s `<verify>` block.
- **After every plan wave:** Run the wave’s combined `mix test` paths listed in the Per-Task map below.
- **Before `/gsd-verify-work`:** `mix check` must be green.
- **Max feedback latency:** 300 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SPEC-01 | T-05-01 | revision bytes tied to `scenario_manifest_sha256` | unit | `mix test test/kiln/specs/` | ⬜ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | SPEC-02 | T-05-02 | IR JSV-validated before codegen | unit | `mix test test/kiln/specs/scenarios_test.exs` | ⬜ W0 | ⬜ pending |
| 05-03-01 | 03 | 2 | SPEC-03, ORCH-05 | T-05-03 | LLM JSON cannot override machine verdict | unit | `mix test test/kiln/agents/roles/qa_verifier_test.exs` | ⬜ W0 | ⬜ pending |
| 05-04-01 | 04 | 3 | SPEC-04 | T-05-04 | `kiln_app` cannot `SELECT holdout_scenarios` | integration | `mix test test/kiln/specs/holdout_priv_test.exs` | ⬜ W0 | ⬜ pending |
| 05-05-01 | 05 | 3 | ORCH-06, OBS-04 | T-05-05 | cap/stuck decisions only inside `Transitions` tx | unit | `mix test test/kiln/runs/transitions_test.exs test/kiln/policies/stuck_detector_test.exs` | ⬜ W0 | ⬜ pending |
| 05-06-01 | 06 | 4 | UAT-01, UAT-02 | T-05-06 | `mix check_no_manual_qa_gates` passes | mix task | `mix check_no_manual_qa_gates` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] ExUnit paths above exist after their plans land (paths are targets — Wave 0 is “first failing test” per plan TDD tasks).
- [ ] `mix check` includes scenario + holdout slice after plan 06 updates `.check.exs`.

*Wave 0 is satisfied when each plan’s first commit introduces the declared test file(s) and they compile.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | — | All behaviors target automated commands above | — |

*All phase behaviors are designed for automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
