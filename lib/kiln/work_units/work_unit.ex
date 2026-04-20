defmodule Kiln.WorkUnits.WorkUnit do
  @moduledoc """
  Ecto schema for `work_units` — the mutable coordination read model for
  Phase 4 / AGENT-04.

  Current state lives here; append-only history is `work_unit_events`.
  PK is assigned by Postgres `uuid_generate_v7()`; Ecto uses
  `read_after_writes: true` on INSERT.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @agent_roles ~w(planner coder tester reviewer uiux qa_verifier mayor)a
  @states ~w(open blocked in_progress completed closed)a

  schema "work_units" do
    field(:run_id, :binary_id)
    field(:agent_role, Ecto.Enum, values: @agent_roles)
    field(:state, Ecto.Enum, values: @states, default: :open)
    field(:priority, :integer, default: 100)
    field(:blockers_open_count, :integer, default: 0)
    field(:claimed_by_role, Ecto.Enum, values: @agent_roles)
    field(:claimed_at, :utc_datetime_usec)
    field(:closed_at, :utc_datetime_usec)
    field(:input_payload, :map, default: %{})
    field(:result_payload, :map, default: %{})
    field(:external_ref, :string)

    timestamps(type: :utc_datetime_usec)
  end

  @required [:run_id, :agent_role]
  @optional [
    :state,
    :priority,
    :blockers_open_count,
    :claimed_by_role,
    :claimed_at,
    :closed_at,
    :input_payload,
    :result_payload,
    :external_ref
  ]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(work_unit, attrs) do
    work_unit
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:agent_role, @agent_roles)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:blockers_open_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:run_id, name: :work_units_run_id_fkey)
    |> check_constraint(:agent_role, name: :work_units_agent_role_check)
    |> check_constraint(:state, name: :work_units_state_check)
    |> check_constraint(:priority, name: :work_units_priority_nonneg)
    |> check_constraint(:blockers_open_count, name: :work_units_blockers_open_nonneg)
    |> check_constraint(:claimed_by_role, name: :work_units_claimed_by_role_check)
  end

  @doc "The seven agent roles (D-58), mirrored on `stage_runs`."
  @spec agent_roles() :: [atom(), ...]
  def agent_roles, do: @agent_roles

  @doc "Work-unit lifecycle states stored on the read model."
  @spec states() :: [atom(), ...]
  def states, do: @states
end
