---
phase: 06
slug: github-integration
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19+) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln/git/ test/kiln/github/ --max-failures=1` |
| **Full suite command** | `mix check` |
| **Estimated runtime** | ~2–5 minutes (full `mix check`) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for paths listed in the active PLAN.md verification block
- **After every plan wave:** Run `mix test test/kiln/git/ test/kiln/github/ test/kiln/runs/` for Phase 6 touched trees
- **Before `/gsd-verify-work`:** `mix check` must be green
- **Max feedback latency:** 300 seconds (CI ceiling)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | GIT-01 | T-06-01 | No secrets in git stderr logs; cmd argv redacted in telemetry | unit | `mix test test/kiln/git_test.exs --max-failures=1` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | GIT-01 | T-06-02 | CAS precondition rejects ambiguous push | unit | `mix test test/kiln/git_test.exs --max-failures=1` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 1 | GIT-02 | T-06-03 | PR intent payload has no raw tokens | unit | `mix test test/kiln/github/github_cli_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 1 | BLOCK-01 | T-06-04 | `:gh_auth_expired` / `:gh_permissions_insufficient` classification | unit | `mix test test/kiln/github/github_cli_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 2 | GIT-01 | T-06-05 | Worker completes `external_operations` atomically | unit | `mix test test/kiln/github/push_worker_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-03-02 | 03 | 2 | GIT-02 | T-06-06 | OpenPRWorker idempotent on replay | unit | `mix test test/kiln/github/open_pr_worker_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-03-03 | 03 | 2 | GIT-03 | T-06-07 | CheckPoller schedules without exhausting max_attempts for pending CI | unit | `mix test test/kiln/github/check_poller_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-04-01 | 04 | 3 | GIT-03 | T-06-08 | Merge predicate persists snapshot for UI phase | unit | `mix test test/kiln/github/merge_predicate_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |
| 06-04-02 | 04 | 3 | ORCH-07 | T-06-09 | Mid-crash replay does not double-complete intent | integration | `mix test test/integration/github_delivery_test.exs --max-failures=1` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure: ExUnit, Oban test helpers, `Kiln.ExternalOperations` tests — covers baseline.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| Live `git push` to origin | GIT-01 | Needs real remote + credentials | Clone scratch repo, run push worker once with `KILN_TEST_GITHUB=1`, verify single commit on remote |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
