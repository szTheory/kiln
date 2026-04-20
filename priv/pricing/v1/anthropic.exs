# D-146 pricing table for Anthropic models (April 2026 published rates).
#
# Format: %{model_id => %{input_per_mtok_usd, output_per_mtok_usd,
#         cache_write_per_mtok_usd, cache_read_per_mtok_usd}}
#
# Source: https://www.anthropic.com/pricing (April 2026 snapshot).
# Values locked here are cross-validated by
# `test/support/fixtures/pricing/anthropic_vectors_seed.exs` — drift in
# this table that breaks the seed vectors surfaces immediately in
# `Kiln.PricingTest`.
%{
  "claude-opus-4-5-20250929" => %{
    input_per_mtok_usd: Decimal.new("15.00"),
    output_per_mtok_usd: Decimal.new("75.00"),
    cache_write_per_mtok_usd: Decimal.new("18.75"),
    cache_read_per_mtok_usd: Decimal.new("1.50")
  },
  "claude-sonnet-4-5-20250929" => %{
    input_per_mtok_usd: Decimal.new("3.00"),
    output_per_mtok_usd: Decimal.new("15.00"),
    cache_write_per_mtok_usd: Decimal.new("3.75"),
    cache_read_per_mtok_usd: Decimal.new("0.30")
  },
  "claude-haiku-4-5-20250929" => %{
    input_per_mtok_usd: Decimal.new("1.00"),
    output_per_mtok_usd: Decimal.new("5.00"),
    cache_write_per_mtok_usd: Decimal.new("1.25"),
    cache_read_per_mtok_usd: Decimal.new("0.10")
  }
}
