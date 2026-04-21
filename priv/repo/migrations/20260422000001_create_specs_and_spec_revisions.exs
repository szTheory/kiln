defmodule Kiln.Repo.Migrations.CreateSpecsAndSpecRevisions do
  @moduledoc """
  Phase 5 (SPEC-01): versioned operator specs — `specs` (identity + title) and
  `spec_revisions` (append-only markdown bodies + `scenario_manifest_sha256`).

  `scenario_manifest_sha256` is nullable until the scenario compiler (Plan 05-02)
  fills it; when set it must be 64-char lowercase hex (sha256 digest of the
  canonical scenario bundle bytes).

  Privileges mirror `runs`: `kiln_app` gets INSERT/SELECT/UPDATE (no DELETE) —
  revisions are edited by creating new rows in a later UI iteration; for now
  UPDATE allows manifest hash backfill.
  """

  use Ecto.Migration

  def change do
    create table(:specs, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(:title, :text, null: false)
      timestamps(type: :utc_datetime_usec)
    end

    create table(:spec_revisions, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      add(
        :spec_id,
        references(:specs, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:body, :text, null: false)
      add(:scenario_manifest_sha256, :text)

      add(:inserted_at, :utc_datetime_usec, null: false)
    end

    execute(
      """
      ALTER TABLE spec_revisions
        ADD CONSTRAINT spec_revisions_scenario_manifest_sha256_format
        CHECK (
          scenario_manifest_sha256 IS NULL
          OR scenario_manifest_sha256 ~ '^[0-9a-f]{64}$'
        )
      """,
      "ALTER TABLE spec_revisions DROP CONSTRAINT IF EXISTS spec_revisions_scenario_manifest_sha256_format"
    )

    create(index(:spec_revisions, [:spec_id], name: :spec_revisions_spec_id_idx))
    create(index(:spec_revisions, [:inserted_at], name: :spec_revisions_inserted_at_idx))

    execute(
      "ALTER TABLE specs OWNER TO kiln_owner",
      "ALTER TABLE specs OWNER TO current_user"
    )

    execute(
      "ALTER TABLE spec_revisions OWNER TO kiln_owner",
      "ALTER TABLE spec_revisions OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON specs TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON specs FROM kiln_app"
    )

    execute(
      "GRANT INSERT, SELECT, UPDATE ON spec_revisions TO kiln_app",
      "REVOKE INSERT, SELECT, UPDATE ON spec_revisions FROM kiln_app"
    )

    execute(
      "REVOKE DELETE, TRUNCATE ON specs FROM kiln_app",
      ""
    )

    execute(
      "REVOKE DELETE, TRUNCATE ON spec_revisions FROM kiln_app",
      ""
    )
  end
end
