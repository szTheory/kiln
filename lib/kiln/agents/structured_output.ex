defmodule Kiln.Agents.StructuredOutput do
  @moduledoc """
  Provider-agnostic structured-output facade (D-104 / D-156). Dispatches
  to a per-provider native mode based on
  `Adapter.capabilities().json_schema_mode`.

  Native modes (provider-side enforcement):

    * Anthropic — `tool_use` (current Anthropix 0.6.2; D-156 resolution)
    * OpenAI — `response_format: {type: "json_schema", json_schema: {schema, strict: true}}`
    * Google — `function_calling`
    * Ollama — `json_schema_mode == false`; falls through to prompted-JSON
      + JSV post-validate + 1 retry

  All paths post-validate the response via JSV Draft 2020-12 as
  defense-in-depth (even when the provider promises native JSON
  schema enforcement — 2025 industry consensus: 3% residual error rate).

  ## Usage

      StructuredOutput.request(schema, adapter: Kiln.Agents.Adapter.Anthropic,
                                        prompt: %Prompt{...})

  Returns `{:ok, parsed_map}` when the response parses as JSON AND
  validates against `schema`; `{:error, reason}` otherwise. The
  prompted-JSON path retries once on JSON parse failure (D-104 — retry
  counted against caller's stage budget via BudgetGuard wrapping in
  Wave 2+).
  """

  alias Kiln.Agents.{Prompt, Response}

  @type opts :: [adapter: module(), prompt: Prompt.t()]

  @spec request(map(), opts()) :: {:ok, term()} | {:error, term()}
  def request(schema, opts) when is_map(schema) and is_list(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    prompt = Keyword.fetch!(opts, :prompt)

    schema_root =
      JSV.build!(schema, default_meta: "https://json-schema.org/draft/2020-12/schema")

    caps = adapter.capabilities()

    if caps.json_schema_mode do
      do_native_request(adapter, prompt, schema_root, opts)
    else
      do_prompted_request(adapter, prompt, schema, schema_root, opts, 1)
    end
  end

  # Native-mode dispatch — the adapter's `complete/2` receives the schema
  # via opts[:json_schema] and is responsible for wiring it into the
  # provider-specific request shape (tool_use / response_format /
  # function_calling). The scaffolded adapters return plain content; the
  # live Anthropic adapter wires tool_use when Wave 2/3 lands that path.
  defp do_native_request(adapter, prompt, schema_root, opts) do
    native_opts = Keyword.put(opts, :json_schema_mode, :native)

    with {:ok, %Response{content: content}} <- adapter.complete(prompt, native_opts),
         {:ok, parsed} <- parse_json_content(content),
         {:ok, validated} <- JSV.validate(parsed, schema_root) do
      {:ok, validated}
    end
  end

  # Prompted-JSON — append the schema to the system prompt, ask the
  # model to respond with JSON matching it, post-validate. Retries once
  # on parse or validation failure.
  defp do_prompted_request(adapter, %Prompt{} = prompt, schema, schema_root, opts, attempt) do
    schema_str = Jason.encode!(schema)
    system_addendum = "\n\nRespond with JSON matching this schema:\n" <> schema_str
    augmented = %Prompt{prompt | system: (prompt.system || "") <> system_addendum}

    with {:ok, %Response{content: content}} <- adapter.complete(augmented, opts),
         {:ok, parsed} <- parse_json_content(content),
         {:ok, validated} <- JSV.validate(parsed, schema_root) do
      {:ok, validated}
    else
      _err when attempt < 2 ->
        do_prompted_request(adapter, prompt, schema, schema_root, opts, attempt + 1)

      err ->
        err
    end
  end

  defp parse_json_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} = err -> err
    end
  end

  defp parse_json_content(_), do: {:error, :non_string_content}
end
