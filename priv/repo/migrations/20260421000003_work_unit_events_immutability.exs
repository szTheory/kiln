defmodule Kiln.Repo.Migrations.WorkUnitEventsImmutability do
  @moduledoc """
  Layers 2–3 of append-only enforcement for `work_unit_events`, mirroring
  `audit_events` (D-12 analogue).
  """

  use Ecto.Migration

  def up do
    execute(
      """
      CREATE OR REPLACE FUNCTION work_unit_events_immutable()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION
          'work_unit_events is append-only (Kiln immutability invariant); attempted % blocked', TG_OP
          USING ERRCODE = 'feature_not_supported';
      END;
      $$;
      """,
      "DROP FUNCTION IF EXISTS work_unit_events_immutable()"
    )

    execute(
      """
      CREATE TRIGGER work_unit_events_no_update
        BEFORE UPDATE ON work_unit_events
        FOR EACH ROW EXECUTE FUNCTION work_unit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS work_unit_events_no_update ON work_unit_events"
    )

    execute(
      """
      CREATE TRIGGER work_unit_events_no_delete
        BEFORE DELETE ON work_unit_events
        FOR EACH ROW EXECUTE FUNCTION work_unit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS work_unit_events_no_delete ON work_unit_events"
    )

    execute(
      """
      CREATE TRIGGER work_unit_events_no_truncate
        BEFORE TRUNCATE ON work_unit_events
        FOR EACH STATEMENT EXECUTE FUNCTION work_unit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS work_unit_events_no_truncate ON work_unit_events"
    )

    execute(
      "CREATE RULE work_unit_events_no_update_rule AS ON UPDATE TO work_unit_events DO INSTEAD NOTHING",
      "DROP RULE IF EXISTS work_unit_events_no_update_rule ON work_unit_events"
    )

    execute(
      "CREATE RULE work_unit_events_no_delete_rule AS ON DELETE TO work_unit_events DO INSTEAD NOTHING",
      "DROP RULE IF EXISTS work_unit_events_no_delete_rule ON work_unit_events"
    )

    execute(
      "ALTER TABLE work_unit_events DISABLE RULE work_unit_events_no_update_rule",
      "ALTER TABLE work_unit_events ENABLE RULE work_unit_events_no_update_rule"
    )

    execute(
      "ALTER TABLE work_unit_events DISABLE RULE work_unit_events_no_delete_rule",
      "ALTER TABLE work_unit_events ENABLE RULE work_unit_events_no_delete_rule"
    )
  end

  def down do
    execute("DROP RULE IF EXISTS work_unit_events_no_delete_rule ON work_unit_events")
    execute("DROP RULE IF EXISTS work_unit_events_no_update_rule ON work_unit_events")
    execute("DROP TRIGGER IF EXISTS work_unit_events_no_truncate ON work_unit_events")
    execute("DROP TRIGGER IF EXISTS work_unit_events_no_delete ON work_unit_events")
    execute("DROP TRIGGER IF EXISTS work_unit_events_no_update ON work_unit_events")
    execute("DROP FUNCTION IF EXISTS work_unit_events_immutable()")
  end
end
