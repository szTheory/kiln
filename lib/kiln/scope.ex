defmodule Kiln.Scope do
  @moduledoc """
  Operator scope passed through Phoenix + LiveView. Expands in Phases 7-8.
  P1: stub with correlation_id so logger_json metadata has a stable key.
  """

  defstruct [:operator, :correlation_id, :started_at]

  @type t :: %__MODULE__{
          operator: :local,
          correlation_id: String.t(),
          started_at: DateTime.t()
        }

  @doc "Builds a local-operator scope with a fresh correlation_id."
  @spec local() :: t()
  def local do
    %__MODULE__{
      operator: :local,
      correlation_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }
  end
end
