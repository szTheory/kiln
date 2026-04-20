defmodule Kiln.Stages.ContractRegistry do
  @moduledoc """
  Loads and caches JSV-compiled stage-input contracts at **module compile
  time** (D-73, D-74).

  Rationale: `Kiln.Stages.StageWorker.perform/1` validates the stage input
  envelope at the start of every stage dispatch (D-76 — the P4 token-bloat
  boundary defence). Loading, parsing, and building 5 JSV roots on each
  call would be wasteful. Because the schema files are versioned alongside
  source code, compiling them into a module attribute at build time gives
  `fetch/1` zero file IO and zero JSV build cost at runtime.

  The schema files are `@external_resource` entries so mix recompiles this
  module whenever any of the 5 JSON files under
  `priv/stage_contracts/v1/*.json` changes — no stale cache.

  `@build_opts` enable format validation (`formats: true`, per RESEARCH.md
  correction #1 / STACK.md D-100) so `"format": "uuid"` on `run_id` /
  `stage_run_id` is actually enforced.

  Registered kinds match the `kind` enum in
  `priv/workflow_schemas/v1/workflow.json`:
  `[:planning, :coding, :testing, :verifying, :merge]`.

  If a JSON file is missing (e.g. mid-implementation), `fetch/1` returns
  `{:error, :unknown_kind}` and the caller rejects the stage dispatch.
  """

  @schemas_dir Path.expand("../../../priv/stage_contracts/v1", __DIR__)

  @build_opts [
    default_meta: "https://json-schema.org/draft/2020-12/schema",
    formats: true
  ]

  @kinds ~w(planning coding testing verifying merge)a

  @schemas (for kind <- @kinds, into: %{} do
              path = Path.join(@schemas_dir, "#{kind}.json")

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
  Returns `{:ok, root}` with the JSV-compiled contract for a stage kind, or
  `{:error, :unknown_kind}` if the file wasn't present at compile time or
  the kind isn't one of `[:planning, :coding, :testing, :verifying, :merge]`.
  """
  @spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :unknown_kind}
  def fetch(kind) when is_atom(kind) do
    case Map.get(@schemas, kind, :missing) do
      :missing -> {:error, :unknown_kind}
      root -> {:ok, root}
    end
  end

  @doc """
  Returns the canonical ordered list of stage kinds this registry knows
  about. Matches the `kind` enum in the workflow dialect schema.
  """
  @spec kinds() :: [atom(), ...]
  def kinds, do: @kinds
end
