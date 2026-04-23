defmodule Kiln.Runs.PostMortem do
  @moduledoc """
  Ecto schema for `run_postmortems` — merged-run post-mortem snapshot (Phase 19).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:run_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  @statuses ~w(pending complete failed)a

  schema "run_postmortems" do
    field(:schema_version, :string, default: "1")
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:source_watermark, :string, default: "")
    field(:terminal_reason, :string)
    field(:total_usd_band, :string)
    field(:workflow_id, :string)
    field(:workflow_version, :string)
    field(:scenario_outcome, :string)
    field(:snapshot, :map, default: %{})
    field(:artifact_id, :binary_id)

    timestamps(type: :utc_datetime_usec)
  end

  @castable [
    :run_id,
    :schema_version,
    :status,
    :source_watermark,
    :terminal_reason,
    :total_usd_band,
    :workflow_id,
    :workflow_version,
    :scenario_outcome,
    :snapshot,
    :artifact_id
  ]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(struct_or_cs, attrs) do
    struct_or_cs
    |> cast(attrs, @castable)
    |> validate_required([:run_id, :schema_version, :status, :source_watermark, :snapshot])
  end
end
