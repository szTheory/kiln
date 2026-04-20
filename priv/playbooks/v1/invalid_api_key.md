---
reason: invalid_api_key
severity: halt
title: "Invalid {provider} API key"
short_message: "{provider} rejected the API key (HTTP 401)."
required_context:
  - provider
  - run_id
remediation_commands:
  - label: "Rotate the key"
    command: "{provider_rotate_url}"
  - label: "Update .env and restart"
    command: "docker compose restart kiln"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: restart_run
owning_phase: 3
---

# Invalid {provider} API key

`{provider}` returned **HTTP 401 Unauthorized** on the most recent call from run `{run_id}`.

## What happened

The key loaded from `{provider_env_var}` at boot was rejected by the provider. Common causes:
- Key has been revoked or rotated on the provider dashboard.
- Key belongs to a different workspace/organization than the one the run targets.
- Key was truncated during copy-paste (check for trailing newline or whitespace).

## What to do

1. Rotate the key on the provider dashboard.
2. Update your `.env` with the new value.
3. Restart Kiln: `docker compose restart kiln`.
4. Restart the run: `kiln run restart {run_id}`.
