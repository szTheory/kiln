defmodule Kiln.Repo.Migrations.CreateAuditEvents do
  @moduledoc """
  Creates the `audit_events` append-only ledger table (D-07..D-10, D-51).

  Implements D-12 Layer 1 (role-based REVOKE) by granting only INSERT+SELECT
  to `kiln_app`. Layers 2 (trigger) and 3 (RULE) ship in migration
  20260418000004. All three layers are tested independently in
  `test/kiln/repo/migrations/audit_events_immutability_test.exs`.

  The 22-value `event_kind` CHECK constraint is generated from
  `Kiln.Audit.EventKind.values_as_strings/0` so the Elixir module is the
  single source of truth — adding a kind in Phase 2+ means editing the
  module and writing a follow-up migration that drops + re-adds the
  constraint.

  Five b-tree composite indexes (D-10) cover the Phase 7 UI-05 audit-ledger
  filter UI (run/stage/actor/event-type/time-range).
  """

  use Ecto.Migration

  # Mirror the SSOT at migration time. If the module file is somehow absent at
  # compile time (e.g. a botched rebase that deletes it), this will surface
  # immediately — much better than a silent taxonomy drift between app and DB.
  @event_kinds Kiln.Audit.EventKind.values_as_strings()

  def up do
    create table(:audit_events, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:event_kind, :text, null: false)
      add(:actor_id, :text)
      add(:actor_role, :text)
      add(:run_id, :binary_id)
      add(:stage_id, :binary_id)
      add(:correlation_id, :binary_id, null: false)
      add(:causation_id, :binary_id)
      add(:schema_version, :integer, null: false, default: 1)
      add(:payload, :map, null: false, default: %{})
      add(:occurred_at, :utc_datetime_usec, null: false, default: fragment("now()"))

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # 22-value event_kind CHECK constraint (D-07, D-08).
    kinds_list = Enum.map_join(@event_kinds, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE audit_events
        ADD CONSTRAINT audit_events_event_kind_check
        CHECK (event_kind IN (#{kinds_list}))
      """,
      "ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check"
    )

    # 5 b-tree composite indexes per D-10. Order matters: (filter-col, time DESC)
    # is the canonical shape for "most recent N events of a given kind / run /
    # stage / actor" Phase 7 will drive.
    create(
      index(:audit_events, [:run_id, {:desc, :occurred_at}],
        where: "run_id IS NOT NULL",
        name: :audit_events_run_id_occurred_at_idx
      )
    )

    create(
      index(:audit_events, [:stage_id, {:desc, :occurred_at}],
        where: "stage_id IS NOT NULL",
        name: :audit_events_stage_id_occurred_at_idx
      )
    )

    create(
      index(:audit_events, [:event_kind, {:desc, :occurred_at}],
        name: :audit_events_event_kind_occurred_at_idx
      )
    )

    create(
      index(:audit_events, [:actor_id, {:desc, :occurred_at}],
        name: :audit_events_actor_id_occurred_at_idx
      )
    )

    create(index(:audit_events, [:correlation_id], name: :audit_events_correlation_id_idx))

    # The table is owned by kiln_owner (D-48) regardless of which
    # connecting user ran the migration. This keeps DDL authority
    # centralized in the migration role even when `mix ecto.migrate`
    # is invoked by a superuser for bootstrap.
    execute(
      "ALTER TABLE audit_events OWNER TO kiln_owner",
      "ALTER TABLE audit_events OWNER TO current_user"
    )

    # D-12 Layer 1 — role-based REVOKE. kiln_app can INSERT new rows and
    # SELECT existing rows, but cannot mutate them. Any UPDATE/DELETE/TRUNCATE
    # as kiln_app raises SQLSTATE 42501 (insufficient_privilege).
    execute(
      "GRANT INSERT, SELECT ON audit_events TO kiln_app",
      "REVOKE INSERT, SELECT ON audit_events FROM kiln_app"
    )

    # Belt-and-suspenders. The GRANT above is the only privilege granted, so
    # this REVOKE is technically a no-op — but we ship it explicitly so the
    # INSERT-only enforcement is legible in the migration file.
    execute(
      "REVOKE UPDATE, DELETE, TRUNCATE ON audit_events FROM kiln_app",
      ""
    )
  end

  def down do
    drop(table(:audit_events))
  end
end
