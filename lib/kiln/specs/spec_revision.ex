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
    belongs_to(:attached_repo, Kiln.Attach.AttachedRepo, foreign_key: :attached_repo_id)

    field(:body, :string)
    field(:scenario_manifest_sha256, :string)
    field(:request_kind, Ecto.Enum, values: [:feature, :bugfix])
    field(:change_summary, :string)
    field(:acceptance_criteria, {:array, :string}, default: [])
    field(:out_of_scope, {:array, :string}, default: [])

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [
      :spec_id,
      :body,
      :scenario_manifest_sha256,
      :attached_repo_id,
      :request_kind,
      :change_summary,
      :acceptance_criteria,
      :out_of_scope
    ])
    |> validate_required([:spec_id, :body])
    |> normalize_manifest_field()
    |> validate_attached_request_fields()
    |> validate_format(:scenario_manifest_sha256, ~r/^[0-9a-f]{64}$/,
      message: "must be 64-char lowercase hex sha256"
    )
    |> foreign_key_constraint(:spec_id)
    |> foreign_key_constraint(:attached_repo_id)
  end

  defp normalize_manifest_field(changeset) do
    case get_change(changeset, :scenario_manifest_sha256) do
      "" -> put_change(changeset, :scenario_manifest_sha256, nil)
      _ -> changeset
    end
  end

  defp validate_attached_request_fields(changeset) do
    if attached_request_present?(changeset) do
      changeset
      |> validate_required([:attached_repo_id, :request_kind, :change_summary])
      |> validate_change(:acceptance_criteria, fn :acceptance_criteria, value ->
        if Enum.empty?(value || []) do
          [acceptance_criteria: "must include at least one item"]
        else
          []
        end
      end)
    else
      changeset
    end
  end

  defp attached_request_present?(changeset) do
    not is_nil(get_field(changeset, :attached_repo_id)) or
      not is_nil(get_field(changeset, :request_kind)) or
      not is_nil(get_field(changeset, :change_summary)) or
      get_field(changeset, :acceptance_criteria, []) != [] or
      get_field(changeset, :out_of_scope, []) != []
  end
end
