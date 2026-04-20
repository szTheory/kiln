defmodule Kiln.Agents.Adapter do
  @moduledoc """
  Behaviour every LLM adapter implements (D-101 / D-102 / AGENT-01).

  Phase 3 ships:

    * `Kiln.Agents.Adapter.Anthropic` — LIVE via Anthropix 0.6.2
    * `Kiln.Agents.Adapter.OpenAI` — scaffolded on Req (~200 LOC) with
      Mox contract tests + `@tag :live_openai` live-burn gate
    * `Kiln.Agents.Adapter.Google` — scaffolded
    * `Kiln.Agents.Adapter.Ollama` — scaffolded

  Callers invoke adapters via `Kiln.Agents.complete/3` / `stream/3`
  (this module's context facade), which Wave 2/3 extends with
  `Kiln.ModelRegistry.adapter_for/1` resolution and `BudgetGuard`
  pre-flight checks.

  ## Callback contract (D-102)

  All 4 callbacks are REQUIRED — no `@optional_callbacks`. The
  `json_schema_mode` flag on `capabilities/0` is the linchpin for
  `Kiln.Agents.StructuredOutput` to pick native vs prompted JSON per
  adapter (D-104).
  """

  alias Kiln.Agents.{Prompt, Response}

  @typedoc """
  Capability map returned by `capabilities/0`. Every adapter MUST return
  all 5 flags; missing flags are a behaviour contract violation.
  """
  @type capabilities :: %{
          streaming: boolean(),
          tools: boolean(),
          thinking: boolean(),
          vision: boolean(),
          json_schema_mode: boolean()
        }

  @callback complete(Prompt.t(), keyword()) :: {:ok, Response.t()} | {:error, term()}
  @callback stream(Prompt.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  @callback count_tokens(Prompt.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback capabilities() :: capabilities()
end
