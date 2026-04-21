defmodule Kiln.Repo.Migrations.RunsGithubDeliverySnapshot do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      # Nullable jsonb — stores last PR + checks summary for operator surfaces (Phase 7).
      add :github_delivery_snapshot, :map, null: false, default: %{}
    end
  end
end
