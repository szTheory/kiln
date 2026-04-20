defmodule Kiln.Agents.PromptTest do
  @moduledoc """
  Struct-shape tests for `%Kiln.Agents.Prompt{}` (D-102 / D-133 Layer 1).

  The struct MUST exclude `:metadata` from its `Jason.Encoder` derive —
  `:metadata` carries both the `kiln_ctx` Oban ctx map AND
  `%Kiln.Secrets.Ref{}` values, so serialising it would leak a secret
  reference into JSON payloads.
  """

  use ExUnit.Case, async: true

  alias Kiln.Agents.Prompt
  alias Kiln.Secrets.Ref

  test "default fields" do
    p = %Prompt{model: "claude-sonnet-4-5"}
    assert p.model == "claude-sonnet-4-5"
    assert p.system == nil
    assert p.messages == []
    assert p.max_tokens == 4096
    assert p.temperature == 1.0
    assert p.tools == []
    assert p.metadata == %{}
  end

  test "Jason.encode! does NOT include :metadata field" do
    p = %Prompt{
      model: "x",
      metadata: %{api_key: %Ref{name: :anthropic_api_key}}
    }

    encoded = Jason.encode!(p)

    refute encoded =~ "metadata"
    refute encoded =~ "api_key"
    refute encoded =~ "anthropic_api_key"
  end

  test "Jason.encode! exposes the declared whitelist fields" do
    p = %Prompt{
      model: "claude-x",
      system: "you are helpful",
      messages: [%{role: :user, content: "hi"}],
      max_tokens: 100,
      temperature: 0.5,
      tools: [%{name: "search"}]
    }

    encoded = Jason.encode!(p)

    assert encoded =~ ~s("model":"claude-x")
    assert encoded =~ ~s("system":"you are helpful")
    assert encoded =~ ~s("max_tokens":100)
    assert encoded =~ ~s("temperature":0.5)
    assert encoded =~ "messages"
    assert encoded =~ "tools"
  end
end
