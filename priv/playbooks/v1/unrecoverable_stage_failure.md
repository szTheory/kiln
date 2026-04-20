---
reason: unrecoverable_stage_failure
severity: escalate
title: "Unrecoverable stage failure — run {run_id}"
short_message: "Stage failed beyond retry; full playbook ships in Phase 5."
required_context:
  - run_id
  - stage_id
remediation_commands:
  - label: "Placeholder"
    command: "# see owning_phase: 5"
audit_kind_on_resolve: block_resolved
next_action_on_resolve: abort_run
owning_phase: 5
stub: true
---

# Unrecoverable stage failure — run {run_id}

Stub playbook. Phase 5 (Verification & Bounded Loop) ships the full diagnostic bundle, stuck-detector integration, and escalation-routing remediation text.
