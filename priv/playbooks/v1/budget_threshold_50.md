---
reason: budget_threshold_50
severity: warn
title: "Budget notice: half of run cap reached ({run_id})"
short_message: "Spend is about {pct}% of the frozen cap. The run continues."
required_context:
  - run_id
  - spent_usd
  - cap_usd
  - pct
remediation_commands:
  - label: "Review run detail"
    command: "open http://localhost:4000/ops/runs/{run_id}"
  - label: "Observe spend"
    command: "watch cost dashboard for routed model spend"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: resume_run
owning_phase: 18
---

# Budget notice: half of run cap reached

Spend has reached **{pct}%** of the run’s frozen `max_tokens_usd` cap (about **{spent_usd}** of **{cap_usd}**). **The run continues.** This is advisory only — caps are unchanged until you edit the workflow and restart.

## What to do

1. Open run detail for `{run_id}` to see per-stage cost and model routing.
2. If spend is expected, no action is required.
3. If you need more headroom, raise `caps.max_tokens_usd` in the workflow YAML and restart the run.
