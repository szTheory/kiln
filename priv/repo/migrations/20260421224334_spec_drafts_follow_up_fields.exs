defmodule Kiln.Repo.Migrations.SpecDraftsFollowUpFields do
  @moduledoc """
  Phase 8 INTAKE-03: follow-up drafts filed from merged runs — `source_run_id`,
  `artifact_refs` (CAS metadata only), `operator_summary`, and `run_follow_up` source.
  """

  use Ecto.Migration

  def up do
    alter table(:spec_drafts) do
      add(:source_run_id, references(:runs, type: :binary_id, on_delete: :nilify_all))
      add(:artifact_refs, :map, null: false, default: fragment("'[]'::jsonb"))
      add(:operator_summary, :text)
    end

    create(index(:spec_drafts, [:source_run_id], name: :spec_drafts_source_run_id_idx))

    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (source IN ('freeform', 'markdown_import', 'github_issue', 'run_follow_up'))
    """)
  end

  def down do
    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (source IN ('freeform', 'markdown_import', 'github_issue'))
    """)

    drop(index(:spec_drafts, [:source_run_id], name: :spec_drafts_source_run_id_idx))

    alter table(:spec_drafts) do
      remove(:operator_summary)
      remove(:artifact_refs)
      remove(:source_run_id)
    end
  end
end
