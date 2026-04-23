defmodule Kiln.OperatorReadiness.ProbeRow do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}

  @type t :: %__MODULE__{
          id: integer(),
          anthropic_configured: boolean(),
          github_cli_ok: boolean(),
          docker_ok: boolean()
        }

  schema "operator_readiness" do
    field(:anthropic_configured, :boolean)
    field(:github_cli_ok, :boolean)
    field(:docker_ok, :boolean)
  end

  @fields [:anthropic_configured, :github_cli_ok, :docker_ok]

  def changeset(row, attrs) do
    row
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end
end
