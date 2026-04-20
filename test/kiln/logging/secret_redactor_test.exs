defmodule Kiln.Logging.SecretRedactorTest do
  @moduledoc """
  Unit tests for `Kiln.Logging.SecretRedactor` (D-133 Layer 4).

  Guards two redaction triggers + pass-through:

    * Key-name match (case-insensitive substring) across five
      substrings: `api_key`, `secret`, `token`, `authorization`, `bearer`
    * Value-prefix match across five prefixes: `sk-ant-`, `sk-proj-`,
      `ghp_`, `gho_`, `AIza`
    * Non-matching entries pass through unchanged (strings, ints,
      atoms, nils, maps)
  """

  use ExUnit.Case, async: true

  alias Kiln.Logging.SecretRedactor

  describe "redact/3 — key-name triggers" do
    for key <- [:api_key, :secret, :token, :authorization, :bearer] do
      @key key
      test "atom key #{inspect(key)} triggers redaction" do
        assert SecretRedactor.redact(@key, "anything", []) == "**redacted**"
      end
    end

    test "mixed-case string key triggers redaction" do
      assert SecretRedactor.redact("API_KEY", "val", []) == "**redacted**"
      assert SecretRedactor.redact("Authorization", "val", []) == "**redacted**"
      assert SecretRedactor.redact("X-BEARER-TOKEN", "val", []) == "**redacted**"
    end

    test "substring-match key triggers redaction" do
      assert SecretRedactor.redact(:my_api_key_for_anthropic, "v", []) == "**redacted**"
      assert SecretRedactor.redact(:session_token, "v", []) == "**redacted**"
      assert SecretRedactor.redact(:client_secret, "v", []) == "**redacted**"
    end
  end

  describe "redact/3 — value-prefix triggers (benign key)" do
    for prefix <- ["sk-ant-", "sk-proj-", "ghp_", "gho_", "AIza"] do
      @prefix prefix
      test "value starting with #{prefix} triggers redaction on benign key" do
        assert SecretRedactor.redact(:unrelated, @prefix <> "FAKE0000000", []) ==
                 "**redacted**"
      end
    end

    test "prefix must be at the start of the value (not a substring anywhere)" do
      # A key with a prefix embedded mid-string should NOT trigger the
      # value-prefix rule on a benign key. Key-name rule is also off here.
      assert SecretRedactor.redact(:unrelated, "message containing sk-ant-FAKE", []) ==
               "message containing sk-ant-FAKE"
    end
  end

  describe "redact/3 — pass-through" do
    test "ordinary string passes through unchanged" do
      assert SecretRedactor.redact(:msg, "hello world", []) == "hello world"
    end

    test "integer passes through" do
      assert SecretRedactor.redact(:count, 42, []) == 42
    end

    test "nil passes through" do
      assert SecretRedactor.redact(:run_id, nil, []) == nil
    end

    test "atom value passes through" do
      assert SecretRedactor.redact(:state, :queued, []) == :queued
    end

    test "map value passes through" do
      assert SecretRedactor.redact(:payload, %{a: 1}, []) == %{a: 1}
    end

    test "non-atom non-binary key (e.g. integer) with ordinary value passes through" do
      assert SecretRedactor.redact(1, "plain", []) == "plain"
    end
  end

  describe "@behaviour conformance" do
    test "implements LoggerJSON.Redactor behaviour" do
      behaviours = SecretRedactor.__info__(:attributes) |> Keyword.get_values(:behaviour)
      assert LoggerJSON.Redactor in List.flatten(behaviours)
    end
  end
end
