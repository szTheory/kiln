---
phase: 14
slug: fair-parallel-runs
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-22
updated: 2026-04-23
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for PARA-01 (fair parallel runs).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `config/test.exs` (Oban `testing: :manual`) |
| **Quick run command** | `mix test test/kiln/runs/<module>_test.exs --max-failures 1` |
| **Full suite command** | `mix check` |
| **Estimated runtime** | ~120–300 seconds (full `mix check` — project default) |

---

## Sampling Rate

- **After every task commit:** Run the **narrowest** automated command listed on that task’s row below.
- **After every plan wave:** `mix test test/kiln/runs/` paths touched by that wave + `mix compile --warnings-as-errors` if Elixir files changed.
- **Before `/gsd-verify-work`:** `mix check` must be green.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|---------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | PARA-01 | T-14-01 | No secrets in telemetry metadata; no `run_id` metric labels | unit | `mix test test/kiln/runs/run_scheduling_telemetry_test.exs --max-failures 1` | ❌ W0 | ⬜ |
| 14-01-02 | 01 | 1 | PARA-01 | — | Event emitted only on successful exit from `:queued` | unit | `grep -qF '[:kiln, :run, :scheduling, :queued, :stop]' lib/kiln/runs/scheduling_telemetry.ex` AND `grep -q SchedulingTelemetry lib/kiln/runs/transitions.ex` | ✅ | ⬜ |
| 14-02-01 | 02 | 1 | PARA-01 | — | RR + stable tie-break deterministic | unit | `mix test test/kiln/runs/fair_round_robin_test.exs --max-failures 1` | ❌ W0 | ⬜ |
| 14-02-02 | 02 | 1 | PARA-01 | — | RunDirector applies ordering before spawn reduce | unit | `mix test test/kiln/runs/run_director_fairness_test.exs --max-failures 1` | ❌ W0 | ⬜ |
| 14-03-01 | 03 | 2 | PARA-01 | — | Integration harness + dwell bound | integration | `mix test test/kiln/runs/run_parallel_fairness_test.exs --max-failures 1` | ❌ W0 | ⬜ |
| 14-03-02 | 03 | 2 | PARA-01 | T-14-02 | README operator copy matches D-16 | doc | `grep -q 'Fair scheduling' README.md` | ✅ | ⬜ |
| 14-03-03 | 03 | 2 | PARA-01 | — | Oban job meta includes top-level `run_id` for observability | unit | `mix test test/kiln/stages/next_stage_dispatcher_test.exs --max-failures 1` OR grep on `next_stage_dispatcher.ex` | ❌ W0 | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [x] Existing **ExUnit + Oban testing mode** covers infrastructure — no new framework install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| *None planned* | PARA-01 | All behaviors target automated telemetry + tests | — |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or documented grep gates
- [x] No 3 consecutive tasks without automated verify
- [x] No watch-mode flags in commands
- [x] `nyquist_compliant: true` set after wave 2 green

**Approval:** signed off 2026-04-23 (`14-VERIFICATION.md`, `14-01-SUMMARY.md`, `14-02-SUMMARY.md`, `14-03-SUMMARY.md` per D-2318)

---

### Threat references (plan-aligned)

| ID | Description |
|----|-------------|
| T-14-01 | Telemetry leaks secrets or uses forbidden metric labels |
| T-14-02 | Operator doc over-claims fairness beyond implemented grain |
