defmodule Kiln.ExternalOperations.Operation do
  @moduledoc """
  Ecto schema for a row of the polymorphic `external_operations` intent table
  (D-14). Every external side-effect (LLM call, git push, Docker run, notify,
  secret resolve) funnels through this schema via `Kiln.ExternalOperations`'s
  two-phase `intent → action → completion` state machine.

  The `state` enum is locked at five values (D-16):

    * `:intent_recorded` — Phase A: caller declared intent; no external
      side-effect yet. Inserted atomically with an
      `external_op_intent_recorded` audit event (D-18).
    * `:action_in_flight` — Phase B: caller has started the external
      side-effect but has not yet observed the outcome.
    * `:completed` — Phase C(success): action returned cleanly; result
      payload captured; an `external_op_completed` audit event was written
      in the same transaction.
    * `:failed` — Phase C(fail): action threw or returned an error; an
      `external_op_failed` audit event was written in the same transaction.
    * `:abandoned` — terminal state for orphaned rows set by Phase 5's
      `StuckDetector` (intent without action-start after TTL).

  The PK is Postgres-generated via `uuid_generate_v7()` (migration 5); Ecto
  needs `read_after_writes: true` so it issues `RETURNING id` on INSERT.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @states [:intent_recorded, :action_in_flight, :completed, :failed, :abandoned]

  @derive {Jason.Encoder,
           only: [
             :id,
             :op_kind,
             :idempotency_key,
             :state,
             :schema_version,
             :intent_payload,
             :result_payload,
             :attempts,
             :run_id,
             :stage_id,
             :intent_recorded_at,
             :action_started_at,
             :completed_at
           ]}

  schema "external_operations" do
    field(:op_kind, :string)
    field(:idempotency_key, :string)
    field(:state, Ecto.Enum, values: @states, default: :intent_recorded)
    field(:schema_version, :integer, default: 1)
    field(:intent_payload, :map, default: %{})
    field(:result_payload, :map)
    field(:attempts, :integer, default: 0)
    field(:last_error, :map)
    field(:run_id, :binary_id)
    field(:stage_id, :binary_id)
    field(:intent_recorded_at, :utc_datetime_usec)
    field(:action_started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec)
  end

  @required [:op_kind, :idempotency_key]
  @optional [
    :state,
    :schema_version,
    :intent_payload,
    :result_payload,
    :attempts,
    :last_error,
    :run_id,
    :stage_id,
    :intent_recorded_at,
    :action_started_at,
    :completed_at
  ]

  @doc """
  Build a changeset for INSERT or UPDATE. Enforces the 5-value state
  domain via `Ecto.Enum` (app-side) — the DB CHECK constraint catches
  any bypass, but this gives a clean changeset-level error before the
  round-trip.
  """
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(op, attrs) do
    op
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:state, @states)
    |> unique_constraint(:idempotency_key, name: :external_operations_idempotency_key_idx)
  end

  @doc "The canonical 5-state enum (D-16), in the order state transitions flow."
  @spec states() ::
          [:intent_recorded | :action_in_flight | :completed | :failed | :abandoned, ...]
  def states, do: @states
end
