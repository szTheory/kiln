defmodule Kiln.Workflows.SchemaRegistry do
  @moduledoc """
  Loads and caches the JSV-compiled workflow dialect schema at **module
  compile time** (D-66, D-73).

  Rationale: `Kiln.Workflows.load!/1` is called every time a workflow YAML is
  loaded (boot + every operator-triggered run). Loading, parsing, and
  building a JSV root on each call would be wasteful. Because the schema
  file is versioned alongside source code, compiling it into a module
  attribute at build time gives `fetch/1` zero file IO and zero JSV build
  cost at runtime.

  The schema file is an `@external_resource` so mix recompiles this module
  whenever `priv/workflow_schemas/v1/workflow.json` changes — no stale cache.

  The JSV `@build_opts` enable format validation (`formats: true`, per
  RESEARCH.md correction #1 / STACK.md D-100) so workflow authors get real
  feedback on `"format": "uri"`, `"format": "uuid"`, and related format
  assertions. Draft 2020-12's default meta-schema does NOT enable format
  validation on its own.

  If the JSON file is missing (e.g. mid-implementation of a future kind),
  `fetch/1` returns `{:error, :unknown_kind}` and the loader rejects the
  workflow with a typed error instead of raising at boot.
  """

  @schemas_dir Path.expand("../../../priv/workflow_schemas/v1", __DIR__)

  @build_opts [
    default_meta: "https://json-schema.org/draft/2020-12/schema",
    formats: true
  ]

  @kinds ~w(workflow)a

  @schemas (for kind <- @kinds, into: %{} do
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
  `{:error, :unknown_kind}` if the file wasn't present at compile time or
  the kind isn't in this registry.
  """
  @spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :unknown_kind}
  def fetch(kind) when is_atom(kind) do
    case Map.get(@schemas, kind, :missing) do
      :missing -> {:error, :unknown_kind}
      root -> {:ok, root}
    end
  end

  @doc """
  Returns the list of kinds this registry knows about, regardless of whether
  their backing JSON schema file loaded cleanly at compile time.
  """
  @spec kinds() :: [atom(), ...]
  def kinds, do: @kinds
end
