defmodule Kiln.Repo.Migrations.AddMetadataToAuditEvents do
  use Ecto.Migration

  def change do
    alter table(:audit_events) do
      add :metadata, :map, null: false, default: %{}
    end
  end
end
