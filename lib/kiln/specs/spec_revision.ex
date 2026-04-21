defmodule Kiln.Specs.SpecRevision do
  @moduledoc """
  Ecto schema for `spec_revisions` — append-only-ish markdown bodies for a
  `specs` row plus `scenario_manifest_sha256` (nullable until compile).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "spec_revisions" do
    belongs_to(:spec, Kiln.Specs.Spec, foreign_key: :spec_id)

    field(:body, :string)
    field(:scenario_manifest_sha256, :string)

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [:spec_id, :body, :scenario_manifest_sha256])
    |> validate_required([:spec_id, :body])
    |> normalize_manifest_field()
    |> validate_format(:scenario_manifest_sha256, ~r/^[0-9a-f]{64}$/,
      message: "must be 64-char lowercase hex sha256"
    )
    |> foreign_key_constraint(:spec_id)
  end

  defp normalize_manifest_field(changeset) do
    case get_change(changeset, :scenario_manifest_sha256) do
      "" -> put_change(changeset, :scenario_manifest_sha256, nil)
      _ -> changeset
    end
  end
end
