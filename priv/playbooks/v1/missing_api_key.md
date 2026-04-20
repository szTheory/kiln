---
reason: missing_api_key
severity: halt
title: "Missing {provider} API key"
short_message: "{provider} API key is not set. Run cannot start."
required_context:
  - provider
  - run_id
remediation_commands:
  - label: "Set Anthropic key"
    command: "export ANTHROPIC_API_KEY=sk-ant-..."
  - label: "Restart the run"
    command: "kiln run restart {run_id}"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: restart_run
owning_phase: 3
---

# Missing {provider} API key

The run could not start because the `{provider}` API key is not available to the Kiln runtime.

## What happened

`Kiln.Runs.RunDirector` checked `Kiln.Secrets.present?/1` for the providers required by the run's `model_profile_snapshot` and found `{provider}` missing.

## What to do

1. Export the API key in your shell (or add it to your `.env`):
   ```
   export {provider_env_var}=...
   ```
2. Restart Kiln so `config/runtime.exs` reads the new value into `:persistent_term`:
   ```
   docker compose restart kiln
   ```
3. Restart the run: `kiln run restart {run_id}`.

## Why

Secrets are write-once at boot. Kiln cannot pick up a new key without a process restart — this is a durability decision, not a bug.
