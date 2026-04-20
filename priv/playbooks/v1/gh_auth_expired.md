---
reason: gh_auth_expired
severity: halt
title: "GitHub auth expired — run {run_id}"
short_message: "gh auth expired; full playbook ships in Phase 6."
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

# GitHub auth expired — run {run_id}

Stub playbook. The full remediation text ships in Phase 6 (GitHub integration), where the `gh` CLI shell-out and auth refresh pipeline land.

Contact the maintainer if you hit this before Phase 6 ships — it indicates an unexpected code path.
