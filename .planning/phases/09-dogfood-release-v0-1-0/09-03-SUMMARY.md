---
phase: 09-dogfood-release-v0-1-0
plan: "03"
subsystem: docs
tags: [readme, onboarding, local-dev]

key-files:
  modified:
    - README.md
    - test/integration/first_run.sh
    - .env.sample
---

# Plan 09-03 Summary

- README restructured: prerequisites, numbered quick start ending at `/onboarding`, environment + human vs automated matrix, traces pointer, CI badge preserved.
- `first_run.sh` header aligned with README (no implicit `asdf install`).
- `.env.sample` documents dogfood + OTEL optional vars alongside existing keys.

## Self-Check: PASSED

- `bash -n test/integration/first_run.sh`
- `mix test test/kiln_web/live/onboarding_live_test.exs`
