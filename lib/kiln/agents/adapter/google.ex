defmodule Kiln.Agents.Adapter.Google do
  @moduledoc """
  SCAFFOLDED Google Gemini adapter (D-101). Compiles, implements the
  `Kiln.Agents.Adapter` behaviour, Mox-tested for contract shape.

  Same scaffold pattern as `Kiln.Agents.Adapter.OpenAI` — `complete/2`
  and `stream/2` return `{:error, :scaffolded}` unless `live: true` +
  `:google_api_key` present. Live wire path is `@tag :live_google`-gated.

  See the OpenAI adapter moduledoc for the full secrets-boundary
  contract; this module follows the same shape.
  """

  @behaviour Kiln.Agents.Adapter

  alias Kiln.Agents.{Prompt, Response}
  alias Kiln.Secrets

  @base_url "https://generativelanguage.googleapis.com"

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
    rough =
      messages
      |> Enum.map(&char_len/1)
      |> Enum.sum()

    {:ok, div(rough, 4) + 1}
  end

  defp char_len(%{content: content}), do: content |> to_string() |> String.length()
  defp char_len(_), do: 0

  defp scaffold_only?(opts) do
    not (Keyword.get(opts, :live, false) and Secrets.present?(:google_api_key))
  end

  defp do_complete(%Prompt{} = prompt, opts) do
    # Gemini uses an API-key query param rather than an Authorization
    # header. Single Secrets.reveal!/1 call site for this module.
    base = Keyword.get(opts, :base_url, @base_url)
    key = fetch_api_key()
    model = prompt.model || "gemini-2.0-flash"

    body = %{
      "contents" => [
        %{"parts" => [%{"text" => stringify_messages(prompt.messages)}]}
      ],
      "generationConfig" => %{"maxOutputTokens" => prompt.max_tokens}
    }

    url = "#{base}/v1beta/models/#{model}:generateContent?key=#{URI.encode(key)}"

    case Req.post(url,
           finch: Kiln.Finch,
           headers: [{"content-type", "application/json"}],
           json: body
         ) do
      {:ok, %{status: 200, body: raw}} ->
        {:ok, build_response(model, raw)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stringify_messages(messages) do
    messages
    |> Enum.map(fn
      %{content: content} -> to_string(content)
      _ -> ""
    end)
    |> Enum.join("\n")
  end

  # SOLE Kiln.Secrets.reveal!/1 call site in this file.
  defp fetch_api_key do
    Secrets.reveal!(:google_api_key)
  end

  defp build_response(model, raw) do
    tokens_in = get_in(raw, ["usageMetadata", "promptTokenCount"]) || 0
    tokens_out = get_in(raw, ["usageMetadata", "candidatesTokenCount"]) || 0

    content =
      raw
      |> get_in(["candidates", Access.at(0), "content", "parts"])
      |> case do
        parts when is_list(parts) -> parts |> Enum.map(&Map.get(&1, "text", "")) |> Enum.join()
        _ -> nil
      end

    %Response{
      content: content,
      stop_reason: get_in(raw, ["candidates", Access.at(0), "finishReason"]) |> safe_atom(),
      tokens_in: tokens_in,
      tokens_out: tokens_out,
      cost_usd: estimate_cost(model, tokens_in, tokens_out),
      actual_model_used: model,
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
