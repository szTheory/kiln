defmodule Kiln.Audit.Event do
  @moduledoc """
  Ecto schema for `audit_events` rows.

  The primary key is assigned by the Postgres `uuid_generate_v7()` default
  (not Ecto-side), so `autogenerate: false` is set explicitly. This keeps
  insertion order aligned with wall-clock time — an invariant Phase 7's
  audit-ledger replay view relies on.

  `event_kind` is declared as an `Ecto.Enum` over
  `Kiln.Audit.EventKind.values/0`, so any atom outside the 22-value taxonomy
  is rejected at changeset time — before the INSERT reaches the Postgres
  CHECK constraint. Two layers of enforcement (app + DB) with the same SSOT.

  `schema_version` supports future payload evolution: when a kind's
  JSON-schema shape changes in a backward-incompatible way, bump this
  integer and add `priv/audit_schemas/v{N}/{kind}.json`. `Kiln.Audit` then
  dispatches on `{kind, schema_version}` when validating.
  """

  use Ecto.Schema

  alias Kiln.Audit.EventKind

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :event_kind,
             :actor_id,
             :actor_role,
             :run_id,
             :stage_id,
             :correlation_id,
             :causation_id,
             :schema_version,
             :payload,
             :occurred_at
           ]}

  schema "audit_events" do
    field(:event_kind, Ecto.Enum, values: EventKind.values())
    field(:actor_id, :string)
    field(:actor_role, :string)
    field(:run_id, :binary_id)
    field(:stage_id, :binary_id)
    field(:correlation_id, :binary_id)
    field(:causation_id, :binary_id)
    field(:schema_version, :integer, default: 1)
    field(:payload, :map, default: %{})
    field(:occurred_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
