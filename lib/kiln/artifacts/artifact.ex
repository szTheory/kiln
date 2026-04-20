defmodule Kiln.Artifacts.Artifact do
  @moduledoc """
  Ecto schema for a row of the `artifacts` lookup table — one row per
  per-stage CAS-stored blob (D-79, D-80, D-81). The physical blob lives
  on-disk at `<cas_root>/<aa>/<bb>/<sha256>`; this row maps
  `(stage_run_id, name) -> sha256 + size + content_type` so the full
  CAS path is derivable without a second lookup.

  Invariants enforced at the changeset layer (matched by DB CHECK
  constraints in migration 20260419000004):

    * `sha256` is 64 lowercase hex digits.
    * `size_bytes` is in `0..52_428_800` (50 MB hard cap — D-75).
    * `content_type` is in the five-value controlled vocab that matches
      `priv/stage_contracts/v1/*.json $defs.artifact_ref.content_type`.

  The schema has **no `updated_at`** (D-81) — artifacts are semantically
  append-only. The DB grants `kiln_app` only INSERT + SELECT, so a raw
  `Repo.update_all/2` would fail at the privilege layer; the schema
  simply does not expose a row-level update path.

  The PK is Postgres-generated via `uuid_generate_v7()` (migration
  20260419000004); Ecto needs `read_after_writes: true` so it issues
  `RETURNING id` on INSERT — same pattern as `Kiln.Runs.Run`,
  `Kiln.Stages.StageRun`, and `Kiln.ExternalOperations.Operation`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  # Controlled vocab — mirrors priv/stage_contracts/v1/*.json artifact_ref
  # enum. Ecto.Enum values are atoms; storage is a text column.
  @content_types ~w(text/markdown text/plain application/x-diff application/json text/x-elixir)a

  # 50 MB hard cap (D-75).
  @max_size_bytes 52_428_800

  @derive {Jason.Encoder,
           only: [
             :id,
             :stage_run_id,
             :run_id,
             :name,
             :sha256,
             :size_bytes,
             :content_type,
             :schema_version,
             :producer_kind,
             :inserted_at
           ]}

  schema "artifacts" do
    field(:stage_run_id, :binary_id)
    field(:run_id, :binary_id)
    field(:name, :string)
    field(:sha256, :string)
    field(:size_bytes, :integer)
    field(:content_type, Ecto.Enum, values: @content_types)
    field(:schema_version, :integer, default: 1)
    field(:producer_kind, :string)

    # D-81: inserted_at ONLY (NO updated_at).
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required [:stage_run_id, :run_id, :name, :sha256, :size_bytes, :content_type]
  @optional [:schema_version, :producer_kind]

  @doc """
  Build a changeset for INSERT. The DB grants `kiln_app` only INSERT +
  SELECT on the `artifacts` table, so there is deliberately no UPDATE
  path — callers who need a new artifact must `put/4` a new row, never
  mutate an existing one.

  Wires the FK constraint names so `Repo.insert/1` surfaces a clean
  changeset error on violation rather than a raw `Postgrex.Error`, and
  the CHECK constraint names (sha256 format, content_type vocab) so a
  bypass attempt surfaces the same way.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:sha256, ~r/^[0-9a-f]{64}$/)
    |> validate_number(:size_bytes,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: @max_size_bytes
    )
    |> validate_inclusion(:content_type, @content_types)
    |> foreign_key_constraint(:stage_run_id)
    |> foreign_key_constraint(:run_id)
    |> unique_constraint([:stage_run_id, :name], name: :artifacts_stage_run_name_idx)
    |> check_constraint(:sha256, name: :artifacts_sha256_format)
    |> check_constraint(:size_bytes, name: :artifacts_size_nonneg)
    |> check_constraint(:content_type, name: :artifacts_content_type_check)
  end

  @doc "The five content-type atoms this schema accepts (D-75 artifact_ref enum)."
  @spec content_types() :: [atom(), ...]
  def content_types, do: @content_types

  @doc "The 50 MB hard cap (D-75) — exported for callers who want to pre-flight-check."
  @spec max_size_bytes() :: pos_integer()
  def max_size_bytes, do: @max_size_bytes
end
