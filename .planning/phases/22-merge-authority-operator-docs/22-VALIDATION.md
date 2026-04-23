---
phase: 22
slug: merge-authority-operator-docs
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 22 — Validation Strategy

> Documentation phase: merge-authority matrix in `.planning/PROJECT.md` + README pointer. No new test framework.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — markdown / grep / manual diff review |
| **Config file** | n/a |
| **Quick run command** | `rg -n "Merge authority" .planning/PROJECT.md README.md` |
| **Full suite command** | same + confirm `.github/workflows/ci.yml` job names cited in PROJECT still exist |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick `rg` / `grep` checks from the plan’s `<acceptance_criteria>`
- **After plan wave 1:** Full suite command (CI name cross-check)
- **Before `/gsd-verify-work`:** Executor SUMMARY cites grep results
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | DOCS-08 | T-22-01 / — | No misleading “local = merge” claims | grep | `grep -q '12-01-SUMMARY' .planning/PROJECT.md` | ✅ | ⬜ pending |
| 22-01-02 | 01 | 1 | DOCS-08 | T-22-02 / — | README links SSOT; no duplicate authoritative table | grep | `grep -qE '\\.planning/PROJECT\\.md#merge-authority' README.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements (no new test stubs).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Readability / tone | DOCS-08 | Brand + calm-operator voice | Skim new sections: no “you must green locally to merge” unless branch protection actually enforces it |

---

## Validation Sign-Off

- [ ] All tasks have grep-verifiable acceptance criteria
- [ ] Sampling continuity: doc tasks each have automated grep
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter after execute-phase

**Approval:** pending
