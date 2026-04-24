---
phase: 20
slug: phase-19-verification-planning-ssot
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 20 — Validation Strategy

> Documentation and SSOT alignment; verification is **command-backed** doc gates, not new application modules.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) — invoked only to **re-confirm** Phase 19 paths documented in `19-VERIFICATION.md` |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | See `19-VERIFICATION.md` **Automated** block after Plan 01 |
| **Estimated runtime** | ~60–180 seconds for scoped tests |

---

## Sampling Rate

- **After Plan 01:** Run automated block from `19-VERIFICATION.md`; set `status: passed` only on exit 0.
- **After Plan 02:** No code execution — grep frontmatter + markdown table checks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | SSOT | — | N/A | docs + mix | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 20-01-02 | 01 | 1 | SSOT | — | N/A | mix | Scoped lines from `19-VERIFICATION.md` | ✅ | ⬜ pending |
| 20-02-01 | 02 | 1 | SSOT | — | N/A | grep | `grep requirements-completed` on each `19-*-SUMMARY.md` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [x] **Existing infrastructure** — no new test files; Wave 0 satisfied by repo ExUnit + Mix.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | — |

---

## Validation Sign-Off

- [ ] Plan 01 automated commands green
- [ ] `19-VERIFICATION.md` frontmatter `status: passed`
- [ ] Plan 02 SUMMARY + REQUIREMENTS + ROADMAP grep checks pass

**Approval:** pending
