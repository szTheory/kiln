defmodule Kiln.Logging.SecretRedactor do
  @moduledoc """
  `LoggerJSON.Redactor` behaviour implementation (D-133 Layer 4) of the
  six-layer secret-redaction defense.

  Scrubs log-metadata entries whose key matches one of
  `@secret_key_substrings` (case-insensitive substring match) OR whose
  binary value starts with one of `@secret_value_prefixes`.

  Registered in `config/config.exs`:

      config :logger_json, :redactors, [{Kiln.Logging.SecretRedactor, []}]

  Non-secret values pass through unchanged. Non-binary values pass
  through unchanged — redaction operates on log-serialisable strings
  only; numeric/atom/map values cannot be a secret prefix by
  construction.

  ## Triggers

  Key-name substrings (case-insensitive):

    * `api_key` — any `*_api_key*` variant in structured metadata
    * `secret` — includes `client_secret`, `webhook_secret`
    * `token` — includes `access_token`, `refresh_token`, `session_token`
    * `authorization` — HTTP-style header names
    * `bearer` — both `bearer_token` key and `Bearer <value>` headers

  Value prefixes (exact-start match):

    * `sk-ant-` — Anthropic PAT
    * `sk-proj-` — OpenAI project-scoped key
    * `ghp_` — GitHub Personal Access Token
    * `gho_` — GitHub OAuth user-to-server token
    * `AIza` — Google API key

  ## Framework contract

  `LoggerJSON.Formatter.RedactorEncoder` calls
  `redactor.redact(to_string(key), acc, opts)` — keys are coerced to
  string before dispatch. We additionally accept atom keys so unit
  tests can drive the function directly without round-tripping through
  the formatter.
  """

  @behaviour LoggerJSON.Redactor

  @secret_key_substrings ~w(api_key secret token authorization bearer)
  @secret_value_prefixes ~w(sk-ant- sk-proj- ghp_ gho_ AIza)
  @redacted "**redacted**"

  @impl LoggerJSON.Redactor
  def redact(key, value, _opts) do
    cond do
      key_looks_secret?(key) -> @redacted
      value_looks_secret?(value) -> @redacted
      true -> value
    end
  end

  defp key_looks_secret?(key) do
    key
    |> key_to_string()
    |> String.downcase()
    |> contains_any?(@secret_key_substrings)
  end

  defp key_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp key_to_string(key) when is_binary(key), do: key
  defp key_to_string(_), do: ""

  defp contains_any?(lowered, substrings) do
    Enum.any?(substrings, &String.contains?(lowered, &1))
  end

  defp value_looks_secret?(value) when is_binary(value) do
    Enum.any?(@secret_value_prefixes, &String.starts_with?(value, &1))
  end

  defp value_looks_secret?(_), do: false
end
