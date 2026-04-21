defmodule Kiln.Repo.Migrations.CreateSpecDrafts do
  @moduledoc """
  Phase 8 INTAKE: `spec_drafts` — mutable inbox rows before promotion into
  `specs` / `spec_revisions` (D-813..D-820).

  Partial unique indexes (D-818) prevent duplicate **open** GitHub imports by
  `github_node_id` or `(owner, repo, issue_number)`.
  """

  use Ecto.Migration

  def change do
    create table(:spec_drafts, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:title, :text, null: false)
      add(:body, :text, null: false)

      add(:source, :text, null: false)

      add(:inbox_state, :text, null: false, default: "open")

      add(:archived_at, :utc_datetime_usec)
      add(:promoted_spec_id, references(:specs, type: :binary_id, on_delete: :restrict))

      add(:github_node_id, :text)
      add(:github_owner, :text)
      add(:github_repo, :text)
      add(:github_issue_number, :integer)

      add(:etag, :text)
      add(:last_synced_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:spec_drafts, [:inbox_state], name: :spec_drafts_inbox_state_idx))
    create(index(:spec_drafts, [:inserted_at], name: :spec_drafts_inserted_at_idx))

    create(
      unique_index(:spec_drafts, [:github_node_id],
        name: :spec_drafts_open_github_node_id_uidx,
        where: "inbox_state = 'open' AND github_node_id IS NOT NULL"
      )
    )

    create(
      unique_index(:spec_drafts, [:github_owner, :github_repo, :github_issue_number],
        name: :spec_drafts_open_github_issue_uidx,
        where:
          "inbox_state = 'open' AND github_owner IS NOT NULL AND github_repo IS NOT NULL AND github_issue_number IS NOT NULL"
      )
    )

    execute(
      """
      ALTER TABLE spec_drafts
        ADD CONSTRAINT spec_drafts_inbox_state_values
        CHECK (inbox_state IN ('open', 'archived', 'promoted'))
      """,
      "ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_inbox_state_values"
    )

    execute(
      """
      ALTER TABLE spec_drafts
        ADD CONSTRAINT spec_drafts_source_values
        CHECK (source IN ('freeform', 'markdown_import', 'github_issue'))
      """,
      "ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values"
    )

    execute(
      "ALTER TABLE spec_drafts OWNER TO kiln_owner",
      "ALTER TABLE spec_drafts OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON spec_drafts TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON spec_drafts FROM kiln_app"
    )

    execute("REVOKE DELETE, TRUNCATE ON spec_drafts FROM kiln_app", "")
  end
end
