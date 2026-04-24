---
phase: 32
slug: pr-sized-attached-repo-intake
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-24
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/kiln/attach/intake_test.exs test/kiln/specs/attach_request_draft_test.exs test/kiln/runs/attached_request_start_test.exs test/integration/attached_repo_intake_test.exs test/kiln_web/live/attach_entry_live_test.exs` |
| **Full suite command** | `bash script/precommit.sh` |
| **Estimated runtime** | ~15-45 seconds per task-local verify |

---

## Sampling Rate

- **After every task commit:** Run the active task's automated command from the Per-Task Verification Map
- **After every plan wave:** Run `bash script/precommit.sh`
- **Before phase closure:** Full automated suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-01-01 | 01 | 1 | WORK-01 | T-32-01 / T-32-02 / T-32-03 | Attach intake rejects vague requests, normalizes list fields, and never trusts client-supplied repo metadata. | unit | `mix test test/kiln/attach/intake_test.exs` | ✅ | ✅ green |
| 32-01-02 | 01 | 1 | WORK-01 | T-32-04 / — | Draft and promoted spec persistence preserve one durable attached-repo link and one immutable bounded-request snapshot. | unit | `mix test test/kiln/specs/attach_request_draft_test.exs` | ✅ | ✅ green |
| 32-02-01 | 02 | 2 | WORK-01 | T-32-05 / T-32-06 | Attached-request start persists explicit run linkage and reuses the normal `Kiln.Runs` launch authority. | unit | `mix test test/kiln/runs/attached_request_start_test.exs` | ✅ | ✅ green |
| 32-02-02 | 02 | 2 | WORK-01 | T-32-07 / — | One promoted attached request can create one durable attached run with exact repo/spec/revision linkage. | integration | `mix test test/integration/attached_repo_intake_test.exs` | ✅ | ✅ green |
| 32-03-01 | 03 | 3 | WORK-01 | T-32-08 / T-32-09 / T-32-10 | `/attach` renders the bounded-request form after ready state, keeps invalid submissions on-form with deterministic ids, and only renders success after the attached run starts. | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ✅ green |
| 32-03-02 | 03 | 3 | WORK-01 | — | Validation metadata cites the actual proof surface and keeps phase gates aligned with shipped tests. | docs | `rg -n "test/kiln/attach/intake_test\\.exs|test/kiln/specs/attach_request_draft_test\\.exs|test/kiln/runs/attached_request_start_test\\.exs|test/integration/attached_repo_intake_test\\.exs|test/kiln_web/live/attach_entry_live_test\\.exs|wave_0_complete: true|bash script/precommit\\.sh" .planning/phases/32-pr-sized-attached-repo-intake/32-VALIDATION.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/kiln/attach/intake_test.exs` — bounded attach-intake orchestration and idempotency
- [x] `test/kiln/specs/attach_request_draft_test.exs` — attach-linked draft/spec persistence coverage
- [x] `test/kiln/runs/attached_request_start_test.exs` — attach-aware run creation and blocked-start coverage
- [x] `test/integration/attached_repo_intake_test.exs` — draft -> promotion -> attached run launch coverage
- [x] `test/kiln_web/live/attach_entry_live_test.exs` — ready-state form ids, invalid-submit proof, and attached run start success coverage
- [x] Existing infrastructure covers the LiveView test layer; no framework install needed

---

## Typed Human-Only Verifications

All phase behaviors should be automatable with ExUnit and LiveView tests; no human-only verification is required for closure.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all planned proof files
- [x] No watch-mode flags
- [x] Feedback latency < 45s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
