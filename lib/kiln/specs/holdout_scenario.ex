defmodule Kiln.Specs.HoldoutScenario do
  @moduledoc """
  Ecto schema for `holdout_scenarios` — verifier-only scenario bodies (SPEC-04).

  Inserts are expected from `kiln_owner`/migration paths or the dedicated
  verifier DB role — **not** from the `kiln_app` runtime role (no table GRANT).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "holdout_scenarios" do
    belongs_to(:spec, Kiln.Specs.Spec, foreign_key: :spec_id)

    field(:label, :string)
    field(:body, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(row, attrs) do
    row
    |> cast(attrs, [:spec_id, :label, :body])
    |> validate_required([:spec_id, :label, :body])
    |> foreign_key_constraint(:spec_id)
    |> unique_constraint([:spec_id, :label], name: :holdout_scenarios_spec_label_uidx)
  end
end
