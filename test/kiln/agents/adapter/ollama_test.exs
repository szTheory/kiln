defmodule Kiln.Agents.Adapter.OllamaTest do
  @moduledoc """
  Contract tests for the scaffolded Ollama local adapter (D-101).
  """

  use ExUnit.Case, async: true

  alias Kiln.Agents.{Adapter.Ollama, Prompt}

  test "implements the 4 Adapter callbacks" do
    assert function_exported?(Ollama, :complete, 2)
    assert function_exported?(Ollama, :stream, 2)
    assert function_exported?(Ollama, :count_tokens, 1)
    assert function_exported?(Ollama, :capabilities, 0)
  end

  test "declares @behaviour Kiln.Agents.Adapter" do
    behaviours = Ollama.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    assert Kiln.Agents.Adapter in behaviours
  end

  test "complete/2 returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = Ollama.complete(%Prompt{model: "llama3"}, [])
  end

  test "stream/2 returns {:error, :scaffolded}" do
    assert {:error, :scaffolded} = Ollama.stream(%Prompt{model: "llama3"}, [])
  end

  test "capabilities reflects Ollama realistic surface (json_schema_mode: false → prompted-JSON fallback)" do
    caps = Ollama.capabilities()
    assert caps.streaming == true
    assert caps.tools == false
    assert caps.thinking == false
    assert caps.vision == false
    assert caps.json_schema_mode == false
  end

  test "count_tokens returns rough character-based estimate" do
    prompt = %Prompt{
      model: "llama3",
      messages: [%{role: :user, content: "hello local"}]
    }

    assert {:ok, n} = Ollama.count_tokens(prompt)
    assert is_integer(n)
    assert n > 0
  end

  @tag :live_ollama
  test "live Ollama call when OLLAMA_HOST set" do
    if System.get_env("OLLAMA_HOST") do
      assert {:ok, _} =
               Ollama.complete(
                 %Prompt{
                   model: "llama3",
                   messages: [%{role: :user, content: "hi"}],
                   max_tokens: 5
                 },
                 live: true
               )
    else
      flunk("OLLAMA_HOST not set")
    end
  end
end
