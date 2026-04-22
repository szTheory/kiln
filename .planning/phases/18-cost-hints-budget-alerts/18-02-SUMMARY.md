---
phase: 18-cost-hints-budget-alerts
plan: "02"
subsystem: ui
tags: [blockers, notifications, pubsub, oban]

requires:
  - phase: 18-01
    provides: BudgetAlerts.evaluate_crossings/1 + audit kind
provides:
  - Advisory Reason atoms + playbooks + raise_block guard
  - notify_run_if_needed/1 audit→desktop→PubSub pipeline
  - StageWorker hook after stage success
affects: [phase-18-plan-03]

tech-stack:
  added: []
  patterns:
    - "PubSub tuple {:budget_alert, %{crossings: ...}} for LiveView refresh"

key-files:
  created:
    - priv/playbooks/v1/budget_threshold_50.md
    - priv/playbooks/v1/budget_threshold_80.md
  modified:
    - lib/kiln/blockers/reason.ex
    - lib/kiln/blockers.ex
    - lib/kiln/budget_alerts.ex
    - lib/kiln/stages/stage_worker.ex
    - priv/playbook_schemas/v1/playbook.json
    - config/test.exs
    - test/kiln/blockers/reason_test.exs
    - test/kiln/blockers_test.exs
    - test/kiln/notifications_test.exs

key-decisions:
  - "Test env skip_desktop_dispatch avoids shell in BudgetAlerts notify tests"
  - "blocking?/1 filters infer_block_reason so advisory atoms never drive unblock panel"

patterns-established:
  - "Non-blocking reasons extend Reason.all/0 but never BlockedError"

requirements-completed: [COST-02]

duration: 30min
completed: 2026-04-22
---

# Phase 18 Plan 02 Summary

**Advisory threshold reasons, audit-first notify path, and run PubSub wiring shipped.**

## Task commits

1. **Reason + playbooks + raise_block guard** — `0c17636`
2. **notify_run_if_needed + StageWorker + tests** — `1fe4676`

## Self-Check: PASSED

- `mix test test/kiln/blockers/reason_test.exs test/kiln/blockers_test.exs test/kiln/notifications_test.exs test/kiln/stages/stage_worker_test.exs`
- `mix compile --warnings-as-errors`
