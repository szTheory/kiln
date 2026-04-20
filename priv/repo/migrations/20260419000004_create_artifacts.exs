defmodule Kiln.Repo.Migrations.CreateArtifacts do
  @moduledoc """
  Creates the `artifacts` Ecto lookup table for content-addressed-storage
  blobs (D-77, D-79, D-81). Blobs live on-disk at
  `priv/artifacts/cas/<aa>/<bb>/<sha>` (two-level fan-out); this table
  maps `(stage_run_id, name) -> sha256 + size + content_type` so the
  CAS path is derivable from the row's `sha256` without a second lookup.

  Invariants encoded here (D-81):

    * `sha256` is exactly 64 lowercase hex (CHECK constraint — the same
      regex the Ecto changeset enforces at the app boundary).
    * `size_bytes >= 0` (CHECK constraint — 50 MB ceiling is enforced in
      `Kiln.Artifacts.Artifact.changeset/2`).
    * `content_type` is in a controlled vocab matching the stage-contract
      `artifact_ref.content_type` enum (D-75).
    * `(stage_run_id, name)` is unique — one artifact name per stage
      attempt (second put with same name surfaces as a changeset error).
    * `stage_run_id` + `run_id` FKs both use `ON DELETE RESTRICT` — runs
      cannot be deleted while any artifacts reference them (forensic
      preservation; mirror of the `stage_runs -> runs` FK policy in
      migration 20260419000003).
    * Only `inserted_at` (no `updated_at`) — artifacts are semantically
      append-only (D-81).

  Privileges (D-48, D-81): `kiln_app` gets INSERT + SELECT only (NO
  UPDATE, NO DELETE) — mirrors the audit_events grant pattern. Artifacts
  are append-only by design; rewriting a row or dropping one would break
  the immutable-reference contract every cross-stage `artifact_ref`
  depends on.
  """

  use Ecto.Migration

  # Matches $defs.artifact_ref.content_type in priv/stage_contracts/v1/*.json
  # and Kiln.Artifacts.Artifact @content_types.
  @content_types ~w(text/markdown text/plain application/x-diff application/json text/x-elixir)

  def change do
    create table(:artifacts, primary_key: false) do
      add(:id, :binary_id,
        primary_key: true,
        default: fragment("uuid_generate_v7()"),
        null: false
      )

      # D-81 FKs — both ON DELETE RESTRICT (forensic preservation).
      add(
        :stage_run_id,
        references(:stage_runs, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(
        :run_id,
        references(:runs, type: :binary_id, on_delete: :restrict),
        null: false
      )

      # Name is a per-attempt identifier (e.g. "plan.md", "diff.patch");
      # NEVER used as a filesystem path component (CAS paths derive from
      # sha256 only — T1 mitigation in the plan threat model).
      add(:name, :text, null: false)

      # 64-char lowercase hex sha256 (CHECK below).
      add(:sha256, :text, null: false)

      # Total byte length of the blob (50 MB cap enforced at changeset
      # layer; DB CHECK only enforces non-negative).
      add(:size_bytes, :bigint, null: false)

      # Controlled vocab — matches stage_contracts artifact_ref enum.
      add(:content_type, :text, null: false)

      # Versioning for future payload-shape changes.
      add(:schema_version, :integer, null: false, default: 1)

      # Producer is the stage.kind that wrote this artifact
      # (e.g. "planning"); nullable because P2 scaffolding may not always
      # have a stage context.
      add(:producer_kind, :text)

      # D-81: inserted_at ONLY — artifacts are append-only semantically.
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    # sha256 format CHECK — 64 lowercase hex (mirror of the Ecto
    # changeset regex; defence-in-depth for any bypass path).
    execute(
      "ALTER TABLE artifacts ADD CONSTRAINT artifacts_sha256_format CHECK (sha256 ~ '^[0-9a-f]{64}$')",
      "ALTER TABLE artifacts DROP CONSTRAINT artifacts_sha256_format"
    )

    # size_bytes >= 0 CHECK (50 MB ceiling lives on the app changeset).
    execute(
      "ALTER TABLE artifacts ADD CONSTRAINT artifacts_size_nonneg CHECK (size_bytes >= 0)",
      "ALTER TABLE artifacts DROP CONSTRAINT artifacts_size_nonneg"
    )

    # content_type controlled vocab CHECK.
    ct_list = Enum.map_join(@content_types, ", ", &"'#{&1}'")

    execute(
      "ALTER TABLE artifacts ADD CONSTRAINT artifacts_content_type_check CHECK (content_type IN (#{ct_list}))",
      "ALTER TABLE artifacts DROP CONSTRAINT artifacts_content_type_check"
    )

    # Business identity: one name per stage attempt.
    create(
      unique_index(:artifacts, [:stage_run_id, :name],
        name: :artifacts_stage_run_name_idx
      )
    )

    # Per-run time-ordered lookup (drives "show all artifacts for this
    # run" UI + Phase 5 retention scans).
    create(
      index(:artifacts, [:run_id, :inserted_at],
        name: :artifacts_run_inserted_idx
      )
    )

    # Dedup / refcount lookup (drives D-83 GC refcount-based deletion).
    create(index(:artifacts, [:sha256], name: :artifacts_sha256_idx))

    # Owner + grants. D-81: append-only — INSERT + SELECT only; NO
    # UPDATE, NO DELETE. Mirrors the audit_events grant pattern (not the
    # external_operations UPDATE-allowed pattern) — once a row is
    # inserted, the sha256 → file binding is immutable forever.
    execute(
      "ALTER TABLE artifacts OWNER TO kiln_owner",
      "ALTER TABLE artifacts OWNER TO current_user"
    )

    execute(
      "GRANT INSERT, SELECT ON artifacts TO kiln_app",
      "REVOKE INSERT, SELECT ON artifacts FROM kiln_app"
    )

    # Belt-and-suspenders REVOKE — the GRANT above is the only
    # privilege granted, so this REVOKE is a documentation no-op.
    # Ship it explicitly so the append-only contract is legible in the
    # migration file (matches audit_events migration pattern).
    execute(
      "REVOKE UPDATE, DELETE, TRUNCATE ON artifacts FROM kiln_app",
      ""
    )
  end
end
