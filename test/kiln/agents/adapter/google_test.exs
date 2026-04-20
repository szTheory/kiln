defmodule Kiln.Agents.Adapter.GoogleTest do
  @moduledoc """
  Contract tests for the scaffolded Google Gemini adapter (D-101).
  """

  use ExUnit.Case, async: true

  alias Kiln.Agents.{Adapter.Google, Prompt}

  test "implements the 4 Adapter callbacks" do
    assert function_exported?(Google, :complete, 2)
    assert function_exported?(Google, :stream, 2)
    assert function_exported?(Google, :count_tokens, 1)
    assert function_exported?(Google, :capabilities, 0)
  end

  test "declares @behaviour Kiln.Agents.Adapter" do
    behaviours = Google.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    assert Kiln.Agents.Adapter in behaviours
  end

  test "complete/2 without :live returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = Google.complete(%Prompt{model: "gemini-2.0-flash"}, [])
  end

  test "stream/2 without :live returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = Google.stream(%Prompt{model: "gemini-2.0-flash"}, [])
  end

  test "capabilities reflects Gemini realistic surface" do
    caps = Google.capabilities()
    assert caps.streaming == true
    assert caps.tools == true
    assert caps.vision == true
    assert caps.json_schema_mode == true
  end

  test "count_tokens returns rough character-based estimate" do
    prompt = %Prompt{
      model: "gemini-2.0-flash",
      messages: [%{role: :user, content: "hello gemini"}]
    }

    assert {:ok, n} = Google.count_tokens(prompt)
    assert is_integer(n)
    assert n > 0
  end

  @tag :live_google
  test "live Google call when GOOGLE_API_KEY present" do
    if key = System.get_env("GOOGLE_API_KEY") do
      Kiln.Secrets.put(:google_api_key, key)

      assert {:ok, _} =
               Google.complete(
                 %Prompt{
                   model: "gemini-2.0-flash",
                   messages: [%{role: :user, content: "hi"}],
                   max_tokens: 5
                 },
                 live: true
               )
    else
      flunk("GOOGLE_API_KEY not set")
    end
  end
end
