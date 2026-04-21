defmodule Kiln.Repo.Migrations.RunsPhase5BudgetStuck do
  @moduledoc """
  Phase 5 durable inputs for **ORCH-06** (bounded autonomy / governed attempts)
  and **OBS-04** (stuck-run sliding window).

  * `governed_attempt_count` — monotonic counter incremented only on
    idempotent-safe boundaries inside `Kiln.Runs.Transitions` (wired in Plan 05-05).
  * `stuck_signal_window` — jsonb array of recent `{stage_id, failure_class}` maps
    (or equivalent) feeding `Kiln.Policies.StuckWindow` — updated only from the
    same `SELECT … FOR UPDATE` transaction as state transitions (D-S05).
  """

  use Ecto.Migration

  def change do
    alter table(:runs) do
      add(:governed_attempt_count, :integer, null: false, default: 0)

      add(:stuck_signal_window, :map,
        null: false,
        default: fragment("'[]'::jsonb")
      )
    end

    execute(
      "COMMENT ON COLUMN runs.governed_attempt_count IS 'ORCH-06: governed attempts (bounded autonomy)'",
      "COMMENT ON COLUMN runs.governed_attempt_count IS NULL"
    )

    execute(
      "COMMENT ON COLUMN runs.stuck_signal_window IS 'OBS-04: last K stuck signals (jsonb array)'",
      "COMMENT ON COLUMN runs.stuck_signal_window IS NULL"
    )
  end
end
