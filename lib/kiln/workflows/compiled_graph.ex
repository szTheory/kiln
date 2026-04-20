defmodule Kiln.Workflows.CompiledGraph do
  @moduledoc """
  In-memory representation of a validated + topologically-sorted workflow.

  Produced by `Kiln.Workflows.Compiler.compile/1` after JSV Draft 2020-12
  schema validation and the 6 D-62 Elixir-side validators. Downstream
  consumers:

    * `Kiln.Runs.RunDirector` (Plan 02-07) — `checksum` is asserted against
      `runs.workflow_checksum` on rehydration (D-94 integrity mechanism).
    * `Kiln.Stages.StageWorker` (Plan 02-08 / Phase 3) — per-stage dispatch
      lookup via `stages_by_id`.
    * `Kiln.Runs.Transitions` (Plan 02-06) — consumes `stages` ordered list
      + `entry_node` to start a run at the correct stage.

  Fields:

    * `id` — workflow identifier (D-55 regex `^[a-z][a-z0-9_]{2,63}$`)
    * `version` — positive integer, composite key `{id, version}` (D-55)
    * `api_version` — const `"kiln.dev/v1"` today (D-55 migration lever)
    * `metadata` — free-form `description`/`author`/`tags` (D-55)
    * `caps` — hard caps (D-56) frozen at load time
    * `model_profile` — string enum per D-57; stored as string (no atom
      table entry to avoid enum drift between schema and code)
    * `stages` — topologically sorted list; `List.first/1` is always
      `entry_node`
    * `stages_by_id` — O(1) lookup map `%{String.t() => stage()}`
    * `entry_node` — the unique stage id with `depends_on: []` (D-62 v1)
    * `checksum` — 64-char lowercase hex sha256 over a canonical
      term-to-binary representation of the significant fields (D-94)

  The struct is immutable; any change requires recompiling from YAML.
  """

  @type stage :: %{
          required(:id) => String.t(),
          required(:kind) => atom(),
          required(:agent_role) => atom(),
          required(:depends_on) => [String.t()],
          required(:timeout_seconds) => pos_integer(),
          required(:retry_policy) => map(),
          required(:sandbox) => atom(),
          optional(:model_preference) => String.t() | nil,
          optional(:on_failure) =>
            nil | :escalate | %{action: :route, to: String.t(), attach: String.t()}
        }

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          api_version: String.t(),
          metadata: map(),
          caps: map(),
          model_profile: String.t(),
          stages: [stage()],
          stages_by_id: %{String.t() => stage()},
          entry_node: String.t(),
          checksum: String.t()
        }

  @enforce_keys [
    :id,
    :version,
    :api_version,
    :caps,
    :model_profile,
    :stages,
    :stages_by_id,
    :entry_node,
    :checksum
  ]

  defstruct [
    :id,
    :version,
    :api_version,
    :caps,
    :model_profile,
    :stages,
    :stages_by_id,
    :entry_node,
    :checksum,
    metadata: %{}
  ]
end
