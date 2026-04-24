---
phase: 19-post-mortems-soft-feedback
plan: "03"
subsystem: infra
tags: [oban, post-mortem, transitions]
requirements-completed: [SELF-01]
---

## Self-Check: PASSED

- `Kiln.Oban.PostMortemMaterializeWorker` on `:default` queue: `external_operations` intent `post_mortem_materialize`, builds snapshot from `stage_runs` + audit watermark, `PostMortems.upsert_snapshot/2`, optional `:post_mortem_snapshot_stored` audit echo.
- `Kiln.Runs.Transitions.transition/3` enqueues materialization **after** `Repo.transact` returns `{:ok, run}` when `to == :merged` (never inside the transaction).

## key-files.created

- `lib/kiln/oban/post_mortem_materialize_worker.ex`
- `test/kiln/oban/post_mortem_materialize_worker_test.exs`

## key-files.modified

- `lib/kiln/runs/transitions.ex`
