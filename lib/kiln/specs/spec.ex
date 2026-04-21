defmodule Kiln.Specs.Spec do
  @moduledoc """
  Ecto schema for `specs` — stable identity for an operator-authored markdown
  spec (Phase 5). Versioned bodies live in `spec_revisions`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "specs" do
    field(:title, :string)

    has_many(:revisions, Kiln.Specs.SpecRevision, foreign_key: :spec_id)

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(spec, attrs) do
    spec
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
