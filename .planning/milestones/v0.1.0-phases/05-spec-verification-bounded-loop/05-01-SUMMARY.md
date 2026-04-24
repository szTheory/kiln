---
phase: 05-spec-verification-bounded-loop
plan: "01"
status: complete
completed: "2026-04-21"
---

## Outcome

Postgres durability floor for Phase 5: `specs`, `spec_revisions` (with `scenario_manifest_sha256`), `holdout_scenarios` (no `kiln_app` grants), and `runs` columns `governed_attempt_count` + `stuck_signal_window` (ORCH-06 / OBS-04).

## Key files

- `priv/repo/migrations/20260422000001_create_specs_and_spec_revisions.exs` — combined migration (documented choice vs split files)
- `priv/repo/migrations/20260422000002_create_holdout_scenarios.exs`
- `priv/repo/migrations/20260422000003_runs_phase5_budget_stuck.exs`
- `lib/kiln/specs/{spec,spec_revision,holdout_scenario}.ex`, `lib/kiln/specs.ex`
- `lib/kiln/runs/run.ex` — new fields + `transition_changeset/3` casts
- Tests: `test/kiln/specs/{spec_revision,holdout_scenario}_test.exs`, `test/kiln/runs/phase5_run_fields_test.exs`

## Self-Check: PASSED

- `mix test test/kiln/specs/ test/kiln/runs/phase5_run_fields_test.exs`

## Deviations

- `lib/kiln/repo.ex` listed in plan frontmatter but unchanged — no second Repo until 05-04.
