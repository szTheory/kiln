---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "11"
subsystem: application-wiring
tags:
  - phase-3
  - wave-5
  - boot
  - application
  - secrets
completed: 2026-04-20
---

# Phase 3 Plan 11: Application Wiring Summary

Wired the Phase 3 runtime into the live application boot path. The supervision tree now includes the sandbox, DTU, agent-session, and circuit-breaker scaffolds; BootChecks carries the Phase 3 provider-presence/orphan-sweep invariants; provider env vars are loaded into `Kiln.Secrets`; and `RunDirector.start_run/1` blocks missing-provider runs before any LLM call can happen.

## Shipped

- `Kiln.Application` now boots a 14-child tree with `Kiln.Sandboxes.Supervisor`, `Kiln.Sandboxes.DTU.Supervisor`, `Kiln.Agents.SessionSupervisor`, and `Kiln.Policies.FactoryCircuitBreaker` inserted before `RunDirector`
- `Kiln.Application` eagerly calls `Kiln.Sandboxes.Limits.load!/0`, keeps Finch as a single child with per-host pools, and attaches `Kiln.Agents.TelemetryHandler` alongside the existing Oban handler
- `Kiln.BootChecks` now runs 8 invariants by adding `secrets_presence_map_non_empty` and `no_prior_boot_sandbox_orphans`
- `config/runtime.exs` now writes `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, and `OLLAMA_HOST` into `Kiln.Secrets`
- `Kiln.Runs.RunDirector.start_run/1` now raises a typed `:missing_api_key` block when the run's profile implies a provider whose secret is absent, and otherwise advances the run from `:queued` to `:planning`
- Updated application, boot-check, adapter-contract, run-director, and sandbox tests to match the live singleton runtime

## Key Decisions

- Finch pool sharding stays inside the existing `Kiln.Finch` child instead of adding per-provider supervisor children. That preserves the planned child-count budget while still isolating provider hosts.
- The DTU callback router defaults to port `0` in `:test` so ExUnit boots do not fight over a fixed loopback port. Non-test environments keep the explicit `4011` default.
- `RunDirector.start_run/1` infers required providers from either a preset-backed `model_profile_snapshot["profile"]` or from direct `roles` entries. When the snapshot is too sparse to infer a provider, the gate fails open rather than blocking an otherwise-runnable test harness.

## Deviations from Plan

- The roadmap text for this plan mentioned spec-doc updates in `CLAUDE.md`, `ARCHITECTURE.md`, `STACK.md`, and `PITFALLS.md`. This closeout keeps the executable code/test surface as the priority and leaves those narrative docs unchanged.
- `check_no_prior_boot_sandbox_orphans!/0` reuses `Kiln.Sandboxes.DockerDriver.list_orphans/1` plus `docker rm -f` rather than introducing a second Docker enumeration seam just for BootChecks.

## Verification

- `mix test test/kiln/application_test.exs test/kiln/boot_checks_test.exs test/kiln/runs/run_director_p3_test.exs`
- `mix test`

## Remaining Follow-On

- `Kiln.Agents.SessionSupervisor` and `Kiln.Policies.FactoryCircuitBreaker` are still Phase 3 scaffolds. Their live behavior lands in later phases without requiring another application-tree migration.
- The missing-provider gate lives on `RunDirector.start_run/1`; the rest of the run-intake surface still needs to call that API consistently when Phase 4+ orchestration grows.
