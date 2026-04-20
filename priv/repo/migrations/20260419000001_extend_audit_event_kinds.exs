defmodule Kiln.Repo.Migrations.ExtendAuditEventKinds do
  @moduledoc """
  Extends the `audit_events_event_kind_check` CHECK constraint from the 22
  kinds shipped in Phase 1 (migration 20260418000003) to the 25 kinds declared
  in `Kiln.Audit.EventKind.values/0` after Phase 2's D-85 extension.

  Pattern (per RESEARCH.md §Pitfall #2): Postgres has no in-place CHECK-expand;
  the migration drops the old constraint and re-adds a new one generated from
  `Kiln.Audit.EventKind.values_as_strings/0` (the SSOT stays in Elixir).

  `down/0` hard-codes the original 22-kind list. Reading from
  `Kiln.Audit.EventKind` at rollback time would observe the 25-kind module
  attribute (the module is compiled to the current source) and silently make
  `down` a no-op.
  """

  use Ecto.Migration

  def up do
    # Mirror the SSOT at migration time. The Elixir module is compiled against
    # the current source (25 atoms after Phase 2 D-85), so this list reflects
    # the extended taxonomy.
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
    # Re-create the ORIGINAL 22-kind constraint. The list is hard-coded here
    # because reading from `Kiln.Audit.EventKind` at rollback time would
    # observe the 25-atom module attribute (the module is always compiled to
    # the current source) and silently make `down` a no-op.
    original_kinds =
      ~w(
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
      )

    kinds_list = Enum.map_join(original_kinds, ", ", &"'#{&1}'")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

    execute("""
    ALTER TABLE audit_events
      ADD CONSTRAINT audit_events_event_kind_check
      CHECK (event_kind IN (#{kinds_list}))
    """)
  end
end
