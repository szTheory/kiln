defmodule Kiln.Repo.Migrations.CreateOperatorReadiness do
  @moduledoc """
  Phase 8 BLOCK-04 — singleton row tracking operator environment probes.
  """

  use Ecto.Migration

  def change do
    create table(:operator_readiness, primary_key: false) do
      add(:id, :smallint, primary_key: true, default: 1)
      add(:anthropic_configured, :boolean, null: false, default: true)
      add(:github_cli_ok, :boolean, null: false, default: true)
      add(:docker_ok, :boolean, null: false, default: true)
    end

    execute(
      "INSERT INTO operator_readiness (id, anthropic_configured, github_cli_ok, docker_ok) VALUES (1, true, true, true)",
      "DELETE FROM operator_readiness WHERE id = 1"
    )

    execute(
      "ALTER TABLE operator_readiness OWNER TO kiln_owner",
      "ALTER TABLE operator_readiness OWNER TO current_user"
    )

    execute(
      "GRANT SELECT, INSERT, UPDATE ON operator_readiness TO kiln_app",
      "REVOKE SELECT, INSERT, UPDATE ON operator_readiness FROM kiln_app"
    )
  end
end
