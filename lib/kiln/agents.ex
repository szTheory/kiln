defmodule Kiln.Agents do
  @moduledoc """
  Agent invocation surface (ARCHITECTURE.md §4 execution layer).
  Provider-agnostic via `Kiln.Agents.Adapter` behaviour (AGENT-01 /
  D-101..D-102).

  ## Adapters

  Live in Phase 3:

    * `Kiln.Agents.Adapter.Anthropic` — Anthropix 0.6.2 + Req 0.5 +
      Finch pool routing

  Scaffolded in Phase 3 (Req-based, `@tag :live_<provider>` gated; real
  wire calls deferred to Phase 5+):

    * `Kiln.Agents.Adapter.OpenAI`
    * `Kiln.Agents.Adapter.Google`
    * `Kiln.Agents.Adapter.Ollama`

  ## Public API

  Wave 5 wires `Kiln.Stages.StageWorker` to call these — pre-Wave-5
  callers resolve the right adapter via `Kiln.ModelRegistry.adapter_for/1`
  (Plan 03-06) and thread it explicitly.

    * `complete/3` — synchronous LLM call returning `{:ok, %Response{}}`.
    * `stream/3` — Enumerable passthrough (D-103 — no PubSub in P3;
      Phase 7 wires the LiveView consumer).

  See `.planning/research/ARCHITECTURE.md` §11 for callback shapes and
  ModelRegistry resolution.
  """

  alias Kiln.Agents.{Prompt, Response}

  @doc """
  Invoke an adapter's `complete/2` with the given prompt.

  Pre-Wave-5 callers pass the adapter module explicitly (resolved via
  `Kiln.ModelRegistry.adapter_for/1` once it ships); Wave 5+ wires
  `BudgetGuard` pre-flight between the caller and the adapter.
  """
  @spec complete(module(), Prompt.t(), keyword()) :: {:ok, Response.t()} | {:error, term()}
  def complete(adapter, %Prompt{} = prompt, opts) when is_atom(adapter) do
    adapter.complete(prompt, opts)
  end

  @doc """
  Invoke an adapter's `stream/2`. Returns `{:ok, Enumerable.t()}` — the
  caller is responsible for consuming the Enumerable (D-103 passthrough).
  """
  @spec stream(module(), Prompt.t(), keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def stream(adapter, %Prompt{} = prompt, opts) when is_atom(adapter) do
    adapter.stream(prompt, opts)
  end
end
