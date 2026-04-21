defmodule Kiln.Workflows.WorkflowDefinitionSnapshot do
  @moduledoc """
  Postgres snapshot of a successfully loaded workflow YAML (UI-03 / D-716).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  schema "workflow_definition_snapshots" do
    field(:workflow_id, :string)
    field(:version, :integer)
    field(:compiled_checksum, :string)
    field(:yaml_body, :string)
    field(:truncated, :boolean, default: false)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:workflow_id, :version, :compiled_checksum, :yaml_body, :truncated])
    |> validate_required([:workflow_id, :version, :compiled_checksum, :truncated])
    |> validate_length(:compiled_checksum, is: 64)
  end
end
