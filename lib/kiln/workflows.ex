defmodule Kiln.Workflows do
  @moduledoc """
  Public API for the Workflows bounded context.

  Wraps the loader + compiler + checksum so callers don't reach into
  `Kiln.Workflows.Loader`, `Kiln.Workflows.Compiler`, or
  `Kiln.Workflows.Graph` directly:

    * `load/1` — path → `{:ok, %CompiledGraph{}}` or typed error
    * `load!/1` — path → `%CompiledGraph{}`; raises on error
    * `compile/1` — JSV-validated map → `{:ok, %CompiledGraph{}}` or
      typed error; exposed for unit tests that bypass the YAML layer
    * `checksum/1` — `%CompiledGraph{}` → sha256 hex (driven by D-94
      rehydration integrity assertion in Plan 02-07)

  See the module docs on `Kiln.Workflows.Loader` + `Kiln.Workflows.Compiler`
  for error-shape taxonomy and the 6 D-62 validators.
  """

  alias Kiln.Workflows.{CompiledGraph, Compiler, Loader}

  @spec load(Path.t()) ::
          {:ok, CompiledGraph.t()}
          | {:error, term()}
  defdelegate load(path), to: Loader

  @spec load!(Path.t()) :: CompiledGraph.t()
  defdelegate load!(path), to: Loader

  @spec compile(map()) ::
          {:ok, CompiledGraph.t()}
          | {:error, term()}
  defdelegate compile(raw), to: Compiler

  @doc """
  Returns the compiled graph's sha256 hex checksum (D-94). The
  checksum is computed by `Kiln.Workflows.Compiler.compile/1` over the
  shape-significant fields via `:erlang.term_to_binary(_, :deterministic)`
  + `:crypto.hash(:sha256, _)`.
  """
  @spec checksum(CompiledGraph.t()) :: String.t()
  def checksum(%CompiledGraph{checksum: sha}) when is_binary(sha), do: sha
end
