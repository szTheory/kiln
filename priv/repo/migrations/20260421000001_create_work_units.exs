defmodule Kiln.Repo.Migrations.CreateWorkUnits do
  @moduledoc """
  Creates `work_units` (mutable coordination read model) and
  `work_unit_dependencies` (blocker edges) for Phase 4 / AGENT-04.

  Mirrors the `runs` / `stage_runs` enum-CHECK + uuidv7 PK + owner/grant
  posture. `kiln_app` may INSERT/SELECT/UPDATE `work_units` but not
  DELETE (forensic coordination state). Dependencies may DELETE rows when
  unblock clears edges.
  """

  use Ecto.Migration

  @agent_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)
  @wu_states ~w(open blocked in_progress completed closed)

  def change do
    create table(:work_units, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:run_id, references(:runs, type: :binary_id, on_delete: :restrict), null: false)

      add(:agent_role, :text, null: false)
      add(:state, :text, null: false, default: "open")

      add(:priority, :integer, null: false, default: 100)
      add(:blockers_open_count, :integer, null: false, default: 0)

      add(:claimed_by_role, :text)
      add(:claimed_at, :utc_datetime_usec)
      add(:closed_at, :utc_datetime_usec)

      add(:input_payload, :map, null: false, default: %{})
      add(:result_payload, :map, null: false, default: %{})
      add(:external_ref, :text)

      timestamps(type: :utc_datetime_usec)
    end

    roles_list = Enum.map_join(@agent_roles, ", ", &"'#{&1}'")
    states_list = Enum.map_join(@wu_states, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE work_units
        ADD CONSTRAINT work_units_agent_role_check
        CHECK (agent_role IN (#{roles_list}))
      """,
      "ALTER TABLE work_units DROP CONSTRAINT work_units_agent_role_check"
    )

    execute(
      """
      ALTER TABLE work_units
        ADD CONSTRAINT work_units_state_check
        CHECK (state IN (#{states_list}))
      """,
      "ALTER TABLE work_units DROP CONSTRAINT work_units_state_check"
    )

    execute(
      """
      ALTER TABLE work_units
        ADD CONSTRAINT work_units_priority_nonneg
        CHECK (priority >= 0)
      """,
      "ALTER TABLE work_units DROP CONSTRAINT work_units_priority_nonneg"
    )

    execute(
      """
      ALTER TABLE work_units
        ADD CONSTRAINT work_units_blockers_open_nonneg
        CHECK (blockers_open_count >= 0)
      """,
      "ALTER TABLE work_units DROP CONSTRAINT work_units_blockers_open_nonneg"
    )

    execute(
      """
      ALTER TABLE work_units
        ADD CONSTRAINT work_units_claimed_by_role_check
        CHECK (
          claimed_by_role IS NULL
          OR claimed_by_role IN (#{roles_list})
        )
      """,
      "ALTER TABLE work_units DROP CONSTRAINT work_units_claimed_by_role_check"
    )

    create(index(:work_units, [:run_id], name: :work_units_run_id_idx))

    create(
      index(:work_units, [:run_id, :inserted_at],
        name: :work_units_run_id_inserted_at_idx
      )
    )

    create(
      index(:work_units, [:state, :blockers_open_count, :priority, :inserted_at],
        where:
          "state IN ('open','blocked','in_progress') AND blockers_open_count = 0",
        name: :work_units_ready_partial_idx
      )
    )

    create table(:work_unit_dependencies, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:blocked_work_unit_id,
        references(:work_units, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:blocker_work_unit_id,
        references(:work_units, type: :binary_id, on_delete: :restrict),
        null: false
      )

      timestamps(type: :utc_datetime_usec)
    end

    execute(
      """
      ALTER TABLE work_unit_dependencies
        ADD CONSTRAINT work_unit_dependencies_no_self_block
        CHECK (blocked_work_unit_id <> blocker_work_unit_id)
      """,
      "ALTER TABLE work_unit_dependencies DROP CONSTRAINT work_unit_dependencies_no_self_block"
    )

    create(
      unique_index(:work_unit_dependencies, [:blocked_work_unit_id, :blocker_work_unit_id],
        name: :work_unit_dependencies_blocked_blocker_uidx
      )
    )

    create(
      index(:work_unit_dependencies, [:blocker_work_unit_id],
        name: :work_unit_dependencies_blocker_work_unit_id_idx
      )
    )

    create(
      index(:work_unit_dependencies, [:blocked_work_unit_id],
        name: :work_unit_dependencies_blocked_work_unit_id_idx
      )
    )

    execute(
      "ALTER TABLE work_units OWNER TO kiln_owner",
      "ALTER TABLE work_units OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON work_units TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON work_units FROM kiln_app"
    )

    execute(
      "REVOKE DELETE, TRUNCATE ON work_units FROM kiln_app",
      ""
    )

    execute(
      "ALTER TABLE work_unit_dependencies OWNER TO kiln_owner",
      "ALTER TABLE work_unit_dependencies OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE, DELETE ON work_unit_dependencies TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE, DELETE ON work_unit_dependencies FROM kiln_app"
    )
  end
end
