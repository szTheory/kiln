---
phase: 23
slug: nyquist-validation-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for Nyquist posture closure and SSOT follow-through.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Repository artifact verification + project gate commands |
| **Config file** | `mix.exs`, `script/precommit.sh`, `script/planning_gates.sh` |
| **Quick run command** | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' "$f" || grep -q '^## Nyquist waiver$' "$f"; done` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~120-600 seconds (depends on full repo precommit state) |

---

## Sampling Rate

- **After every task commit:** Run the smallest grep loop that proves each touched `VALIDATION.md` still has an explicit Nyquist posture.
- **After every plan wave:** Re-run the four-file posture loop and inspect any touched `VERIFICATION.md` / `SUMMARY.md` citations for accuracy.
- **Before `$gsd-verify-work`:** `bash script/precommit.sh` must be green if unrelated repo failures are absent, and `23-VERIFICATION.md` must exist.
- **Max feedback latency:** 600 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | NYQ-01 | T-23-01 | Each target `VALIDATION.md` ends with explicit posture (`nyquist_compliant: true` or waiver) | doc + grep | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' "$f" || grep -q '^## Nyquist waiver$' "$f"; done` | ✅ | ⬜ pending |
| 23-01-02 | 01 | 1 | NYQ-01 | T-23-01 | `true` closures cite local evidence; waiver uses exact Phase 23 block shape with owner and review-by date | doc + grep | `grep -q '^## Nyquist waiver$' .planning/phases/16-read-only-run-replay/16-VALIDATION.md && grep -q 'Review-by: 2026-05-23' .planning/phases/16-read-only-run-replay/16-VALIDATION.md` | ✅ | ⬜ pending |
| 23-02-01 | 02 | 2 | NYQ-01 | T-23-02 | `23-VERIFICATION.md` records the evidence audit before SSOT flips | doc + grep | `test -f .planning/phases/23-nyquist-validation-closure/23-VERIFICATION.md && grep -q 'NYQ-01' .planning/phases/23-nyquist-validation-closure/23-VERIFICATION.md` | ❌ W0 | ⬜ pending |
| 23-03-01 | 03 | 3 | NYQ-01 | T-23-03 | `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` move only after Phase 23 verification passes | doc + grep | `grep -q '| NYQ-01 | Phase 23 | Complete |' .planning/REQUIREMENTS.md && grep -q 'Phase 23: Nyquist / VALIDATION closure' .planning/ROADMAP.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.planning/phases/23-nyquist-validation-closure/23-VERIFICATION.md` — execution must add the verification artifact before SSOT flips.
- [ ] Optional: add short evidence-anchor notes to touched target `VERIFICATION.md` files only if citations are too implicit.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | NYQ-01 | This phase should resolve posture from existing artifacts, grep checks, and explicit waiver text rather than new runtime manual testing | — |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable or file-existence verification
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers the missing `23-VERIFICATION.md` artifact
- [ ] No watch-mode flags
- [ ] Feedback latency < 600s
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes honestly

**Approval:** pending

---

### Threat references (plan-aligned)

| ID | Description |
|----|-------------|
| T-23-01 | A target phase is marked compliant or waived without explicit local evidence or required waiver fields |
| T-23-02 | Phase 23 updates SSOT without its own verification artifact |
| T-23-03 | Requirements and roadmap drift away from the target validation artifacts |
