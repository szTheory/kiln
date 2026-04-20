defmodule Kiln.WorkUnits.WorkUnitEvent do
  @moduledoc """
  Ecto schema for append-only `work_unit_events` rows (AGENT-04).

  Event taxonomy is fixed for Phase 4; extend via paired migration +
  module update.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @event_kinds ~w(created claimed blocked unblocked completed closed)a
  @actor_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)a

  schema "work_unit_events" do
    field(:work_unit_id, :binary_id)
    field(:event_kind, Ecto.Enum, values: @event_kinds)
    field(:actor_role, Ecto.Enum, values: @actor_roles)
    field(:payload, :map, default: %{})
    field(:occurred_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required [:work_unit_id, :event_kind]
  @optional [:actor_role, :payload, :occurred_at]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:event_kind, @event_kinds)
    |> foreign_key_constraint(:work_unit_id, name: :work_unit_events_work_unit_id_fkey)
    |> check_constraint(:event_kind, name: :work_unit_events_event_kind_check)
    |> check_constraint(:actor_role, name: :work_unit_events_actor_role_check)
  end

  @doc "Minimum Phase 4 event kinds for the work-unit ledger."
  @spec event_kinds() :: [atom(), ...]
  def event_kinds, do: @event_kinds
end
