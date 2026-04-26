---
phase: 19-post-mortems-soft-feedback
plan: "05"
subsystem: ui
tags: [liveview, stages, operator-nudge]
requirements-completed:
  - SELF-01
  - FEEDBACK-01
---

## Self-Check: PASSED

- `OperatorNudges.consume_pending_for_planning/1` locks run, pages pending feedback audits, advances `operator_nudge_last_audit_id`.
- `StageWorker` runs consumption before `stub_dispatch` for `:planning`; appends `operator_nudges_consumed: N` to stub artifact when `N > 0`.
- `RunDetailLive`: `#post-mortem-panel` for merged runs; `#operator-nudge-form` with `phx-disable-with`, `submit_nudge` handler, rate-limit flash copy containing `Try again`.

## key-files.modified

- `lib/kiln/stages/stage_worker.ex`
- `lib/kiln/operator_nudges.ex`
- `lib/kiln_web/live/run_detail_live.ex`
- `test/kiln/stages/stage_worker_test.exs`
- `test/kiln_web/live/run_detail_live_test.exs`
