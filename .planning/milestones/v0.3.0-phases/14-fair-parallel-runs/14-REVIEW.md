---
phase: 14-fair-parallel-runs
status: clean
reviewed: 2026-04-22
depth: quick
---

# Phase 14 — Code review (quick)

## Scope

Phase 14 application changes: scheduling telemetry, fair round-robin + RunDirector cursor, Oban meta enrichment, tests, README, `.check.exs` ex_unit→dialyzer dependency.

## Findings

No blocking issues identified in quick pass.

- **Telemetry metadata** is whitelisted; `run_id` is not added to `KilnWeb.Telemetry` metric tags.
- **`emit_queued_dwell_stop/2`** no-ops unless `run.state == :queued`, avoiding duplicate signals on re-entrancy.
- **Fair ordering** is pure and deterministic (no random tie-break).
- **Oban meta** merges `pack_meta()` first so `kiln_ctx` is preserved; `run_id` string key is explicit for log grep.

## Residual risks

- `run_parallel_fairness_test` relies on live `RunDirector.start_run/1` and app supervision; flakiness should be monitored if CI load changes.
