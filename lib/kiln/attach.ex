defmodule Kiln.Attach do
  @moduledoc """
  Public boundary for operator attach-source intake.
  """

  alias Kiln.Attach.Source
  alias Kiln.Attach.WorkspaceManager

  @type resolve_result :: {:ok, Source.t()} | {:error, Source.error()}
  @type hydrate_result :: {:ok, WorkspaceManager.result()} | {:error, WorkspaceManager.error()}

  @spec resolve_source(String.t(), keyword()) :: resolve_result()
  def resolve_source(raw_input, opts \\ []) when is_binary(raw_input) do
    Source.resolve(raw_input, opts)
  end

  @spec validate_source(String.t(), keyword()) :: resolve_result()
  def validate_source(raw_input, opts \\ []) when is_binary(raw_input) do
    Source.resolve(raw_input, opts)
  end

  @spec hydrate_workspace(Source.t(), keyword()) :: hydrate_result()
  def hydrate_workspace(%Source{} = source, opts \\ []) do
    WorkspaceManager.hydrate(source, opts)
  end
end
