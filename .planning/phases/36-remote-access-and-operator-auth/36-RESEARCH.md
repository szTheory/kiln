# Phase 36: Remote Access & Operator Auth - Research

**Gathered:** 2026-04-25
**Status:** Ready for planning

## Findings

- Sigra `~> 0.2` is a good fit for Phoenix 1.8 auth: it ships the session/login primitives, WebAuthn passkeys via `wax_`, DB-backed sessions, and audit hooks while leaving generated code in Kiln's repo.
- The lowest-surface install for Kiln is controller-first auth: `mix sigra.install Operators Operator operators --no-live --no-organizations --no-admin --yes`. That keeps the login page plain-HTTP, avoids unrelated LiveView/admin/org surface, and still leaves password + passkey login enabled.
- Kiln should keep `current_scope` as the public assign for LiveViews/controllers, but hydrate it from Sigra's authenticated operator/session state. `KilnWeb.Plugs.Scope` and `KilnWeb.LiveScope` are the seam.
- Remote access should be profile-gated in `compose.yaml`: a `remote` profile with only a Tailscale sidecar, no public dashboard ports, and `TS_AUTHKEY` as the human-provided secret.
- Verification should be split: automated tests for login/route gating and compose-shape validation, plus a short manual smoke runbook for the tailnet URL.

## Recommended implementation shape

1. Install Sigra into `Kiln.Operators` and keep the generated auth code owned by Kiln.
2. Route all dashboard LiveViews behind an authenticated browser pipeline; leave `/health` untouched.
3. Seed the single operator with one idempotent Mix task instead of adding any signup surface.
4. Add the `remote` compose profile and a smoke doc that points operators at the tailnet URL.

---

*Phase: 36-remote-access-and-operator-auth*
*Research gathered: 2026-04-25*
