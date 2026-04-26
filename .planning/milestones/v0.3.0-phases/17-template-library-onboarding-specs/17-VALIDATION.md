---
phase: 17
slug: template-library-onboarding-specs
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-22
updated: 2026-04-23
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (Kiln / ExUnit).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Phoenix `mix test`) |
| **Config file** | `test/test_helper.exs`, `mix.exs` aliases |
| **Quick run command** | `mix test test/path/to/file_test.exs` |
| **Full suite command** | `mix precommit` (project meta-runner per `AGENTS.md`) |
| **Estimated runtime** | ~2–8 minutes (full precommit; incremental tests faster) |

---

## Sampling Rate

- **After every task commit:** `mix test` on files touched by the task (or smallest relevant directory)
- **After every plan wave:** `mix test` for all new/changed test modules in that wave
- **Before `/gsd-verify-work`:** `mix precommit` green
- **Max feedback latency:** ~600s CI budget (local incremental much lower)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | WFE-01 | Path traversal / T-17-01 | `template_id` resolved from manifest only | unit + LV | `mix test test/kiln/templates_manifest_test.exs` | ⬜ W0 | ⬜ pending |
| TBD | 01 | 1 | ONB-01 | — | ≥3 templates ship with metadata | mix task or test | `mix templates.verify` (once implemented) | ⬜ W0 | ⬜ pending |
| TBD | 02+ | 1–2 | WFE-01 | CSRF / T-17-02 | LiveView mutate events only via `phx-submit` / CSRF pipeline | LV test | `mix test test/kiln_web/live/templates_live_test.exs` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] ExUnit + Phoenix test stack already present — **no new framework**
- [ ] `mix templates.verify` (or dedicated test module) — **stubs / first implementation** in plan 01 if not pre-existing

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Release tarball reads `priv/templates/*` | WFE-01 | Distillery/Release path sanity | Build or run `_build/prod/rel/.../bin/kiln` smoke if project adds release job |

*If none beyond above: "Most behaviors have automated verification."*

---

## Validation Sign-Off

- [x] All tasks have grep- or test-verifiable acceptance criteria
- [x] Sampling continuity: no long stretches without `mix test`
- [x] `nyquist_compliant: true` set in frontmatter when execution completes

**Approval:** signed off 2026-04-23 (`17-VERIFICATION.md`, `17-01-SUMMARY.md`, `17-03-SUMMARY.md` per D-2319)
