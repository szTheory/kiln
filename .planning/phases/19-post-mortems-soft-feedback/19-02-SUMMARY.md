---
phase: 19-post-mortems-soft-feedback
plan: "02"
subsystem: database
tags: [ecto, post-mortem, runs]
---

## Self-Check: PASSED

- `run_postmortems` table (1:1 `run_id` PK/FK, typed columns, JSONB `snapshot`, `schema_version`, optional `artifact_id` FK).
- `Kiln.Runs.PostMortem` schema + `has_one :post_mortem` on `Run`.
- `Kiln.Runs.PostMortems` with `get_by_run_id/1` and `upsert_snapshot/2` (`on_conflict` on `run_id`).

## key-files.created

- `lib/kiln/runs/post_mortem.ex`
- `lib/kiln/runs/post_mortems.ex`
- `priv/repo/migrations/20260422234016_create_run_postmortems.exs`
- `test/kiln/runs/post_mortems_test.exs`

## key-files.modified

- `lib/kiln/runs/run.ex`
