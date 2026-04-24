defmodule Kiln.Repo.Migrations.CreateAttachedRepos do
  @moduledoc """
  Creates durable attached-repo metadata for managed brownfield workspaces.
  """

  use Ecto.Migration

  @source_kinds ~w(local_path github_url)
  @repo_providers ~w(local github)

  def change do
    create table(:attached_repos, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:source_kind, :text, null: false)
      add(:repo_provider, :text, null: false)
      add(:repo_host, :text)
      add(:repo_owner, :text)
      add(:repo_name, :text, null: false)
      add(:repo_slug, :text, null: false)
      add(:canonical_input, :text, null: false)
      add(:canonical_repo_root, :text)
      add(:source_fingerprint, :text, null: false)
      add(:workspace_key, :text, null: false)
      add(:workspace_path, :text, null: false)
      add(:remote_url, :text)
      add(:clone_url, :text)
      add(:default_branch, :text)
      add(:base_branch, :text, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    source_kinds_list = Enum.map_join(@source_kinds, ", ", &"'#{&1}'")
    repo_providers_list = Enum.map_join(@repo_providers, ", ", &"'#{&1}'")

    execute(
      """
      ALTER TABLE attached_repos
        ADD CONSTRAINT attached_repos_source_kind_check
        CHECK (source_kind IN (#{source_kinds_list}))
      """,
      "ALTER TABLE attached_repos DROP CONSTRAINT IF EXISTS attached_repos_source_kind_check"
    )

    execute(
      """
      ALTER TABLE attached_repos
        ADD CONSTRAINT attached_repos_repo_provider_check
        CHECK (repo_provider IN (#{repo_providers_list}))
      """,
      "ALTER TABLE attached_repos DROP CONSTRAINT IF EXISTS attached_repos_repo_provider_check"
    )

    create(
      unique_index(:attached_repos, [:source_fingerprint], name: :attached_repos_source_fingerprint_idx)
    )

    create(unique_index(:attached_repos, [:workspace_key], name: :attached_repos_workspace_key_idx))

    create(index(:attached_repos, [:repo_slug], name: :attached_repos_repo_slug_idx))

    execute(
      "ALTER TABLE attached_repos OWNER TO kiln_owner",
      "ALTER TABLE attached_repos OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON attached_repos TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON attached_repos FROM kiln_app"
    )

    execute(
      "REVOKE DELETE, TRUNCATE ON attached_repos FROM kiln_app",
      ""
    )
  end
end
