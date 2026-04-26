---
created: 2026-04-26T16:01:54.503Z
title: Wire real Sigra controllers (36-01 followup)
area: auth
files:
  - lib/kiln_web/controllers/sigra_stub_controllers.ex
  - lib/kiln_web/controllers/registration_html.ex
  - lib/kiln_web/controllers/mfa_settings_html.ex
  - lib/kiln_web/router.ex:130-149
---

## Problem

Phase 36-01 (commit 89c8f26 — Sigra-backed operator auth) shipped HTML
templates and `redirect(to: ~p"/users/...")` calls for ~10 routes that
were never wired into the router. Templates without controllers, and a
router declaration referencing a non-existent `RegistrationController`,
were silently tolerated by `mix phx.server` in dev (warnings only) but
broke CI's `mix compile --warnings-as-errors`.

To unblock PR #1 (docker boot fixes), commit `d093c85` added stub
controllers in `lib/kiln_web/controllers/sigra_stub_controllers.ex`
that all return HTTP 501 with a TODO message, and added the matching
router entries. This makes `mix check` pass but every operator-auth
flow involving register, MFA settings, or reactivation hits a 501
wall.

## Solution

Wire each stub against the real Sigra implementations:

- **RegistrationController** (`new`, `create`) — render the existing
  `registration_html.ex` template; create flow likely needs a Sigra
  user changeset + Repo insert.
- **MFASettingsController** (`show`, `disable`, `enroll`, `confirm`,
  `complete`, `regenerate`, `revoke_trust`) — `mfa_settings_html.ex`
  is the view template; check Sigra's bundled MFA controller for the
  reference action shapes (`deps/sigra/lib/sigra_web/...` or its
  generator output).
- **SettingsController** (`show`) — operator settings page; may want
  to use a LiveView instead of a controller.
- **ReactivationController** (`new`) — account-reactivation flow
  triggered by `KilnWeb.UserAuth.check_account_active/2`.

Approach: probably easiest to run Sigra's installer/generator against
the current schema (e.g. `mix sigra.gen.oauth` or equivalent) and diff
the output, then port the actions module-by-module.

This is a multi-day phase, not a quick fix — file as `/gsd-add-phase`
when ready, with discuss-phase to scope what registration/MFA actually
needs to do for the v1 solo-operator persona before implementing.
