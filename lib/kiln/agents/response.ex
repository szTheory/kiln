defmodule Kiln.Agents.Response do
  @moduledoc """
  Provider-agnostic LLM response envelope (D-102 / D-105 / OPS-02).

  `:actual_model_used` is the model the provider actually billed — D-105
  requires recording both `requested_model` (on `%Prompt{}`) and
  `actual_model_used` to catch silent model fallback in the
  ModelRegistry. `cost_usd` is computed by `Kiln.Pricing.estimate_usd/3`
  (Plan 03-06) on receipt.

  ## Redaction boundary

  `:raw` holds the provider's un-normalized response body and is kept
  for forensic attach-to-artifact use. It is EXCLUDED from
  `@derive Jason.Encoder` — serialising it would leak arbitrary provider
  bytes into audit payloads and cross-process messages. Tests in
  `test/kiln/agents/response_test.exs` assert this.
  """

  @derive {Jason.Encoder,
           only: [:content, :stop_reason, :tokens_in, :tokens_out, :cost_usd, :actual_model_used]}

  defstruct [
    :content,
    :stop_reason,
    :tokens_in,
    :tokens_out,
    :cost_usd,
    :actual_model_used,
    :raw
  ]

  @type stop_reason :: :end_turn | :max_tokens | :stop_sequence | :tool_use | atom()

  @type t :: %__MODULE__{
          content: term(),
          stop_reason: stop_reason() | nil,
          tokens_in: non_neg_integer() | nil,
          tokens_out: non_neg_integer() | nil,
          cost_usd: Decimal.t() | nil,
          actual_model_used: String.t() | nil,
          raw: term()
        }
end
