defmodule Kiln.Repo.Migrations.ExtendAuditEventKindsP8FollowUpDrafted do
  @moduledoc """
  Phase 8 INTAKE-03: extends `audit_events_event_kind_check` for `:follow_up_drafted`.
  """

  use Ecto.Migration

  @prior_kinds ~w(
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
    orphan_container_swept
    dtu_contract_drift_detected
    dtu_health_degraded
    factory_circuit_opened
    factory_circuit_closed
    model_deprecated_resolved
    notification_fired
    notification_suppressed
    spec_draft_promoted
  )

  def up do
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
    kinds_list = Enum.map_join(@prior_kinds, ", ", &"'#{&1}'")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

    execute("""
    ALTER TABLE audit_events
      ADD CONSTRAINT audit_events_event_kind_check
      CHECK (event_kind IN (#{kinds_list}))
    """)
  end
end
