---
phase: 36-remote-access-and-operator-auth
plan: 02
subsystem: infra
tags: [docker-compose, tailscale, remote-access, testing]

# Dependency graph
requires: []
provides:
  - Profile-gated Tailscale sidecar for private dashboard access
  - Compose regression test that locks the remote service shape
  - Operator docs and env sample entries for starting the tunnel
affects:
  - 36-03
  - README.md
  - .env.sample

# Tech tracking
tech-stack:
  added: [tailscale/tailscale container, Docker Compose remote profile, YamlElixir-based compose shape test]
  patterns: [profile-gated sidecar, env-driven tunnel target, host-gateway access to host Phoenix]

key-files:
  created: [test/kiln/remote_compose_profile_test.exs, .planning/phases/36-remote-access-and-operator-auth/36-02-SUMMARY.md]
  modified: [compose.yaml, .env.sample, README.md]

key-decisions:
  - "Use a remote-only Tailscale sidecar so the default compose surface stays unchanged."
  - "Serve the host Phoenix app through host.docker.internal with env-based auth and tunnel target defaults."

patterns-established:
  - "Profile-gated infra: remote-only services stay isolated from the ordinary local path."
  - "Compose config regression: assert rendered service shape rather than relying on manual inspection."

requirements-completed: [REMOTE-02]

# Metrics
duration: 14m
completed: 2026-04-26
---

# Phase 36: Remote Access & Operator Auth Summary

**Remote Tailscale access for the dashboard now ships as a profile-gated sidecar with env-based auth and a regression test that prevents accidental public-port drift.**

## Performance

- **Duration:** 14m
- **Started:** 2026-04-25T17:35:35Z
- **Completed:** 2026-04-26T00:08:31Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Added a `remote` Compose profile with a Tailscale sidecar that serves the host dashboard over tailnet only.
- Locked the remote compose shape in an executable regression test.
- Documented the operator setup path in `.env.sample` and `README.md`.

## Task Commits

1. **Task 1: Lock the remote compose shape in tests** - `405a884` (test)
2. **Task 2: Add the remote profile and operator setup guidance** - `156d7fe` (feat)

## Files Created/Modified
- `test/kiln/remote_compose_profile_test.exs` - regression test for the remote compose shape
- `compose.yaml` - adds the profile-gated Tailscale sidecar and state volume
- `.env.sample` - adds TS_AUTHKEY and optional tunnel overrides
- `README.md` - documents remote start steps for operators

## Decisions Made
- Keep the remote tunnel additive so normal local compose usage is unchanged.
- Default the tunnel target to `http://host.docker.internal:4000` so the host Phoenix app can stay on its normal port.
- Use environment variables for the auth key and tunnel target so operators can start the sidecar from `.env`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `mix test` needed a temporary local Postgres instance because the repo boot path expects a reachable test database.
- The compose regression initially exposed a command interpolation issue; the final config now escapes shell variables so the container sees the env values at runtime.

## User Setup Required
External services require manual configuration.

- Add `TS_AUTHKEY` from the Tailscale admin console.
- Optional: set `TAILSCALE_HOSTNAME` or `TAILSCALE_TUNNEL_TARGET` if the defaults do not match your host setup.
- Start the tunnel with `docker compose --profile remote up -d tailscale` after the host Phoenix app is running.

## Next Phase Readiness
- Phase 36-03 can build the operator smoke checklist on top of the locked remote profile shape.
- No blocking issues remain in this slice.

## Self-Check: PASSED

- Summary file exists on disk.
- Task commits `405a884` and `156d7fe` are present in git history.

---
*Phase: 36-remote-access-and-operator-auth*
*Completed: 2026-04-26*
