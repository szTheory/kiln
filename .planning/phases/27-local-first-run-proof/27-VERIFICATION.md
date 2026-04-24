# Phase 27 Verification

## Owning Proof Command

`mix kiln.first_run.prove`

Phase 27 cites this one command as the setup-ready local first-run proof for `UAT-04`.
It is intentionally narrower than `mix shift_left.verify` and broader than a LiveView-only check.

## Delegated Layers

1. `mix integration.first_run`
   Proves the real local topology contract: `.env`, Docker Compose data plane, host Phoenix boot, and `/health`.
2. `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`
   Proves the operator-visible setup-ready path: `/settings` return context into `hello-kiln`, `Start run`, and arrival on `/runs/:id` with the stable `#run-detail` proof surface.

## Scope

This command is the Phase 27 proof for the setup-ready local first-run journey only.
It does not claim to replace the broader merge-authority suite, `mix shift_left.verify`, or direct shell ownership of `test/integration/first_run.sh`.

## Execution Note

Verified on 2026-04-24 with `mix kiln.first_run.prove`. The local topology layer reached `/health` with `status="ok"` and the focused LiveView layer passed the targeted `templates` and `run_detail` suites in `MIX_ENV=test`.
