defmodule Kiln.PricingTest do
  @moduledoc """
  Tests for `Kiln.Pricing.estimate_usd/3` — the single pricing surface
  consumed by `Kiln.Agents.BudgetGuard` and the Phase 7 cost dashboard.

  The pricing tables under `priv/pricing/v1/<provider>.exs` are the
  SSOT; these tests assert the lookup + arithmetic and the
  `known_model?/1` membership check.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Kiln.Pricing

  describe "estimate_usd/3" do
    test "claude-opus-4-5 1000/500 matches published rates" do
      # Opus rates: $15/mtok input, $75/mtok output.
      # 1000/1_000_000 * 15 = 0.015; 500/1_000_000 * 75 = 0.0375
      # Total = 0.0525
      cost = Pricing.estimate_usd("claude-opus-4-5-20250929", 1000, 500)
      assert Decimal.compare(cost, Decimal.new("0.05250")) == :eq
    end

    test "claude-sonnet-4-5 1000/500 matches published rates" do
      # Sonnet rates: $3/mtok input, $15/mtok output.
      # 1000/1_000_000 * 3 = 0.003; 500/1_000_000 * 15 = 0.0075
      # Total = 0.0105
      cost = Pricing.estimate_usd("claude-sonnet-4-5-20250929", 1000, 500)
      assert Decimal.compare(cost, Decimal.new("0.01050")) == :eq
    end

    test "claude-haiku-4-5 1000/500 matches published rates" do
      # Haiku rates: $1/mtok input, $5/mtok output.
      # 1000/1_000_000 * 1 = 0.001; 500/1_000_000 * 5 = 0.0025
      # Total = 0.0035
      cost = Pricing.estimate_usd("claude-haiku-4-5-20250929", 1000, 500)
      assert Decimal.compare(cost, Decimal.new("0.00350")) == :eq
    end

    test "unknown model returns 0 and logs a warning" do
      log =
        capture_log(fn ->
          assert Decimal.compare(
                   Pricing.estimate_usd("unknown-model-xyz", 100, 50),
                   Decimal.new(0)
                 ) == :eq
        end)

      assert log =~ "unknown model"
    end

    test "nil model returns 0" do
      assert Decimal.compare(Pricing.estimate_usd(nil, 100, 50), Decimal.new(0)) == :eq
    end

    test "zero tokens returns 0" do
      assert Decimal.compare(
               Pricing.estimate_usd("claude-sonnet-4-5-20250929", 0, 0),
               Decimal.new(0)
             ) == :eq
    end

    test "cross-validates the Wave 0 seed fixture" do
      # test/support/fixtures/pricing/anthropic_vectors_seed.exs holds the
      # 3 seed vectors whose expected_usd values must match this table.
      fixture_path =
        Path.expand("../../test/support/fixtures/pricing/anthropic_vectors_seed.exs", __DIR__)

      vectors = fixture_path |> Code.eval_file() |> elem(0)

      for {id, model, input_tokens, output_tokens, expected_usd} <- vectors do
        actual = Pricing.estimate_usd(model, input_tokens, output_tokens)

        assert Decimal.compare(actual, expected_usd) == :eq,
               "fixture #{id} (#{model}, #{input_tokens}/#{output_tokens}) " <>
                 "expected #{Decimal.to_string(expected_usd)}, got #{Decimal.to_string(actual)}"
      end
    end
  end

  describe "known_model?/1" do
    test "returns true for every live P3 Anthropic model" do
      for model <- [
            "claude-opus-4-5-20250929",
            "claude-sonnet-4-5-20250929",
            "claude-haiku-4-5-20250929"
          ] do
        assert Pricing.known_model?(model), "expected #{model} to be known"
      end
    end

    test "returns false for an unknown model" do
      refute Pricing.known_model?("unknown-model-xyz")
    end
  end

  describe "all_known_models/0" do
    test "returns a non-empty list covering all 4 providers" do
      models = Pricing.all_known_models()
      assert is_list(models)
      assert length(models) >= 9
      # At least one per provider
      assert Enum.any?(models, &String.starts_with?(&1, "claude-"))
      assert Enum.any?(models, &String.starts_with?(&1, "gpt-"))
      assert Enum.any?(models, &String.starts_with?(&1, "gemini-"))
      assert Enum.any?(models, &(String.contains?(&1, "llama") or String.contains?(&1, "qwen")))
    end
  end
end
