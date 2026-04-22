defmodule Kiln.BlockersTest do
  use ExUnit.Case, async: true
  alias Kiln.Blockers

  test "raise_block/3 raises Kiln.Blockers.BlockedError with populated fields" do
    assert_raise Kiln.Blockers.BlockedError, fn ->
      Blockers.raise_block(:missing_api_key, "run-a", %{provider: "anthropic"})
    end
  end

  test "raise_block/3 with unknown reason raises ArgumentError" do
    assert_raise ArgumentError, fn ->
      Blockers.raise_block(:not_a_reason, "run-a", %{})
    end
  end

  test "raise_block/3 rejects advisory (non-blocking) reasons" do
    assert_raise ArgumentError, ~r/non-blocking reason/, fn ->
      Blockers.raise_block(:budget_threshold_50, "run-a", %{})
    end
  end

  test "fetch/1 delegates to PlaybookRegistry" do
    assert {:ok, _pb} = Blockers.fetch(:missing_api_key)
  end

  test "render/2 delegates to PlaybookRegistry" do
    assert {:ok, rp} =
             Blockers.render(:budget_exceeded, %{
               run_id: "r1",
               estimated_usd: "12.50",
               remaining_usd: "0.00",
               workflow_id: "elixir_phoenix_feature",
               new_cap_usd: "20.00"
             })

    assert rp.reason == :budget_exceeded
  end
end
