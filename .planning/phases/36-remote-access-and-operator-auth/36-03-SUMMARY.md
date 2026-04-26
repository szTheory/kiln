---
phase: 36-remote-access-and-operator-auth
plan: 03
subsystem: auth/infra
tags: [phoenix, liveview, tailscale, remote-access, testing]

# Dependency graph
requires:
  - phase: 36-01
    provides: Sigra-backed operator auth and the authenticated browser session boundary
  - phase: 36-02
    provides: profile-gated remote Tailscale access for the dashboard
provides:
  - Route-level regression coverage for public health and dashboard auth gates
  - A concise operator smoke runbook for tailnet verification
affects:
  - 36-04
  - remote operator verification
  - dashboard auth posture

# Tech tracking
tech-stack:
  added: [ExUnit route regression, Markdown operator runbook]
  patterns: [live/2 redirect assertions, stable dashboard DOM-id checks, explicit failure-signaling runbooks]

key-files:
  created: [test/kiln_web/route_gate_test.exs, docs/remote-access-smoke.md, .planning/phases/36-remote-access-and-operator-auth/36-03-SUMMARY.md]
  modified: [.planning/STATE.md, .planning/ROADMAP.md, .planning/REQUIREMENTS.md]

key-decisions:
  - "Use a focused route-gate regression that checks /health, unauthenticated redirects, and authenticated dashboard rendering with stable IDs."
  - "Document the remote smoke path as an operator checklist with exact TS_AUTHKEY + MagicDNS steps and clear success/failure signals."

patterns-established:
  - "Route gate tests should assert real redirects and real dashboard IDs instead of implementation details."
  - "Remote operator docs should name the exact compose command and the expected login gate before dashboard access."

requirements-completed: [REMOTE-01, REMOTE-02, REMOTE-03]

# Metrics
duration: 22m
completed: 2026-04-26
---

# Phase 36: Remote Access & Operator Auth Summary

**Dashboard route-gate regression plus tailnet smoke runbook for remote operator verification.**

## Performance

- **Duration:** 22m
- **Started:** 2026-04-26T07:15:00Z
- **Completed:** 2026-04-26T07:37:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added a route-level regression that keeps `/health` public while protecting dashboard routes.
- Confirmed authenticated dashboard access still reaches the run board.
- Wrote a short remote smoke runbook with the `docker compose --profile remote` + `TS_AUTHKEY` path and MagicDNS checks.

## Task Commits

1. **Task 1: Add the route-gate regression** - `a87f1af` (test)
2. **Task 2: Write the remote smoke runbook** - `d0255ec` (docs)

## Files Created/Modified
- `test/kiln_web/route_gate_test.exs` - route-level regression for public health and dashboard auth gates
- `docs/remote-access-smoke.md` - operator smoke checklist for tailnet access

## Decisions Made
- Keep `/health` asserted with the plain path because it is endpoint-level, not router-level.
- Use stable dashboard DOM ids in the regression so the test survives UI refactors.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- The verification shell did not have `python`, so the runbook content check used `elixir -e` instead.
- `mix test` emitted pre-existing route warnings from other Sigra-generated paths, but the targeted regression still passed.
- The `gsd-sdk` state helper could not parse the existing STATE.md position fields, so the phase/state/roadmap/requirements files were patched directly to keep the milestone SSOT current.

## User Setup Required
None - no external service configuration required for this slice.

## Next Phase Readiness
- Route-gate coverage is in place for the remote auth boundary.
- The operator now has a concrete tailnet smoke checklist to run from another device.

## Self-Check: PASSED

- Summary file exists on disk.
- Task commits `a87f1af` and `d0255ec` are present in git history.

---
*Phase: 36-remote-access-and-operator-auth*
*Completed: 2026-04-26*
