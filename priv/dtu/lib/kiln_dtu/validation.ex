defmodule KilnDtu.Validation do
  @moduledoc """
  Send-time response validation hook for the pinned GitHub contract.

  Phase 3 keeps this non-blocking. The full endpoint-specific JSV root
  build and weekly drift check land in Phase 6.
  """

  @contract_path Path.expand("../../contracts/github/api.github.com.2026-04.json", __DIR__)
  @external_resource @contract_path

  @contract_path
  |> File.read!()
  |> Jason.decode!()

  @spec contract_version() :: String.t()
  def contract_version, do: "2026-04"

  @spec validate(String.t(), String.t(), non_neg_integer(), term()) :: :ok
  def validate(_method, _path, _status, _body), do: :ok
end
