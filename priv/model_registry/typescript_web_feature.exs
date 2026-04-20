# D-105 / D-107 — model-profile preset for TypeScript web features.
#
# General-purpose coding profile. Mirrors `elixir_lib` because Anthropic
# is the only live provider in P3; P5+ can adjust independently.
%{
  planner: %{
    model: "claude-opus-4-5-20250929",
    fallback: ["claude-sonnet-4-5-20250929"],
    tier_crossing_alerts_on: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  coder: %{
    model: "claude-sonnet-4-5-20250929",
    fallback: ["claude-haiku-4-5-20250929"],
    tier_crossing_alerts_on: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  tester: %{
    model: "claude-sonnet-4-5-20250929",
    fallback: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  reviewer: %{
    model: "claude-sonnet-4-5-20250929",
    fallback: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  ui_ux: %{
    model: "claude-sonnet-4-5-20250929",
    fallback: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  qa_verifier: %{
    model: "claude-sonnet-4-5-20250929",
    fallback: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  mayor: %{
    model: "claude-opus-4-5-20250929",
    fallback: ["claude-sonnet-4-5-20250929"],
    tier_crossing_alerts_on: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  }
}
