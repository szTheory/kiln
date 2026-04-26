---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "09"
subsystem: ops
tags: [onboarding, readiness, plugs]

requirements-completed: [BLOCK-04]

completed: 2026-04-21
---

# Phase 08 — Plan 09 Summary

Added singleton `operator_readiness` row, `Kiln.OperatorReadiness` probes + `mark_step/2`, `OnboardingGate` plug with `/onboarding` wizard, and a `RunDirector.start_run/1` guard returning `{:error, :factory_not_ready}` when the factory is not ready. `KILN_SKIP_OPERATOR_READINESS=1` bypasses checks.

## Self-Check: PASSED

- `grep -n "defmodule Kiln.OperatorReadiness" lib/kiln/operator_readiness.ex` — matches
- `grep -n "ready?\\|factory_ready" lib/kiln/operator_readiness.ex` — matches (`ready?/0`)
- `grep -n "OnboardingGate" lib/kiln_web/router.ex` — matches
- `grep -n 'live "/onboarding"' lib/kiln_web/router.ex` — matches
- `grep -n "Set up Kiln" lib/kiln_web/live/onboarding_live.ex` — matches
- `grep -n "OperatorReadiness" lib/kiln/runs/run_director.ex` — matches
- `test -f test/kiln/runs/run_director_readiness_test.exs` — yes
- `mix test test/kiln/operator_readiness_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/plugs/onboarding_gate_test.exs test/kiln/runs/run_director_readiness_test.exs` — green
