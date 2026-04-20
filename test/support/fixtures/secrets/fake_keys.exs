# D-133 Layer 6 — Negative-secret-leak adversarial corpus.
#
# These strings are DETERMINISTIC FAKES. They match the published shape
# of each provider's API keys but are composed entirely of a literal
# `FAKE` substring + deterministic padding, so they cannot authenticate
# against any real provider service (invalid entropy + marker prefix).
#
# Shapes (from each provider's key documentation):
#   * Anthropic PAT   — `sk-ant-<40-char-base62>`
#   * OpenAI service  — `sk-proj-<40-char-base62>`
#   * GitHub PAT      — `ghp_<36-char-base62>`
#   * GitHub OAuth    — `gho_<36-char-base62>`
#   * Google API key  — `AIza<35-char-base64url>`
#
# THESE STRINGS MUST NOT APPEAR OUTSIDE THIS FIXTURE FILE. The SEC-01
# adversarial suite (plan 03-08 Wave 4) greps logs, `inspect/1` output,
# docker-inspect env, telemetry metadata, changeset errors, and the
# workspace for these patterns. A leak = test failure.
#
# Committed, not gitignored (Wave 0 simplicity — plan 03-00 Task 3 note).
# The keys are deterministic fakes with known-invalid entropy; the
# moduledoc-comments above make the "not real" nature explicit.

%{
  anthropic: "sk-ant-FAKE0000000000000000000000000000000000",
  openai: "sk-proj-FAKE000000000000000000000000000000000",
  github_personal: "ghp_FAKE00000000000000000000000000000",
  github_oauth: "gho_FAKE00000000000000000000000000000",
  google: "AIzaFAKE00000000000000000000000000000"
}
