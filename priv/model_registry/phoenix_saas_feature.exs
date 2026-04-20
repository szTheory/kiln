# D-105 / D-107 — model-profile preset for Phoenix SaaS feature work.
#
# Phoenix is Elixir; the role/model mapping mirrors `elixir_lib` exactly.
# Split maintained as a distinct file so P5+ can tune independently
# (e.g. stronger reviewer for multi-tenant security review) without
# disturbing the library-project preset.
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
