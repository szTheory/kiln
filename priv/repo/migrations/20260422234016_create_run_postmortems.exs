defmodule Kiln.Repo.Migrations.CreateRunPostmortems do
  @moduledoc """
  Phase 19 — hybrid `run_postmortems` store (1:1 with `runs`, D-1901).
  """

  use Ecto.Migration

  @statuses ~w(pending complete failed)

  def change do
    create table(:run_postmortems, primary_key: false) do
      add(:run_id, references(:runs, type: :binary_id, on_delete: :delete_all),
        primary_key: true,
        null: false
      )

      add(:schema_version, :text, null: false, default: "1")
      add(:status, :text, null: false, default: "pending")
      add(:source_watermark, :text, null: false, default: "")

      add(:terminal_reason, :text)
      add(:total_usd_band, :text)
      add(:workflow_id, :text)
      add(:workflow_version, :text)
      add(:scenario_outcome, :text)

      add(:snapshot, :map, null: false, default: %{})

      add(:artifact_id, references(:artifacts, type: :binary_id, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    statuses = Enum.map_join(@statuses, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE run_postmortems
        ADD CONSTRAINT run_postmortems_status_check
        CHECK (status IN (#{statuses}))
      """,
      "ALTER TABLE run_postmortems DROP CONSTRAINT run_postmortems_status_check"
    )

    create(index(:run_postmortems, [:status]))
  end
end
