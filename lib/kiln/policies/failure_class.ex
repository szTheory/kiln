defmodule Kiln.Policies.FailureClass do
  @moduledoc """
  Small closed vocabulary for stuck-window `failure_class` (OBS-04).
  """

  @atoms ~w(verify_timeout binary_crash test_failure unknown)a

  @spec cast(term()) :: {:ok, atom()} | :error
  def cast(v) when v in @atoms, do: {:ok, v}

  def cast(v) when is_binary(v) do
    case String.downcase(v) do
      "verify_timeout" -> {:ok, :verify_timeout}
      "binary_crash" -> {:ok, :binary_crash}
      "test_failure" -> {:ok, :test_failure}
      "unknown" -> {:ok, :unknown}
      _ -> :error
    end
  end

  def cast(_), do: :error
end
