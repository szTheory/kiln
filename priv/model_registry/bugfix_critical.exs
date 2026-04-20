# D-105 / D-107 — model-profile preset for critical bugfix work.
#
# Upgrades `coder` and `mayor` to Opus so the diagnostic and repair paths
# run the strongest model available. Other roles remain Sonnet (plenty
# thorough for test/review on a targeted fix).
%{
  planner: %{
    model: "claude-opus-4-5-20250929",
    fallback: ["claude-sonnet-4-5-20250929"],
    tier_crossing_alerts_on: ["claude-haiku-4-5-20250929"],
    fallback_policy: :same_provider
  },
  coder: %{
    model: "claude-opus-4-5-20250929",
    fallback: ["claude-sonnet-4-5-20250929"],
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
