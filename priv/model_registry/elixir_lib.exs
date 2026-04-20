# D-105 / D-107 — model-profile preset for Elixir library projects.
#
# Role -> %{model, fallback, tier_crossing_alerts_on, fallback_policy}
#
# P3 ships `fallback_policy: :same_provider` on every role (D-107).
# Phase 5+ flips OpenAI live, and the operator may switch individual
# roles to `:cross_provider` without a schema migration.
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
