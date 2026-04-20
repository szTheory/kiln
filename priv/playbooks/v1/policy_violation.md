---
reason: policy_violation
severity: halt
title: "Policy violation on run {run_id}"
short_message: "{policy_detail}"
required_context:
  - run_id
  - policy_detail
remediation_commands:
  - label: "Inspect the diagnostic"
    command: "kiln run diagnostic {run_id}"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: abort_run
owning_phase: 3
---

# Policy violation — run {run_id}

The run triggered a policy guard:

> {policy_detail}

Common causes:
- Sandbox env-builder rejected a secret-shaped env var name (D-134 allowlist).
- Sandbox detected an egress attempt to a non-DTU destination (Wave 3 adversarial layer).
- Prompt-injection tool-call rejected by typed tool allowlist (Phase 4 scope; groundwork only in P3).

## What to do

1. Open the run diagnostic: `kiln run diagnostic {run_id}` prints the full audit trail with the triggering event.
2. If this is a workflow authoring bug, fix the YAML and restart.
3. If this is agent-generated code attempting something suspicious, that is the system working as designed — do not override.
