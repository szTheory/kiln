defmodule Kiln.Repo.Migrations.AddOperatorNudgeLastAuditIdToRuns do
  @moduledoc """
  Phase 19 — operator nudge consumption cursor (D-1924). Nullable `binary_id`
  without FK to avoid circular migration ordering with `audit_events`.
  """

  use Ecto.Migration

  def change do
    alter table(:runs) do
      add(:operator_nudge_last_audit_id, :binary_id)
    end

    create(index(:runs, [:operator_nudge_last_audit_id]))
  end
end
