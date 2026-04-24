---
phase: 28
slug: first-run-proof-runtime-closure
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 28 — Validation Strategy

> Nyquist validation contract for `UAT-04`: close the real runtime-proof gap, rerun the owning command under the intended runtime role, and reconcile the repository truth surfaces from fresh evidence.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + role-scoped Repo assertions + shell proof + planning-artifact grep verification |
| **Config file** | `config/runtime.exs`, `test/integration/first_run.sh`, `.planning/phases/28-first-run-proof-runtime-closure/28-VERIFICATION.md` |
| **Quick run command** | `mix test test/kiln/repo/migrations/oban_runtime_privileges_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~15-180 seconds for focused checks; longer for full precommit |

---

## Sampling Rate

- **After Task 1 code changes:** run the role-scoped migration regression, then rerun `mix integration.first_run` so the delegated proof path is verified before SSOT edits begin.
- **After Task 2 artifact edits:** rerun `mix kiln.first_run.prove`, then grep the exact closure strings in `28-VERIFICATION.md`, `27-VERIFICATION.md`, `27-01-SUMMARY.md`, `ROADMAP.md`, and `REQUIREMENTS.md`.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <30 seconds for the focused migration regression; longer for the delegated integration/proof reruns.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 1 | UAT-04 | T-28-01 / T-28-02 | `kiln_app` can access the Oban relations required for app boot, and the delegated integration proof explicitly boots under that runtime role and still reaches `/health` | migration + integration | `mix test test/kiln/repo/migrations/oban_runtime_privileges_test.exs && mix integration.first_run` | ❌ W0 | ⬜ pending |
| 28-01-02 | 01 | 1 | UAT-04 | T-28-01 / T-28-02 | The delegated integration proof explicitly boots under the restricted runtime role and still reaches `/health` | integration | `mix integration.first_run` | ✅ | ⬜ pending |
| 28-01-03 | 01 | 1 | UAT-04 | T-28-03 / T-28-04 | The top-level proof command passes end to end and the closure artifacts agree on the final `UAT-04` truth, with Phase 27 verification explicitly marked non-owning | proof + docs | `mix kiln.first_run.prove && rg -n "status:|superseded|historical|mix kiln\\.first_run\\.prove|/health|UAT-04|Phase 28" .planning/phases/28-first-run-proof-runtime-closure/28-VERIFICATION.md .planning/phases/27-local-first-run-proof/27-VERIFICATION.md .planning/phases/27-local-first-run-proof/27-01-SUMMARY.md .planning/ROADMAP.md .planning/REQUIREMENTS.md && bash script/precommit.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing proof owner already exists at `lib/mix/tasks/kiln.first_run.prove.ex`.
- [x] Existing delegated integration proof already exists at `test/integration/first_run.sh`.
- [x] Existing contradictory artifacts are present and named by `.planning/milestones/v0.5.0-MILESTONE-AUDIT.md`.
- [x] Phase research exists at `.planning/phases/28-first-run-proof-runtime-closure/28-RESEARCH.md`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | UAT-04 | This phase should be fully covered by role-scoped regression, delegated integration proof, top-level proof rerun, and artifact grep checks | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity is defined across the phase
- [x] Wave 0 prerequisites are satisfied
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set for this plan-time validation contract
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** pending
