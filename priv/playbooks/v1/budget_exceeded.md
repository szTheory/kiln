---
reason: budget_exceeded
severity: halt
title: "Budget cap exceeded on run {run_id}"
short_message: "Pre-flight estimated ${estimated_usd}; remaining ${remaining_usd}."
required_context:
  - run_id
  - estimated_usd
  - remaining_usd
remediation_commands:
  - label: "Review spend"
    command: "open http://localhost:4000/ops/dashboard"
  - label: "Raise caps (workflow YAML)"
    command: "edit priv/workflows/{workflow_id}.yaml # caps.max_tokens_usd"
  - label: "Restart the run"
    command: "kiln run restart {run_id}"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: restart_run
owning_phase: 3
---

# Budget exceeded on run {run_id}

`Kiln.Agents.BudgetGuard.check!/2` estimated the next LLM call at **${estimated_usd}** but only **${remaining_usd}** of the run's budget remains. The call was refused before dispatch.

## Why there is no override

Bounded autonomy (CLAUDE.md) is a core Kiln invariant. A `KILN_BUDGET_OVERRIDE` env var would make budget an advisory instead of a guarantee — at 2am that is the wrong trade (D-138).

## What to do

1. Review spend: `/ops/dashboard` shows the per-stage breakdown.
2. If the run is worth more budget, edit the workflow YAML:
   ```yaml
   caps:
     max_tokens_usd: {new_cap_usd}
   ```
3. Restart the run: `kiln run restart {run_id}`. The edited caps are pinned into `runs.caps_snapshot` on start.
