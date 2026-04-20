---
reason: rate_limit_exhausted
severity: warn
title: "{provider} rate limit hit"
short_message: "{provider} returned 429; fallback chain exhausted."
required_context:
  - provider
  - run_id
  - retry_after_seconds
remediation_commands:
  - label: "Wait and resume"
    command: "kiln run resume {run_id}"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: resume_run
owning_phase: 3
---

# {provider} rate limit exhausted

`{provider}` returned HTTP 429 for every model in the fallback chain. The run is paused, not failed.

## What happened

`Kiln.ModelRegistry.next/2` walked the fallback chain ({fallback_chain}) and every model returned 429. The account-wide rate limit is saturated.

## What to do

1. Wait for the rate-limit window to reset (`{retry_after_seconds}`s remaining on the last attempt).
2. Resume the run: `kiln run resume {run_id}`.
3. If this repeats, edit the workflow YAML to select a cheaper preset or add an alternate provider to `fallback.fallback_policy`.
