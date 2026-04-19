defmodule Kiln.Repo.Migrations.CreateExternalOperations do
  @moduledoc """
  Creates the `external_operations` single polymorphic idempotency table
  (D-14 — Brandur Stripe pattern). Every external side-effect (LLM call,
  git push, Docker run, notify, secret resolve) funnels through this
  table via the two-phase `intent → action → completion` state machine
  shipped in `Kiln.ExternalOperations` (D-18).

  Column + index layout per D-21; CHECK on the 5-state enum per D-16.
  PK is `uuid_generate_v7()` (same extension/fallback as `audit_events`
  from Plan 01-03, so insertion order sorts by wall-clock time).

  Privileges (D-48): `kiln_app` gets INSERT/SELECT/UPDATE (state
  transitions need UPDATE); explicitly NOT granted DELETE (forensic
  preservation — only the 30-day Pruner running as `kiln_owner` can
  delete, via a `SET LOCAL ROLE` inside the worker).
  """

  use Ecto.Migration

  @states ~w(intent_recorded action_in_flight completed failed abandoned)

  def up do
    create table(:external_operations, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      # Classification (D-17 initial 10-kind taxonomy; open-coded text —
      # adding a kind later is an app-side change plus a data migration
      # if we need to backfill old rows).
      add(:op_kind, :text, null: false)

      # Idempotency key (D-15: flat string `run_id:stage_id:op_name` or
      # `system:...` for ops with no run context).
      add(:idempotency_key, :text, null: false)

      # State machine (D-16, 5 values). Enforced at the DB via a CHECK
      # constraint (below) and at the app via `Ecto.Enum`.
      add(:state, :text, null: false, default: "intent_recorded")

      # Payload versioning — future payload shapes can be distinguished
      # by bumping this and registering a new JSV schema version.
      add(:schema_version, :integer, null: false, default: 1)

      # Polymorphic payloads — `intent_payload` captures the caller's
      # intent at Phase A (what they wanted); `result_payload` captures
      # the external system's response at Phase C success.
      add(:intent_payload, :map, null: false, default: %{})
      add(:result_payload, :map)

      # Retry accounting
      add(:attempts, :integer, null: false, default: 0)
      add(:last_error, :map)

      # Associations — nullable so system-level ops (e.g. a periodic
      # secret refresh) can still flow through this table.
      add(:run_id, :binary_id)
      add(:stage_id, :binary_id)

      # Lifecycle timestamps, one per state transition.
      add(:intent_recorded_at, :utc_datetime_usec)
      add(:action_started_at, :utc_datetime_usec)
      add(:completed_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # 5-value state CHECK constraint (D-16).
    states_list = Enum.map_join(@states, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE external_operations
        ADD CONSTRAINT external_operations_state_check
        CHECK (state IN (#{states_list}))
      """,
      "ALTER TABLE external_operations DROP CONSTRAINT external_operations_state_check"
    )

    # Unique index on idempotency_key (D-15). This is the enforcement
    # that makes `INSERT ... ON CONFLICT DO NOTHING` safe: two callers
    # racing on the same key will have exactly one win.
    create(
      unique_index(:external_operations, [:idempotency_key],
        name: :external_operations_idempotency_key_idx
      )
    )

    # Active-state partial index (D-21) — supports the Phase 5 StuckDetector
    # scanning for orphaned rows that got stuck in an intermediate state.
    create(
      index(:external_operations, [:state],
        where: "state IN ('intent_recorded', 'action_in_flight')",
        name: :external_operations_active_state_idx
      )
    )

    # Per-run lookup (D-21) — supports "show all external ops for this
    # run" queries from Phase 7 UI and `StuckDetector` scans.
    create(index(:external_operations, [:run_id], name: :external_operations_run_id_idx))

    # Per-kind state lookup (D-21) — supports "how many docker_run ops
    # are currently action_in_flight?" style dashboards.
    create(
      index(:external_operations, [:op_kind, :state],
        name: :external_operations_op_kind_state_idx
      )
    )

    # Ownership transfer — matches the audit_events pattern. Migrations
    # may be bootstrapped as a connecting superuser, but the table is
    # owned by kiln_owner so DDL authority stays centralised (D-48).
    execute(
      "ALTER TABLE external_operations OWNER TO kiln_owner",
      "ALTER TABLE external_operations OWNER TO current_user"
    )

    # D-48 grants. kiln_app gets full DML except DELETE — forensic
    # preservation (T-03 mitigation). The Pruner is the only code path
    # that deletes, and it runs as kiln_owner via `SET LOCAL ROLE`.
    execute(
      "GRANT INSERT, SELECT, UPDATE ON external_operations TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON external_operations FROM kiln_app"
    )
  end

  def down do
    execute(
      "REVOKE ALL ON external_operations FROM kiln_app",
      ""
    )

    drop(table(:external_operations))
  end
end
