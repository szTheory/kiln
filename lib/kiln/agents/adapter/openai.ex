defmodule Kiln.Agents.Adapter.OpenAI do
  @moduledoc """
  SCAFFOLDED OpenAI adapter (D-101). Compiles, implements the
  `Kiln.Agents.Adapter` behaviour, Mox-tested for contract shape.

  Live wire calls return `{:error, :scaffolded}` by default; opt in via
  `live: true` + a present `:openai_api_key` secret. `@tag :live_openai`
  tests exercise the real OpenAI Chat Completions endpoint when
  `OPENAI_API_KEY` is present — they are excluded from `mix test` by
  default (see `test/test_helper.exs`).

  Phase 5+ likely flips this to LIVE when OPS-02's cross-provider
  fallback chain needs to be exercised end-to-end. Until then the
  scaffold prevents Anthropic-shaped leakage into the adapter contract.

  ## Secrets boundary (D-131..D-133 Layer 1)

  `Kiln.Secrets.reveal!/1` has exactly one call site in this file:
  inside `build_headers/0`, which is called only from the live
  `do_complete/2` path. When `live: true` is NOT set, `fetch_api_key/0`
  is never called, so the raw string never materialises.
  """

  @behaviour Kiln.Agents.Adapter

  alias Kiln.Agents.{Prompt, Response}
  alias Kiln.Secrets

  @base_url "https://api.openai.com"

  @impl true
  def capabilities do
    %{
      streaming: true,
      tools: true,
      thinking: false,
      vision: true,
      json_schema_mode: true
    }
  end

  @impl true
  def complete(%Prompt{} = prompt, opts) do
    if scaffold_only?(opts) do
      {:error, :scaffolded}
    else
      do_complete(prompt, opts)
    end
  end

  @impl true
  def stream(%Prompt{} = _prompt, opts) do
    if scaffold_only?(opts),
      do: {:error, :scaffolded},
      else: {:error, :stream_not_implemented_p3}
  end

  @impl true
  def count_tokens(%Prompt{messages: messages}) do
    # Rough char-based estimate (4 chars ≈ 1 token for English-ish text).
    # Phase 5+ wires tiktoken_ex for accurate OpenAI tokenisation.
    rough =
      messages
      |> Enum.map(&char_len/1)
      |> Enum.sum()

    {:ok, div(rough, 4) + 1}
  end

  defp char_len(%{content: content}), do: content |> to_string() |> String.length()
  defp char_len(_), do: 0

  defp scaffold_only?(opts) do
    not (Keyword.get(opts, :live, false) and Secrets.present?(:openai_api_key))
  end

  defp do_complete(%Prompt{} = prompt, opts) do
    base = Keyword.get(opts, :base_url, @base_url)
    headers = build_headers()

    body = %{
      "model" => prompt.model,
      "messages" => prompt.messages,
      "max_tokens" => prompt.max_tokens
    }

    case Req.post("#{base}/v1/chat/completions",
           finch: Kiln.Finch,
           headers: headers,
           json: body
         ) do
      {:ok, %{status: 200, body: raw}} ->
        {:ok, build_response(prompt, raw)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_headers do
    [
      {"authorization", "Bearer " <> fetch_api_key()},
      {"content-type", "application/json"}
    ]
  end

  # SOLE Kiln.Secrets.reveal!/1 call site in this file. Only invoked
  # from the live do_complete/2 path (gated by scaffold_only?/1).
  defp fetch_api_key do
    Secrets.reveal!(:openai_api_key)
  end

  defp build_response(%Prompt{} = prompt, raw) do
    tokens_in = get_in(raw, ["usage", "prompt_tokens"]) || 0
    tokens_out = get_in(raw, ["usage", "completion_tokens"]) || 0

    %Response{
      content: get_in(raw, ["choices", Access.at(0), "message", "content"]),
      stop_reason: get_in(raw, ["choices", Access.at(0), "finish_reason"]) |> safe_atom(),
      tokens_in: tokens_in,
      tokens_out: tokens_out,
      cost_usd: estimate_cost(Map.get(raw, "model") || prompt.model, tokens_in, tokens_out),
      actual_model_used: Map.get(raw, "model"),
      raw: raw
    }
  end

  defp safe_atom(nil), do: nil
  defp safe_atom(s) when is_binary(s), do: String.to_atom(s)
  defp safe_atom(s) when is_atom(s), do: s

  defp estimate_cost(model, tokens_in, tokens_out) do
    if Code.ensure_loaded?(Kiln.Pricing) and
         function_exported?(Kiln.Pricing, :estimate_usd, 3) do
      apply(Kiln.Pricing, :estimate_usd, [model, tokens_in, tokens_out])
    else
      nil
    end
  end
end
