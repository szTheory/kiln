---
phase: 2
slug: workflow-engine-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> The planner fills the Per-Task Verification Map from its PLAN.md tasks.
> The Validation Architecture section in 02-RESEARCH.md is the source for test recipes.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (shipped with OTP 28.1), ex_machina for factories, Mox for behaviour mocks, StreamData for property tests, Oban.Testing for worker tests |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `MIX_ENV=test mix test --exclude slow --exclude integration --max-failures 3` |
| **Full suite command** | `mix check` (runs compile-warnings-as-errors, credo strict, dialyzer, deps.audit, sobelow, full test suite, + the P2 custom checks `check_no_signature_block` + `check_bounded_contexts`) |
| **Estimated runtime** | ~20 s quick (deps/compile hot) · ~4 min full `mix check` on cold dialyzer cache |

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test {focused_test_file}` on the test file for the changed code
- **After every plan wave:** Run `MIX_ENV=test mix test` (whole suite, no check runners)
- **Before `/gsd-verify-work`:** `mix check` must be green (includes dialyzer, credo, sobelow, deps.audit, full test suite, and the P2 custom checks)
- **Max feedback latency:** 30 s after task commit; 4 min before phase verification

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| *(populated by planner once PLAN.md files are written — one row per task. Each task maps to at least one automated test command covering at least one phase requirement.)* | | | | | | | | | |

---

## Wave 0 Requirements

Test-infrastructure scaffolding the planner MUST create (or confirm exists) before any Wave 1 task runs:

- [ ] `test/support/fixtures/workflows/minimal_two_stage.yaml` — 2-stage pass-through fixture (D-64)
- [ ] `test/support/fixtures/workflows/cyclic.yaml` — 3-stage cycle for `Kiln.Workflows.Graph` toposort failure tests
- [ ] `test/support/fixtures/workflows/missing_entry.yaml` — all stages have `depends_on` non-empty; `Kiln.Workflows.load!/1` must reject
- [ ] `test/support/fixtures/workflows/forward_edge_on_failure.yaml` — `on_failure.to` pointing at a descendant, rejected per D-62 validator 4
- [ ] `test/support/fixtures/workflows/signature_populated.yaml` — `signature: {...}` non-null; `mix check_no_signature_block` must fail when this is staged outside `test/support/fixtures/`
- [ ] `test/support/factories/workflow_factory.ex` + `run_factory.ex` + `stage_run_factory.ex` + `artifact_factory.ex` (ex_machina)
- [ ] `test/support/oban_case.ex` — shared ExUnit template wiring `Oban.Testing` with the 6 queue names, `async: false` for workers touching `external_operations`
- [ ] `test/support/rehydration_case.ex` — template for crash/recovery tests that explicitly stops the `RunSupervisor` subtree, keeps Postgres, and asserts `RunDirector` rehydrates
- [ ] `test/kiln/artifacts/cas_test_helper.ex` — tmp-dir setup + teardown for CAS writes (per-test `priv/artifacts/cas/` override)

Wave 0 ensures every subsequent task has the fixtures, factories, and case templates it needs on line 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `priv/artifacts/cas/` directory-fanout performance on 1M+ blobs | P19 / D-77 | 1M-blob synthetic test would take hours and pollute fs | Deferred to Phase 5 load-test harness; v1 ships the structure and a 10k-blob micro-benchmark only |
| Operator-visible `illegal_transition` error clarity | D-89 | Wording validated by human readability, not automation | Reviewer reads `IllegalTransitionError.message/1` output from an iex shell against 3 representative illegal transitions; confirms `from=... to=... allowed_from_<from>=[...]` is present and clear |

All other Phase 2 behaviors have automated verification. The BEAM-kill-and-recover scenario (ORCH-03/ORCH-04) is automated via `test/integration/run_rehydration_test.exs` using explicit `Supervisor.stop/3` + fresh `RunDirector` start (simulates restart without actually killing the test VM).

---

## Validation Sign-Off

- [ ] Every PLAN.md task has an `acceptance_criteria` block with at least one grep-verifiable command or file-contents assertion
- [ ] Every phase requirement ID (ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07) has at least one automated test asserting it
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification (property + integration tests interleaved with unit tests)
- [ ] Wave 0 fixtures land before any Wave 1 planner/coder task depends on them
- [ ] No watch-mode flags in `mix test` commands (sampling is ephemeral, not continuous)
- [ ] Feedback latency < 30 s on quick, < 4 min on `mix check`
- [ ] `mix check_no_signature_block` ships and is invoked from `mix check`
- [ ] `mix check_bounded_contexts` updated to admit the 13th context (`Kiln.Artifacts`) per D-97
- [ ] `nyquist_compliant: true` set in frontmatter once every row above is ticked

**Approval:** pending
