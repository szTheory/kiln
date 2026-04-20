defmodule Kiln.Repo.Migrations.CreateStageRuns do
  @moduledoc """
  Creates the `stage_runs` table — one row per per-attempt stage
  execution. Per D-82, hot-path cost/token/model columns live here
  (NOT in audit payload, NOT in artifacts) so the Phase 7 cost dashboard
  and Phase 3 model-fallback detection can index them directly.

  Structural clone of `20260418000006_create_external_operations.exs`
  with the four enum CHECKs (`kind`, `agent_role`, `state`, `sandbox`)
  generated via `Enum.map_join/3`.

  FK policy (D-81): `run_id REFERENCES runs(id) ON DELETE RESTRICT` —
  runs cannot be deleted while any stage_runs (or artifacts) reference
  them. kiln_app does not have DELETE grants on `runs` anyway, but the
  RESTRICT policy is the structural enforcement: any attempt to delete
  a run with live stage_runs raises `Postgrex.Error` (foreign_key_violation).

  Uniqueness: `(run_id, workflow_stage_id, attempt)` is the business
  identity — exactly one row per (run, stage, attempt) triple. This is
  what the Phase 3 stage-dispatcher consults before enqueueing retries.

  Additional CHECKs:
    * `attempt BETWEEN 1 AND 10` — D-74 attempt ceiling (stage-contract
      envelope enforces same bound at input-validation time; DB is
      defence-in-depth)
    * `cost_usd >= 0` — non-negative monetary invariant

  Privileges: kiln_app gets INSERT/SELECT/UPDATE (state mutates via
  dispatcher); no DELETE (forensic preservation, mirrors `runs`).
  """

  use Ecto.Migration

  @kinds ~w(planning coding testing verifying merge)
  @agent_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)
  @states ~w(pending dispatching running succeeded failed cancelled)
  @sandboxes ~w(none readonly readwrite)

  def change do
    create table(:stage_runs, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      # D-81: on_delete :restrict — runs cannot be deleted while stage_runs reference them.
      add(:run_id, references(:runs, type: :binary_id, on_delete: :restrict), null: false)

      # Matches the YAML workflow stages[].id (^[a-z][a-z0-9_]{1,31}$); D-58.
      add(:workflow_stage_id, :text, null: false)

      add(:kind, :text, null: false)
      add(:agent_role, :text, null: false)
      add(:attempt, :integer, null: false, default: 1)
      add(:state, :text, null: false, default: "pending")
      add(:timeout_seconds, :integer, null: false)
      add(:sandbox, :text, null: false)

      # D-82 hot-path metrics columns (NOT audit payload).
      add(:tokens_used, :integer, null: false, default: 0)
      add(:cost_usd, :decimal, precision: 18, scale: 6, null: false, default: 0)

      # OPS-02 adaptive-fallback detection: record what was asked AND what
      # actually handled it, so silent fallback across tiers surfaces in the
      # dashboard as a mismatch.
      add(:requested_model, :text)
      add(:actual_model_used, :text)

      # Populated only when state = :failed
      add(:error_summary, :text)

      timestamps(type: :utc_datetime_usec)
    end

    # Four enum CHECKs via a comprehension — one per enum column.
    for {col, vals} <- [
          kind: @kinds,
          agent_role: @agent_roles,
          state: @states,
          sandbox: @sandboxes
        ] do
      list = Enum.map_join(vals, ", ", &"'#{&1}'")

      execute(
        "ALTER TABLE stage_runs ADD CONSTRAINT stage_runs_#{col}_check CHECK (#{col} IN (#{list}))",
        "ALTER TABLE stage_runs DROP CONSTRAINT stage_runs_#{col}_check"
      )
    end

    # D-74 attempt ceiling. CHECK at DB layer is defence-in-depth alongside
    # the validate_number in the changeset.
    execute(
      "ALTER TABLE stage_runs ADD CONSTRAINT stage_runs_attempt_range CHECK (attempt BETWEEN 1 AND 10)",
      "ALTER TABLE stage_runs DROP CONSTRAINT stage_runs_attempt_range"
    )

    # Non-negative cost invariant.
    execute(
      "ALTER TABLE stage_runs ADD CONSTRAINT stage_runs_cost_nonneg CHECK (cost_usd >= 0)",
      "ALTER TABLE stage_runs DROP CONSTRAINT stage_runs_cost_nonneg"
    )

    # Indexes — canonical query shapes:
    # 1. Business-unique (run_id, workflow_stage_id, attempt) — the
    # stage-dispatcher's dedupe key. Phase 3's StageWorker consults this
    # before scheduling the next attempt.
    create(
      unique_index(:stage_runs, [:run_id, :workflow_stage_id, :attempt],
        name: :stage_runs_run_stage_attempt_idx
      )
    )

    # 2. (run_id) — "show me all stages for this run" (the Phase 7 run
    # detail view's dominant query).
    create(index(:stage_runs, [:run_id], name: :stage_runs_run_id_idx))

    # 3. (state) — dashboard counts + StuckDetector scans.
    create(index(:stage_runs, [:state], name: :stage_runs_state_idx))

    # D-48: ownership + grants (same shape as runs).
    execute(
      "ALTER TABLE stage_runs OWNER TO kiln_owner",
      "ALTER TABLE stage_runs OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON stage_runs TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON stage_runs FROM kiln_app"
    )
  end
end
