defmodule Kiln.Repo.Migrations.AddAttachedRepoIntakeFields do
  use Ecto.Migration

  def up do
    alter table(:spec_drafts) do
      add(:attached_repo_id, references(:attached_repos, type: :binary_id, on_delete: :restrict))
      add(:request_kind, :text)
      add(:change_summary, :text)
      add(:acceptance_criteria, {:array, :text}, null: false, default: [])
      add(:out_of_scope, {:array, :text}, null: false, default: [])
    end

    alter table(:spec_revisions) do
      add(:attached_repo_id, references(:attached_repos, type: :binary_id, on_delete: :restrict))
      add(:request_kind, :text)
      add(:change_summary, :text)
      add(:acceptance_criteria, {:array, :text}, null: false, default: [])
      add(:out_of_scope, {:array, :text}, null: false, default: [])
    end

    create(index(:spec_drafts, [:attached_repo_id], name: :spec_drafts_attached_repo_id_idx))

    create(
      index(:spec_revisions, [:attached_repo_id], name: :spec_revisions_attached_repo_id_idx)
    )

    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (
        source IN (
          'freeform',
          'markdown_import',
          'github_issue',
          'run_follow_up',
          'template',
          'attached_repo_intake'
        )
      )
    """)

    # source IN includes attached_repo_intake for attached brownfield drafts.

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_request_kind_values
      CHECK (request_kind IS NULL OR request_kind IN ('feature', 'bugfix'))
    """)

    execute("""
    ALTER TABLE spec_revisions
      ADD CONSTRAINT spec_revisions_request_kind_values
      CHECK (request_kind IS NULL OR request_kind IN ('feature', 'bugfix'))
    """)
  end

  def down do
    execute(
      "ALTER TABLE spec_revisions DROP CONSTRAINT IF EXISTS spec_revisions_request_kind_values"
    )

    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_request_kind_values")
    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (
        source IN (
          'freeform',
          'markdown_import',
          'github_issue',
          'run_follow_up',
          'template'
        )
      )
    """)

    drop(index(:spec_revisions, [:attached_repo_id], name: :spec_revisions_attached_repo_id_idx))
    drop(index(:spec_drafts, [:attached_repo_id], name: :spec_drafts_attached_repo_id_idx))

    alter table(:spec_revisions) do
      remove(:out_of_scope)
      remove(:acceptance_criteria)
      remove(:change_summary)
      remove(:request_kind)
      remove(:attached_repo_id)
    end

    alter table(:spec_drafts) do
      remove(:out_of_scope)
      remove(:acceptance_criteria)
      remove(:change_summary)
      remove(:request_kind)
      remove(:attached_repo_id)
    end
  end
end
