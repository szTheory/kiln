---
reason: quota_exceeded
severity: halt
title: "{provider} account quota exceeded"
short_message: "{provider} returned quota_exceeded; account billing action required."
required_context:
  - provider
  - run_id
remediation_commands:
  - label: "Check provider billing"
    command: "{provider_billing_url}"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: restart_run
owning_phase: 3
---

# {provider} quota exceeded

`{provider}` returned a `quota_exceeded` error from run `{run_id}`. Billing action is required on the provider side.

## What to do

1. Open the provider billing dashboard ({provider_billing_url}).
2. Add credit / raise the monthly cap.
3. Wait up to 5 minutes for the provider to propagate.
4. Restart the run: `kiln run restart {run_id}`.
