defmodule Kiln.Agents.StructuredOutputTest do
  @moduledoc """
  Contract tests for `Kiln.Agents.StructuredOutput.request/2` (D-104).

  Asserts dispatch by `Adapter.capabilities().json_schema_mode` and
  JSV Draft 2020-12 post-validation. Uses the Mox-registered
  `Kiln.Agents.AdapterMock` so the dispatch logic can be exercised
  without a live provider.
  """

  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  alias Kiln.Agents.{AdapterMock, Prompt, Response, StructuredOutput}

  test "dispatches to native path when json_schema_mode == true" do
    expect(AdapterMock, :capabilities, fn ->
      %{streaming: true, tools: true, thinking: false, vision: false, json_schema_mode: true}
    end)

    expect(AdapterMock, :complete, fn _prompt, _opts ->
      {:ok, %Response{content: ~s({"foo": "bar"})}}
    end)

    schema = %{
      "type" => "object",
      "properties" => %{"foo" => %{"type" => "string"}},
      "required" => ["foo"]
    }

    assert {:ok, %{"foo" => "bar"}} =
             StructuredOutput.request(schema,
               adapter: AdapterMock,
               prompt: %Prompt{model: "x"}
             )
  end

  test "falls back to prompted-JSON path when json_schema_mode == false" do
    expect(AdapterMock, :capabilities, fn ->
      %{streaming: true, tools: false, thinking: false, vision: false, json_schema_mode: false}
    end)

    expect(AdapterMock, :complete, fn _prompt, _opts ->
      {:ok, %Response{content: ~s({"foo": "bar"})}}
    end)

    schema = %{
      "type" => "object",
      "properties" => %{"foo" => %{"type" => "string"}},
      "required" => ["foo"]
    }

    assert {:ok, %{"foo" => "bar"}} =
             StructuredOutput.request(schema,
               adapter: AdapterMock,
               prompt: %Prompt{model: "x"}
             )
  end

  test "retries once on JSON parse failure (prompted path)" do
    expect(AdapterMock, :capabilities, fn ->
      %{streaming: false, tools: false, thinking: false, vision: false, json_schema_mode: false}
    end)

    # Adapter called exactly 2 times (initial + 1 retry) per D-104.
    expect(AdapterMock, :complete, 2, fn _prompt, _opts ->
      {:ok, %Response{content: "not-json-at-all"}}
    end)

    schema = %{"type" => "object"}

    assert {:error, _} =
             StructuredOutput.request(schema,
               adapter: AdapterMock,
               prompt: %Prompt{model: "x"}
             )
  end

  test "JSV validation failure returns error on native path (defense-in-depth)" do
    expect(AdapterMock, :capabilities, fn ->
      %{streaming: true, tools: true, thinking: false, vision: false, json_schema_mode: true}
    end)

    # Provider returns JSON that parses but fails schema validation —
    # "foo" is required; empty object violates.
    expect(AdapterMock, :complete, fn _prompt, _opts ->
      {:ok, %Response{content: "{}"}}
    end)

    schema = %{
      "type" => "object",
      "properties" => %{"foo" => %{"type" => "string"}},
      "required" => ["foo"]
    }

    assert {:error, _} =
             StructuredOutput.request(schema,
               adapter: AdapterMock,
               prompt: %Prompt{model: "x"}
             )
  end
end
