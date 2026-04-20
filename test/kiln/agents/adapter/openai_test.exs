defmodule Kiln.Agents.Adapter.OpenAITest do
  @moduledoc """
  Contract tests for the scaffolded OpenAI adapter (D-101). Confirms
  @behaviour compliance, scaffold-default `{:error, :scaffolded}` return,
  and capability shape. Real wire calls gated on `@tag :live_openai`.
  """

  use ExUnit.Case, async: true

  alias Kiln.Agents.{Adapter.OpenAI, Prompt}

  test "implements the 4 Adapter callbacks" do
    assert function_exported?(OpenAI, :complete, 2)
    assert function_exported?(OpenAI, :stream, 2)
    assert function_exported?(OpenAI, :count_tokens, 1)
    assert function_exported?(OpenAI, :capabilities, 0)
  end

  test "declares @behaviour Kiln.Agents.Adapter" do
    behaviours = OpenAI.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    assert Kiln.Agents.Adapter in behaviours
  end

  test "complete/2 without :live returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = OpenAI.complete(%Prompt{model: "gpt-4o"}, [])
  end

  test "stream/2 without :live returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = OpenAI.stream(%Prompt{model: "gpt-4o"}, [])
  end

  test "capabilities reflects OpenAI realistic surface" do
    caps = OpenAI.capabilities()
    assert caps.streaming == true
    assert caps.tools == true
    assert caps.thinking == false
    assert caps.vision == true
    assert caps.json_schema_mode == true
  end

  test "count_tokens returns rough character-based estimate" do
    prompt = %Prompt{
      model: "gpt-4o",
      messages: [%{role: :user, content: "hello world"}]
    }

    assert {:ok, n} = OpenAI.count_tokens(prompt)
    assert is_integer(n)
    assert n > 0
  end

  @tag :live_openai
  test "live OpenAI call when OPENAI_API_KEY present" do
    if key = System.get_env("OPENAI_API_KEY") do
      Kiln.Secrets.put(:openai_api_key, key)

      assert {:ok, _} =
               OpenAI.complete(
                 %Prompt{
                   model: "gpt-4o-mini",
                   messages: [%{role: :user, content: "hi"}],
                   max_tokens: 5
                 },
                 live: true
               )
    else
      flunk("OPENAI_API_KEY not set")
    end
  end
end
