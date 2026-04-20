---
reason: gh_permissions_insufficient
severity: halt
title: "GitHub permissions insufficient — run {run_id}"
short_message: "GitHub app/PAT lacks required scopes; full playbook ships in Phase 6."
required_context:
  - run_id
remediation_commands:
  - label: "Placeholder"
    command: "# see owning_phase: 6"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: restart_run
owning_phase: 6
stub: true
---

# GitHub permissions insufficient — run {run_id}

Stub playbook. Phase 6 ships the full scope-check and remediation flow.
