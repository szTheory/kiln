# D-146 pricing regression fixture — SEED (3 vectors).
#
# Plan 03-06 (Wave 2) expands this to 10 vectors per AI-SPEC §Reference
# Dataset. The format (tuple of {id, model, input_tokens, output_tokens,
# expected_usd}) is stable across the expansion — each new vector adds a
# row; no existing row changes shape.
#
# Expected-USD values are PLACEHOLDERS derived from a naive $0.0525 /
# $0.0105 / $0.0035 per-1k-token rate table and will be tuned by the
# Wave 2 pricing plan (plan 03-06) against the published Anthropic
# April 2026 rates. Tests that consume this fixture before Wave 2 should
# treat it as a shape check, not a value check.
#
# Contract:
#   [{fixture_id :: atom, model :: String.t(), input_tokens :: pos_integer,
#     output_tokens :: pos_integer, expected_usd :: Decimal.t()}]

[
  {:opus_small, "claude-opus-4-5-20250929", 1000, 500, Decimal.new("0.05250")},
  {:sonnet_small, "claude-sonnet-4-5-20250929", 1000, 500, Decimal.new("0.01050")},
  {:haiku_small, "claude-haiku-4-5-20250929", 1000, 500, Decimal.new("0.00350")}
]
