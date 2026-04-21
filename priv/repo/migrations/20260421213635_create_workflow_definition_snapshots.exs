defmodule Kiln.Repo.Migrations.CreateWorkflowDefinitionSnapshots do
  use Ecto.Migration

  def change do
    create table(:workflow_definition_snapshots, primary_key: false) do
      add :id, :uuid,
        null: false,
        default: fragment("uuid_generate_v7()"),
        primary_key: true

      add :workflow_id, :string, null: false
      add :version, :integer, null: false
      add :compiled_checksum, :string, null: false, size: 64
      add :yaml_body, :text
      add :truncated, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:workflow_definition_snapshots, [:workflow_id, :inserted_at])
  end
end
