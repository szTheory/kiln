defmodule Kiln.Repo.Migrations.ExtendAuditEventKindsP3 do
  @moduledoc """
  Phase 3 D-145 / D-106 extension: extends the `audit_events_event_kind_check`
  CHECK constraint from the 25 kinds shipped in Phase 2 (migration
  20260419000001) to the 33 kinds declared in `Kiln.Audit.EventKind.values/0`
  after Phase 3's D-145 extension.

  Eight new atoms:

    * `:orphan_container_swept`
    * `:dtu_contract_drift_detected`
    * `:dtu_health_degraded`
    * `:factory_circuit_opened`
    * `:factory_circuit_closed`
    * `:model_deprecated_resolved`
    * `:notification_fired`
    * `:notification_suppressed`

  (`:model_routing_fallback` was already declared in Phase 1; only its JSON
  schema is rewritten in P3 to match D-106.)

  Pattern (Plan 02-01 decision (a)): drop the existing CHECK constraint,
  re-add it from `Kiln.Audit.EventKind.values_as_strings/0` (the SSOT stays
  in Elixir; never enumerate atoms in the migration body).

  `down/0` HARDCODES the prior 25-atom list (Plan 02-01 decision (d)):
  reading `EventKind` at rollback time would observe the post-migration
  33-atom source and silently no-op.
  """

  use Ecto.Migration

  # Verbatim 25-atom snapshot from priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs
  # (22 Phase 1 atoms + 3 Phase 2 D-85 extensions). Pinned deterministically:
  # do NOT source from `Kiln.Audit.EventKind` at rollback time — the module
  # attribute is always compiled to the current source, which after P3 up/0
  # is 33 atoms.
  @prior_p2_kinds_25 ~w(
    run_state_transitioned
    stage_started
    stage_completed
    stage_failed
    external_op_intent_recorded
    external_op_action_started
    external_op_completed
    external_op_failed
    secret_reference_resolved
    model_routing_fallback
    budget_check_passed
    budget_check_failed
    stuck_detector_alarmed
    scenario_runner_verdict
    work_unit_created
    work_unit_state_changed
    git_op_completed
    pr_created
    ci_status_observed
    block_raised
    block_resolved
    escalation_triggered
    stage_input_rejected
    artifact_written
    integrity_violation
  )

  def up do
    # Mirror the SSOT at migration time. The Elixir module is compiled
    # against the current source (33 atoms after Phase 3 D-145), so this
    # list reflects the extended taxonomy.
    kinds = Kiln.Audit.EventKind.values_as_strings()
    kinds_list = Enum.map_join(kinds, ", ", &"'#{&1}'")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

    execute("""
    ALTER TABLE audit_events
      ADD CONSTRAINT audit_events_event_kind_check
      CHECK (event_kind IN (#{kinds_list}))
    """)
  end

  def down do
    # Re-create the ORIGINAL 25-kind (post-P2) constraint. The list is
    # hard-coded because reading from `Kiln.Audit.EventKind` at rollback
    # time would observe the 33-atom module attribute (the module is always
    # compiled to the current source) and silently make `down` a no-op.
    kinds_list = Enum.map_join(@prior_p2_kinds_25, ", ", &"'#{&1}'")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

    execute("""
    ALTER TABLE audit_events
      ADD CONSTRAINT audit_events_event_kind_check
      CHECK (event_kind IN (#{kinds_list}))
    """)
  end
end
