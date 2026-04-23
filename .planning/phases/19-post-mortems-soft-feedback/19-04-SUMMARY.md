---
phase: 19-post-mortems-soft-feedback
plan: "04"
subsystem: api
tags: [operator, audit, ets, telemetry]
---

## Self-Check: PASSED

- `runs.operator_nudge_last_audit_id` nullable `binary_id` (no FK — migration ordering).
- `Kiln.OperatorNudgeLimiter` ETS cooldown + hourly cap; `Kiln.Application` calls `ensure_table/0` at boot.
- `Kiln.OperatorNudges.submit/3`: normalize/validate body, rate limits, `Audit.append(:operator_feedback_received)` in `Repo.transact`, telemetry `[:kiln, :operator, :nudge, :received]` without raw body in metadata.

## key-files.created

- `lib/kiln/operator_nudge_limiter.ex`
- `lib/kiln/operator_nudges.ex`
- `priv/repo/migrations/20260422234610_add_operator_nudge_last_audit_id_to_runs.exs`
- `test/kiln/operator_nudges_test.exs`

## key-files.modified

- `lib/kiln/application.ex`
- `lib/kiln/runs/run.ex`
