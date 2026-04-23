defmodule Kiln.Repo.Migrations.ExtendAuditEventKindsP19OperatorFeedbackPostMortem do
  @moduledoc """
  Phase 19: extends `audit_events_event_kind_check` for
  `:operator_feedback_received` and `:post_mortem_snapshot_stored`.
  """

  use Ecto.Migration

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
    kinds =
      Kiln.Audit.EventKind.values_as_strings()
      |> Enum.reject(&(&1 in ["operator_feedback_received", "post_mortem_snapshot_stored"]))

    kinds_list = Enum.map_join(kinds, ", ", &"'#{&1}'")

    execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

    execute("""
    ALTER TABLE audit_events
      ADD CONSTRAINT audit_events_event_kind_check
      CHECK (event_kind IN (#{kinds_list}))
    """)
  end
end
