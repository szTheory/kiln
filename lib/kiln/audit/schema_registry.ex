defmodule Kiln.Audit.SchemaRegistry do
  @moduledoc """
  Loads and caches JSV-compiled schemas for each `event_kind` at **module
  compile time**.

  Rationale: `Kiln.Audit.append/1` is on the hot path for every state
  transition in every run. Loading, parsing, and building a JSV root for
  22 schemas on each call would be wasteful. Because the schema files are
  versioned alongside source code, compiling them into a module attribute
  at build time gives `fetch/1` zero file IO and zero JSV build cost at
  runtime.

  The schemas directory is an `@external_resource` so mix recompiles this
  module whenever any of the 22 JSON files change — no stale cache.

  If a JSON file is missing (e.g. mid-implementation of a future kind),
  `fetch/1` returns `{:error, :schema_missing}` and `Kiln.Audit.append/1`
  rejects the insert with `{:error, {:audit_schema_missing, kind}}`
  instead of raising at boot.
  """

  alias Kiln.Audit.EventKind

  @schemas_dir Path.expand("../../../priv/audit_schemas/v1", __DIR__)

  @build_opts [default_meta: "https://json-schema.org/draft/2020-12/schema"]

  @schemas (for kind <- EventKind.values(), into: %{} do
              path = Path.join(@schemas_dir, "#{kind}.json")

              # Mark every schema file as an external resource so a change
              # triggers recompile of this module.
              @external_resource path

              case File.read(path) do
                {:ok, json} ->
                  raw = Jason.decode!(json)
                  root = JSV.build!(raw, @build_opts)
                  {kind, root}

                {:error, :enoent} ->
                  {kind, :missing}
              end
            end)

  @doc """
  Returns `{:ok, root}` with the JSV-compiled schema for a kind, or
  `{:error, :schema_missing}` if the file wasn't present at compile time.
  """
  @spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :schema_missing}
  def fetch(kind) when is_atom(kind) do
    case Map.get(@schemas, kind, :missing) do
      :missing -> {:error, :schema_missing}
      root -> {:ok, root}
    end
  end

  @doc """
  Returns the list of kinds that have a loaded schema (used by diagnostic
  tooling and the BootChecks test in Plan 01-06).
  """
  @spec loaded_kinds() :: [atom()]
  def loaded_kinds do
    @schemas
    |> Enum.reject(fn {_kind, root} -> root == :missing end)
    |> Enum.map(fn {kind, _root} -> kind end)
  end
end
