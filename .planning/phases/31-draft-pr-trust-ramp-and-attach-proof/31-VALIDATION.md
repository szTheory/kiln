---
phase: 31
slug: draft-pr-trust-ramp-and-attach-proof
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-24
---

# Phase 31 — Validation Strategy

> Nyquist validation contract for `TRUST-01`, `TRUST-03`, `GIT-05`, and `UAT-05`: carry one ready attached repo through a frozen run-scoped branch and draft PR, then close the milestone with one explicit owning proof command and aligned planning artifacts.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + `Phoenix.LiveViewTest` |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test test/kiln/attach/delivery_test.exs test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs test/kiln_web/live/attach_entry_live_test.exs` |
| **Full suite command** | `MIX_ENV=test mix kiln.attach.prove` |
| **Estimated runtime** | ~30-180 seconds for focused suites; longer for the owning proof command plus precommit |

---

## Sampling Rate

- **After Wave 1 delivery work:** run focused attach delivery and worker tests.
- **After Wave 2 proof / SSOT work:** rerun the owning attach proof command and planning-artifact grep checks.
- **Before phase closure:** `bash script/precommit.sh` must be green.
- **Max feedback latency:** <30 seconds for focused attach suites.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 31-01-01 | 01 | 1 | TRUST-01 / GIT-05 | T-31-01 / T-31-02 | One ready attached repo freezes exactly one deterministic `kiln/attach/<intent-slug>-r<short_run_id>` branch and reuses it on retry | unit | `mix test test/kiln/attach/delivery_test.exs` | ✅ | ✅ green |
| 31-01-02 | 01 | 1 | TRUST-01 / GIT-05 | T-31-03 | Push and draft PR payloads reuse the existing durable worker seams with frozen `head`, `base`, and `draft: true` attrs | unit | `mix test test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs` | ✅ | ✅ green |
| 31-02-01 | 02 | 2 | UAT-05 | T-31-05 / T-31-06 | `mix kiln.attach.prove` delegates the attach happy path, refusal-path set, and focused `/attach` proof in a stable order | unit + mixed | `mix test test/mix/tasks/kiln.attach.prove_test.exs && MIX_ENV=test mix kiln.attach.prove` | ✅ | ✅ green |
| 31-02-02 | 02 | 2 | UAT-05 / TRUST-03 | T-31-07 | Planning artifacts cite the same owning proof command and preserve single-repo, draft-PR-first scope without implying an approval gate | docs | `rg -n "mix kiln\\.attach\\.prove|TRUST-01|TRUST-03|GIT-05|UAT-05|draft PR|single-repo" .planning/PROJECT.md .planning/REQUIREMENTS.md .planning/ROADMAP.md .planning/STATE.md .planning/phases/31-draft-pr-trust-ramp-and-attach-proof/31-VERIFICATION.md` | ✅ | ✅ green |
| 31-02-03 | 02 | 2 | TRUST-03 carry-forward | T-31-06 | `/attach` continues to render ready vs blocked states honestly while LiveView proof remains supportive rather than primary | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/kiln/attach/delivery_test.exs` — delivery-orchestrator coverage for branch freezing and payload assembly
- [x] Expanded `test/integration/github_delivery_test.exs` — hermetic attach happy path covering frozen branch naming, push orchestration, and draft PR creation
- [x] `lib/mix/tasks/kiln.attach.prove.ex` — owning attach proof command
- [x] `test/mix/tasks/kiln.attach.prove_test.exs` — proof-command contract coverage
- [x] Existing `test/kiln/attach/safety_gate_test.exs` retains refusal-path ownership from Phase 30
- [x] Existing `test/kiln_web/live/attach_entry_live_test.exs` retains focused attach-surface truth-state coverage

---

## Typed Human-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None planned | TRUST-01 / TRUST-03 / GIT-05 / UAT-05 | Phase 31 should close on deterministic worker/domain tests, focused LiveView proof, the owning proof task, and the repo precommit gate rather than manual attach walkthroughs | — |

---

## Validation Sign-Off

- [x] All tasks have automated verification commands
- [x] Sampling continuity is defined across both plan waves
- [x] Wave 0 gaps are identified explicitly
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` is set in frontmatter
- [x] Final repo gate is `bash script/precommit.sh`

**Approval:** complete
