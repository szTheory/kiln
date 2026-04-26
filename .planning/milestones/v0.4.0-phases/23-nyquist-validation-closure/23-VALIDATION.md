---
phase: 23
slug: nyquist-validation-closure
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-23
updated: 2026-04-23
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for Nyquist posture closure and SSOT follow-through.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Repository artifact verification + project gate commands |
| **Config file** | `mix.exs`, `script/precommit.sh`, `script/planning_gates.sh` |
| **Quick run command** | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' "$f" || grep -q '^## Nyquist waiver$' "$f"; done && mix compile --warnings-as-errors` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~120-600 seconds (depends on full repo precommit state) |

---

## Sampling Rate

- **After every task commit:** Run the smallest grep/compile loop that proves each touched `VALIDATION.md` still has an explicit Nyquist posture and that docs-only edits did not break compile sanity.
- **After every plan wave:** Re-run the four-file posture loop and inspect any touched `VERIFICATION.md` / `SUMMARY.md` citations for accuracy.
- **Before the final repo-wide gate in Plan 02 / Task 2:** Run the SSOT grep precheck over `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` so the closure edits fail fast before `bash script/precommit.sh`.
- **Before `$gsd-verify-work`:** `bash script/precommit.sh` must be green if unrelated repo failures are absent, and `23-VERIFICATION.md` must exist.
- **Max feedback latency:** <30 seconds for task-level grep/compile checks; 120-600 seconds for the final `bash script/precommit.sh` closeout gate

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | NYQ-01 | T-23-01 | Each target `VALIDATION.md` ends with explicit posture (`nyquist_compliant: true` or waiver) | doc + grep + compile | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' "$f" || grep -q '^## Nyquist waiver$' "$f"; done && mix compile --warnings-as-errors` | ✅ | ✅ green |
| 23-01-02 | 01 | 1 | NYQ-01 | T-23-01 | `true` closures cite local evidence; waiver uses exact Phase 23 block shape with owner and review-by date | doc + grep | `grep -q '^## Nyquist waiver$' .planning/phases/16-read-only-run-replay/16-VALIDATION.md && grep -q 'Review-by: 2026-05-23' .planning/phases/16-read-only-run-replay/16-VALIDATION.md` | ✅ | ✅ green |
| 23-02-01 | 02 | 2 | NYQ-01 | T-23-02 | `23-VERIFICATION.md` is created in Plan 02 and records the evidence audit before `23-VALIDATION.md` and SSOT flip | doc + grep | `test -f .planning/phases/23-nyquist-validation-closure/23-VERIFICATION.md && grep -q 'NYQ-01' .planning/phases/23-nyquist-validation-closure/23-VERIFICATION.md` | ✅ created in-plan | ✅ green |
| 23-02-02 | 02 | 2 | NYQ-01 | T-23-03 | `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` move only after Phase 23 verification passes, then a fast SSOT grep precheck runs before the repo-wide precommit gate | doc + grep + repo gate | `grep -q '| NYQ-01 | Phase 23 | Complete |' .planning/REQUIREMENTS.md && grep -q '\\[x\\] \\*\\*Phase 23: Nyquist / VALIDATION closure\\*\\*' .planning/ROADMAP.md && grep -q '23-VERIFICATION.md' .planning/REQUIREMENTS.md && bash script/precommit.sh` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Execution Dependencies

- No separate Wave 0 plan is required. `23-VERIFICATION.md` is created inside Plan 02 / Wave 2 before `23-VALIDATION.md`, `.planning/REQUIREMENTS.md`, or `.planning/ROADMAP.md` are updated.
- Optional: add short evidence-anchor notes to touched target `VERIFICATION.md` files only if citations are too implicit.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | NYQ-01 | This phase should resolve posture from existing artifacts, grep checks, and explicit waiver text rather than new runtime manual testing | — |

---

## Validation Sign-Off

- [x] All tasks have grep-verifiable or file-existence verification
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] No missing Wave 0 prerequisites remain; `23-VERIFICATION.md` is created inside Plan 02 before SSOT flips
- [x] No watch-mode flags
- [x] Feedback latency < 600s
- [x] `nyquist_compliant: true` set in frontmatter when phase execution completes honestly
- [x] Final repo gate runs via `bash script/precommit.sh`

**Approval:** signed off 2026-04-23 (`23-VERIFICATION.md` passed)

---

### Threat references (plan-aligned)

| ID | Description |
|----|-------------|
| T-23-01 | A target phase is marked compliant or waived without explicit local evidence or required waiver fields |
| T-23-02 | Phase 23 updates SSOT without its own verification artifact |
| T-23-03 | Requirements and roadmap drift away from the target validation artifacts |
