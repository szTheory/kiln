defmodule Kiln.WorkUnits.Dependency do
  @moduledoc """
  Ecto schema for `work_unit_dependencies` — directed blocker edges
  (`blocker` → `blocked`) between work units.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "work_unit_dependencies" do
    field(:blocked_work_unit_id, :binary_id)
    field(:blocker_work_unit_id, :binary_id)

    timestamps(type: :utc_datetime_usec)
  end

  @required [:blocked_work_unit_id, :blocker_work_unit_id]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(dep, attrs) do
    dep
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_cross_ids()
    |> foreign_key_constraint(:blocked_work_unit_id,
      name: :work_unit_dependencies_blocked_work_unit_id_fkey
    )
    |> foreign_key_constraint(:blocker_work_unit_id,
      name: :work_unit_dependencies_blocker_work_unit_id_fkey
    )
    |> unique_constraint([:blocked_work_unit_id, :blocker_work_unit_id],
      name: :work_unit_dependencies_blocked_blocker_uidx
    )
    |> check_constraint(:blocked_work_unit_id,
      name: :work_unit_dependencies_no_self_block
    )
  end

  defp validate_cross_ids(changeset) do
    blocked = get_field(changeset, :blocked_work_unit_id)
    blocker = get_field(changeset, :blocker_work_unit_id)

    if blocked && blocker && blocked == blocker do
      add_error(changeset, :blocker_work_unit_id, "must not equal blocked work unit")
    else
      changeset
    end
  end
end
