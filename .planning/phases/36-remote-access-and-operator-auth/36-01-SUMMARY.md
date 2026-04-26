---
phase: 36-remote-access-and-operator-auth
plan: 01
subsystem: auth
tags: [sigra, auth, passkeys, audit]

# Dependency graph
requires: []
provides:
  - Sigra-backed operator auth scaffold and session plumbing
  - Route-level auth redirects and LiveView gating
  - Operator bootstrap task and audit bridge into Kiln.Audit
affects:
  - router.ex
  - user_auth.ex
  - operators.ex
  - session_controller.ex
  - audit bridge tests

# Tech tracking
tech-stack:
  added: [Sigra auth, Cloak vault, passkey ceremony helpers]
  patterns: [single-operator auth, audit bridge, passkey stub hook]

key-files:
  created: [lib/kiln/operators/, lib/kiln_web/auth_error_handler.ex, lib/mix/tasks/kiln.setup_operator.ex, priv/repo/migrations/20260426000131_create_sigra_auth_tables.exs, priv/repo/migrations/20260426000132_add_active_organization_id_to_user_sessions.exs, priv/repo/migrations/20260426000133_create_user_passkeys.exs, test/kiln/audit_bridge_test.exs, test/kiln_web/router_auth_test.exs, test/kiln_web/session_controller_test.exs]
  modified: [config/config.exs, config/runtime.exs, lib/kiln/application.ex, lib/kiln/operators.ex, lib/kiln_web/controllers/confirmation_controller.ex, lib/kiln_web/controllers/reset_password_controller.ex, lib/kiln_web/controllers/session_controller.ex, lib/kiln_web/user_auth.ex]

requirements-completed: [REMOTE-01, REMOTE-03]

# Metrics
completed: 2026-04-26
---

# Phase 36-01 Summary

**Kiln now has a Sigra-backed single-operator auth scaffold with login redirects, passkey/password session plumbing, and an audit bridge into `Kiln.Audit`.**

## Accomplishments
- Added the generated Sigra auth context, controllers, helpers, and migrations for operators, sessions, and passkeys.
- Wired login flows through `KilnWeb.UserAuth` and `Kiln.Operators` so authenticated requests reach the dashboard while unauthenticated requests redirect to `/users/log_in`.
- Bridged successful login events into the existing `Kiln.Audit` ledger and added tests for login, redirect, and audit behavior.
- Added the single-operator bootstrap task and bounded-context/boot-check updates needed for the new auth context.

## Verification
- `DATABASE_URL=ecto://kiln:kiln_dev@localhost:5434/kiln_test mix test test/kiln_web/session_controller_test.exs test/kiln_web/router_auth_test.exs test/kiln/audit_bridge_test.exs` ✅
- `bash script/precommit.sh` surfaced broader repo-wide failures unrelated to this slice.

## Notes
- Passkey tests require `CLOAK_KEY` at runtime because the generated vault is now supervised.
- The passkey ceremony tests use the injected stub hook so the login path stays deterministic.

---
*Phase: 36-remote-access-and-operator-auth*
*Plan: 01*
