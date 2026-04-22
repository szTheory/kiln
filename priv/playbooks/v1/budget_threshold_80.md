---
reason: budget_threshold_80
severity: warn
title: "Budget notice: most of run cap used ({run_id})"
short_message: "Spend is about {pct}% of the frozen cap. The run continues."
required_context:
  - run_id
  - spent_usd
  - cap_usd
  - pct
remediation_commands:
  - label: "Review run detail"
    command: "open http://localhost:4000/ops/runs/{run_id}"
  - label: "Plan next cap change"
    command: "edit workflow YAML caps.max_tokens_usd before restart"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: resume_run
owning_phase: 18
---

# Budget notice: most of run cap used

Spend has reached **{pct}%** of the run’s frozen `max_tokens_usd` cap (about **{spent_usd}** of **{cap_usd}**). **The run continues.** This is a stronger advisory than the 50% band; the run still proceeds under the same caps.

## What to do

1. Review routed model spend on run detail for `{run_id}`.
2. If you are near a hard halt, plan a cap increase before the next expensive stage.
3. Caps do not change until you edit the workflow and restart the run.
