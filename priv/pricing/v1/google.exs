# D-146 pricing table for Google models (April 2026 published rates).
#
# Format: %{model_id => %{input_per_mtok_usd, output_per_mtok_usd}}
#
# Source: https://cloud.google.com/vertex-ai/pricing (April 2026 snapshot).
%{
  "gemini-2.5-pro" => %{
    input_per_mtok_usd: Decimal.new("1.25"),
    output_per_mtok_usd: Decimal.new("5.00")
  },
  "gemini-2.5-flash" => %{
    input_per_mtok_usd: Decimal.new("0.10"),
    output_per_mtok_usd: Decimal.new("0.40")
  }
}
