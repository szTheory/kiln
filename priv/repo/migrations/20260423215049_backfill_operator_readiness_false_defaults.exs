defmodule Kiln.Repo.Migrations.BackfillOperatorReadinessFalseDefaults do
  use Ecto.Migration

  def up do
    alter table(:operator_readiness) do
      modify(:anthropic_configured, :boolean, null: false, default: false)
      modify(:github_cli_ok, :boolean, null: false, default: false)
      modify(:docker_ok, :boolean, null: false, default: false)
    end

    execute("""
    UPDATE operator_readiness
    SET anthropic_configured = false,
        github_cli_ok = false,
        docker_ok = false
    WHERE id = 1
    """)
  end

  def down do
    execute("""
    UPDATE operator_readiness
    SET anthropic_configured = true,
        github_cli_ok = true,
        docker_ok = true
    WHERE id = 1
    """)

    alter table(:operator_readiness) do
      modify(:anthropic_configured, :boolean, null: false, default: true)
      modify(:github_cli_ok, :boolean, null: false, default: true)
      modify(:docker_ok, :boolean, null: false, default: true)
    end
  end
end
