---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "07"
subsystem: sandbox-cas-substrate
tags:
  - phase-3
  - wave-3
  - sandboxes
  - cas
  - env-builder
  - sand-04
  - sec-01
completed: 2026-04-20
---

# Phase 3 Plan 07: Sandbox Substrate Summary

Shipped the pure-data half of the sandbox system: image metadata, resource limits, container launch spec defaults, env allowlist enforcement, and the CAS bridge in and out of `/workspace`.

## Shipped

- `priv/sandbox/base.Dockerfile` and `priv/sandbox/elixir.Dockerfile` with the locked Elixir/OTP/Alpine base, non-root `kiln` user, and baseline build tools
- `priv/sandbox/limits.yaml` plus `Kiln.Sandboxes.Limits` for stage-kind resource profiles loaded into `:persistent_term`
- `priv/sandbox/images.lock` and `mix kiln.sandbox.build` for pinned sandbox image refs and digests
- `%Kiln.Sandboxes.ContainerSpec{}` with all 18 D-116 fields and hardened D-117 defaults
- `Kiln.Sandboxes.ImageResolver` for language-to-image lookup from `images.lock`
- `Kiln.Sandboxes.EnvBuilder` for allowlisted `--env-file` generation with secret-shaped key rejection and `0600` file permissions
- `Kiln.Sandboxes.Hydrator` and `Kiln.Sandboxes.Harvester` for streaming CAS-to-workspace and workspace-to-CAS handoff
- 23 targeted tests passing across limits, container spec defaults, image resolution, env file policy, hydration, harvesting, and CAS round-trip behavior

## Key Decisions

- `ContainerSpec.defaults/0` returns empty `image_ref` and `image_digest` strings instead of `nil` so the struct remains valid under `@enforce_keys` while leaving actual image selection to the Docker driver.
- `EnvBuilder` rejects non-allowlisted keys separately from secret-shaped keys. That preserves the high-signal `:sandbox_env_contains_secret` path while still failing closed for stray variables.
- `Hydrator` resolves refs by SHA through `Artifacts.by_sha/1` and streams the first matching artifact row into the workspace. The artifact ref contract is CAS-centric, not `(stage_run_id, name)` centric.
- `Harvester` reuses `Artifacts.put/4` rather than introducing a sandbox-specific artifact write path, so `artifact_written` audit emission stays in the existing transaction boundary.
- Unknown harvested file extensions fall back to `:"text/plain"` because Phase 2 artifact enums do not yet include a generic binary content type.

## Deviations from Plan

- Added `test/kiln/sandboxes/container_spec_test.exs` to cover the D-116 struct shape explicitly. The plan listed the ContainerSpec behavior but not a dedicated test file.
- `Hydrator` uses `Artifacts.by_sha/1` plus `Artifacts.stream!/1` instead of `Artifacts.get/2`. Plain artifact refs do not carry `stage_run_id`, so `(stage_run_id, name)` lookup cannot satisfy the contract.
- `Harvester` currently skips subdirectories and symlink hardening remains deferred exactly as the plan threat model notes.
- `mix precommit` is referenced by the project instructions but no alias exists in `mix.exs`. I ran `mix check` instead; it surfaced pre-existing unrelated formatter/Credo/Dialyzer/boot-check failures outside this plan, so the plan closeout relies on the targeted sandbox verification suite.

## Verification

- `mix compile --warnings-as-errors`
- `mix test test/kiln/sandboxes/limits_test.exs test/kiln/sandboxes/container_spec_test.exs test/kiln/sandboxes/image_resolver_test.exs test/kiln/sandboxes/env_builder_test.exs test/kiln/sandboxes/hydrator_test.exs test/kiln/sandboxes/harvester_test.exs --max-failures=1`
- `ls priv/sandbox/base.Dockerfile priv/sandbox/elixir.Dockerfile priv/sandbox/limits.yaml priv/sandbox/images.lock`

## Remaining Follow-On

- `Kiln.Sandboxes.Limits.load!/0` is present but not yet wired into app boot. Plan 03-11 owns that integration.
- `mix kiln.sandbox.build` compiles and writes the lock file format, but the Docker build itself was not executed during this plan.
