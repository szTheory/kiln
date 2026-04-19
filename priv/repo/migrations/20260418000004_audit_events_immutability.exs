defmodule Kiln.Repo.Migrations.AuditEventsImmutability do
  @moduledoc """
  Ships Layers 2 and 3 of the D-12 defense-in-depth INSERT-only enforcement
  for `audit_events`.

  Layer 1 (REVOKE) lives in migration 20260418000003. The three layers work
  together: REVOKE blocks mutation for the runtime role; the BEFORE trigger
  blocks mutation even for the table owner; the RULE is a final silent
  safety net if both role and trigger are somehow bypassed.

  Layer 2 — `BEFORE UPDATE OR DELETE OR TRUNCATE` triggers that call
  `audit_events_immutable()`. The trigger `RAISE EXCEPTION` message
  includes the literal string `"audit_events is append-only"` — callers
  and tests assert on this substring (see
  `test/kiln/repo/migrations/audit_events_immutability_test.exs`).

  Layer 3 — `CREATE RULE ... DO INSTEAD NOTHING` on UPDATE and DELETE.
  Returns `num_rows: 0` silently when the trigger is explicitly disabled.
  Exists purely as a last-ditch guard against accidental data loss during
  migrations that deliberately disable triggers.

  `feature_not_supported` (SQLSTATE 0A000) is the semantically-closest
  Postgres error class for "this operation is permanently unsupported on
  this relation" — we use it explicitly so catching code can discriminate
  trigger-enforcement errors from check-constraint errors (23514) or
  privilege errors (42501).
  """

  use Ecto.Migration

  def up do
    execute(
      """
      CREATE OR REPLACE FUNCTION audit_events_immutable()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION
          'audit_events is append-only (Kiln immutability invariant); attempted % blocked', TG_OP
          USING ERRCODE = 'feature_not_supported';
      END;
      $$;
      """,
      "DROP FUNCTION IF EXISTS audit_events_immutable()"
    )

    # BEFORE-UPDATE and BEFORE-DELETE triggers are row-level. Postgres
    # requires TRUNCATE triggers to be statement-level.
    execute(
      """
      CREATE TRIGGER audit_events_no_update
        BEFORE UPDATE ON audit_events
        FOR EACH ROW EXECUTE FUNCTION audit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS audit_events_no_update ON audit_events"
    )

    execute(
      """
      CREATE TRIGGER audit_events_no_delete
        BEFORE DELETE ON audit_events
        FOR EACH ROW EXECUTE FUNCTION audit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS audit_events_no_delete ON audit_events"
    )

    execute(
      """
      CREATE TRIGGER audit_events_no_truncate
        BEFORE TRUNCATE ON audit_events
        FOR EACH STATEMENT EXECUTE FUNCTION audit_events_immutable()
      """,
      "DROP TRIGGER IF EXISTS audit_events_no_truncate ON audit_events"
    )

    # Layer 3 — RULE DO INSTEAD NOTHING. If both the role REVOKE and
    # the trigger are bypassed (e.g. a superuser disables the trigger),
    # the RULE rewrites UPDATE/DELETE to a no-op. The row is not modified
    # and num_rows returns 0.
    execute(
      "CREATE RULE audit_events_no_update_rule AS ON UPDATE TO audit_events DO INSTEAD NOTHING",
      "DROP RULE IF EXISTS audit_events_no_update_rule ON audit_events"
    )

    execute(
      "CREATE RULE audit_events_no_delete_rule AS ON DELETE TO audit_events DO INSTEAD NOTHING",
      "DROP RULE IF EXISTS audit_events_no_delete_rule ON audit_events"
    )
  end

  def down do
    execute("DROP RULE IF EXISTS audit_events_no_delete_rule ON audit_events")
    execute("DROP RULE IF EXISTS audit_events_no_update_rule ON audit_events")
    execute("DROP TRIGGER IF EXISTS audit_events_no_truncate ON audit_events")
    execute("DROP TRIGGER IF EXISTS audit_events_no_delete ON audit_events")
    execute("DROP TRIGGER IF EXISTS audit_events_no_update ON audit_events")
    execute("DROP FUNCTION IF EXISTS audit_events_immutable()")
  end
end
