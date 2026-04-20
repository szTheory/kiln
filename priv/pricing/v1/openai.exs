# D-146 pricing table for OpenAI models (April 2026 published rates).
#
# Format: %{model_id => %{input_per_mtok_usd, output_per_mtok_usd}}
#
# Source: https://openai.com/api/pricing (April 2026 snapshot).
# Cache pricing fields omitted — OpenAI exposes prompt caching on the
# Chat Completions path via a separate billing mechanism; Phase 5+ may
# extend this file when the OpenAI adapter goes live.
%{
  "gpt-4o-mini" => %{
    input_per_mtok_usd: Decimal.new("0.15"),
    output_per_mtok_usd: Decimal.new("0.60")
  },
  "gpt-4o" => %{
    input_per_mtok_usd: Decimal.new("2.50"),
    output_per_mtok_usd: Decimal.new("10.00")
  }
}
