# D-146 pricing table for Ollama (local) models.
#
# Ollama runs locally, so external per-token cost is always zero. The
# table is still populated so `Kiln.Pricing.known_model?/1` returns true
# and downstream cross-validation in `Kiln.ModelRegistry.PresetsTest`
# doesn't surface a false drift signal when an operator wires an Ollama
# model into a preset.
#
# Format: %{model_id => %{input_per_mtok_usd, output_per_mtok_usd}}
%{
  "llama3.3:70b" => %{
    input_per_mtok_usd: Decimal.new("0.00"),
    output_per_mtok_usd: Decimal.new("0.00")
  },
  "qwen2.5-coder:32b" => %{
    input_per_mtok_usd: Decimal.new("0.00"),
    output_per_mtok_usd: Decimal.new("0.00")
  }
}
