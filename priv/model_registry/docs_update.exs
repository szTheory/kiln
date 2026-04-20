# D-105 / D-107 — model-profile preset for docs-only updates.
#
# Docs are cheap to verify and the cost of a miss is low, so every role
# downgrades to Haiku. Fallbacks stay within the Anthropic tier family;
# with Haiku as both primary and fallback-tail, chain exhaustion surfaces
# loudly rather than silently escalating to a pricier tier.
%{
  planner: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  coder: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  tester: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  reviewer: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  ui_ux: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  qa_verifier: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  },
  mayor: %{
    model: "claude-haiku-4-5-20250929",
    fallback: [],
    fallback_policy: :same_provider
  }
}
