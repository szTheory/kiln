defmodule Kiln.Repo.Migrations.AddAttachedRepoContinuityMetadata do
  use Ecto.Migration

  def change do
    alter table(:attached_repos) do
      add :last_selected_at, :utc_datetime_usec
      add :last_run_started_at, :utc_datetime_usec
    end

    create index(:attached_repos, [:last_selected_at])
    create index(:attached_repos, [:last_run_started_at])
  end
end
