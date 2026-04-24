defmodule Kiln.Repo.Migrations.AddAttachedRequestRunLinks do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add(:attached_repo_id, references(:attached_repos, type: :binary_id, on_delete: :nothing))
      add(:spec_id, references(:specs, type: :binary_id, on_delete: :nothing))
      add(:spec_revision_id, references(:spec_revisions, type: :binary_id, on_delete: :nothing))
    end

    create(index(:runs, [:attached_repo_id], name: :runs_attached_repo_id_idx))
    create(index(:runs, [:spec_id], name: :runs_spec_id_idx))
    create(index(:runs, [:spec_revision_id], name: :runs_spec_revision_id_idx))
  end
end
