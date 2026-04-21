defmodule Kiln.Repo.Migrations.CreateWorkUnitEvents do
  @moduledoc """
  Append-only `work_unit_events` ledger (AGENT-04).

  Layer 1 (REVOKE) only grants INSERT+SELECT to `kiln_app`. Layers 2–3
  ship in `20260421000003_work_unit_events_immutability.exs`.
  """

  use Ecto.Migration

  @event_kinds ~w(created claimed blocked unblocked completed closed)
  @actor_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)

  def change do
    create table(:work_unit_events, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(
        :work_unit_id,
        references(:work_units, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:event_kind, :text, null: false)
      add(:actor_role, :text)
      add(:payload, :map, null: false, default: %{})
      add(:occurred_at, :utc_datetime_usec, null: false, default: fragment("now()"))

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    kinds_list = Enum.map_join(@event_kinds, ", ", &"'#{&1}'")
    roles_list = Enum.map_join(@actor_roles, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE work_unit_events
        ADD CONSTRAINT work_unit_events_event_kind_check
        CHECK (event_kind IN (#{kinds_list}))
      """,
      "ALTER TABLE work_unit_events DROP CONSTRAINT work_unit_events_event_kind_check"
    )

    execute(
      """
      ALTER TABLE work_unit_events
        ADD CONSTRAINT work_unit_events_actor_role_check
        CHECK (
          actor_role IS NULL
          OR actor_role IN (#{roles_list})
        )
      """,
      "ALTER TABLE work_unit_events DROP CONSTRAINT work_unit_events_actor_role_check"
    )

    create(
      index(:work_unit_events, [:work_unit_id, {:desc, :occurred_at}],
        name: :work_unit_events_work_unit_occurred_at_idx
      )
    )

    create(
      index(:work_unit_events, [:event_kind, {:desc, :occurred_at}],
        name: :work_unit_events_event_kind_occurred_at_idx
      )
    )

    execute(
      "ALTER TABLE work_unit_events OWNER TO kiln_owner",
      "ALTER TABLE work_unit_events OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT ON work_unit_events TO kiln_app",
      "REVOKE INSERT, SELECT ON work_unit_events FROM kiln_app"
    )

    execute(
      "REVOKE UPDATE, DELETE, TRUNCATE ON work_unit_events FROM kiln_app",
      ""
    )
  end
end
