defmodule Kiln.Agents.Prompt do
  @moduledoc """
  Provider-agnostic LLM prompt envelope (D-102 / AGENT-01). Adapters
  translate this to their native shape inside `complete/2` / `stream/2`.

  Minimum-viable shape for Phase 3 — Phase 4 (work units / agent roles)
  may extend with role-specific tool-call metadata. P3 keeps the surface
  narrow per the "Claude's discretion" policy in 03-CONTEXT.md: only
  fields explicit consumers need right now.

  ## Redaction boundary (D-133 Layer 1)

  `:metadata` is the carrier for:

    * `kiln_ctx` — the `%Kiln.Telemetry.pack_ctx/0`-produced map that
      carries Logger metadata across Oban boundaries.
    * `%Kiln.Secrets.Ref{}` — reference values that resolve to a raw
      secret string only inside `Kiln.Secrets.reveal!/1`.

  Therefore `:metadata` is EXCLUDED from `@derive {Jason.Encoder, ...}` —
  serialising it would leak a secret reference into JSON payloads that
  cross process / network boundaries. `%Prompt{}` tests in
  `test/kiln/agents/prompt_test.exs` assert this exclusion.
  """

  @derive {Jason.Encoder, only: [:messages, :system, :model, :max_tokens, :temperature, :tools]}

  defstruct [
    :model,
    system: nil,
    messages: [],
    max_tokens: 4096,
    temperature: 1.0,
    tools: [],
    metadata: %{}
  ]

  @type message :: %{required(:role) => :user | :assistant, required(:content) => term()}
  @type tool :: map()

  @type t :: %__MODULE__{
          model: String.t() | nil,
          system: String.t() | nil,
          messages: [message()],
          max_tokens: pos_integer(),
          temperature: float(),
          tools: [tool()],
          metadata: map()
        }
end
