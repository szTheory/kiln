defmodule Kiln.Agents.ResponseTest do
  @moduledoc """
  Struct-shape tests for `%Kiln.Agents.Response{}` (D-102 / D-105).

  The struct MUST exclude `:raw` from its `Jason.Encoder` derive — the
  provider's raw response body is kept for forensic attach-to-artifact
  use but must not end up in JSON payloads that cross process / network
  boundaries (leak-by-omission risk if the raw body contains any
  unexpected field).
  """

  use ExUnit.Case, async: true

  alias Kiln.Agents.Response

  test "default fields" do
    r = %Response{}
    assert is_nil(r.content)
    assert is_nil(r.stop_reason)
    assert is_nil(r.cost_usd)
    assert is_nil(r.actual_model_used)
    assert is_nil(r.raw)
    assert is_nil(r.tokens_in)
    assert is_nil(r.tokens_out)
  end

  test "Jason.encode! does NOT include :raw field" do
    r = %Response{content: "x", raw: %{huge: "payload"}}
    encoded = Jason.encode!(r)
    refute encoded =~ "raw"
    refute encoded =~ "huge"
    refute encoded =~ "payload"
  end

  test "Jason.encode! exposes the declared whitelist fields" do
    r = %Response{
      content: "ok",
      stop_reason: :end_turn,
      tokens_in: 10,
      tokens_out: 5,
      cost_usd: Decimal.new("0.001"),
      actual_model_used: "claude-sonnet-4-5-20250929"
    }

    encoded = Jason.encode!(r)

    assert encoded =~ ~s("content":"ok")
    assert encoded =~ "end_turn"
    assert encoded =~ ~s("tokens_in":10)
    assert encoded =~ ~s("tokens_out":5)
    assert encoded =~ "actual_model_used"
    assert encoded =~ "claude-sonnet-4-5-20250929"
    assert encoded =~ "cost_usd"
  end
end
