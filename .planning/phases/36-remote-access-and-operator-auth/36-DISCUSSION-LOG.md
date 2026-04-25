# Phase 36: Remote Access & Operator Auth - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 36-remote-access-and-operator-auth
**Areas discussed:** Auth library (build vs adopt), WebAuthn library, Session strategy, Operator bootstrap, Tunnel sidecar, Auth gate posture, Verification scope, Audit integration, Session lifetime, Bounded context naming

---

## Q1: Auth Library — Build vs Adopt Sigra (SEED-011 framing)

| Option | Description | Selected |
|--------|-------------|----------|
| Adopt Sigra (passkey + password) | `mix sigra.install Operators User operators --no-organizations`, pin `~> 0.2`, brand re-skin required | ✓ |
| Hand-roll on `phx_gen_auth` + `wax` | More bespoke code, tighter control, reinvents Sigra primitives | |
| Adopt Sigra `--no-passkeys` | Password-only via Sigra, add passkeys later | |
| Spike Sigra first | 1–2 hr throwaway branch before committing | |

**User's choice:** Option 1 — Adopt Sigra with passkey + password
**Notes:** SEED-011 directly framed this as the first-turn question. User accepted the recommended path. Sigra audit emission → Kiln Audit.Event noted as a planning concern, not a blocker.

---

## Q2: WebAuthn Library

| Option | Description | Selected |
|--------|-------------|----------|
| Accept Sigra's `wax_` | No extra library decision; Sigra wraps ceremony flow | ✓ |
| Swap `wax_` for `webauthn_components` | Would require forking/patching Sigra output | |

**User's choice:** Option 1 — Accept Sigra's wax_
**Notes:** Follows naturally from D-01. `wax_` is the standard Elixir WebAuthn library.

---

## Q3: Session Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Sigra session plug → feeds Kiln.Scope | Sigra loads operator from DB session; Plugs.Scope builds Scope with operator attached | ✓ |
| Replace Kiln.Scope with Sigra assigns | Drop Scope abstraction, use current_operator directly | |
| Wrap Sigra's session plug entirely | Custom plug delegating to Sigra internals | |

**User's choice:** Option 1 — Sigra session plug feeds Kiln.Scope
**Notes:** Kiln.Scope already wired into every LiveView and plug. Extending it is the smallest delta.

---

## Q3b: Operator Bootstrap

| Option | Description | Selected |
|--------|-------------|----------|
| `mix kiln.setup_operator` | Idempotent Mix task, strips/gates registration LiveViews | ✓ |

**User's choice:** Mix task bootstrap, strip Sigra registration LiveViews
**Notes:** No signup flow, no email verification, no password reset — single-operator system.

---

## Q4: Tunnel Sidecar (REMOTE-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Tailscale only | `tailscale/tailscale` Docker image, MagicDNS, auth key via ENV | ✓ |
| Cloudflare Tunnel only | `cloudflare/cloudflared`, public subdomain, more setup | |
| Both as separate profiles | `remote-tailscale` + `remote-cloudflare`, max flexibility | |
| Tailscale default + Cloudflare documented | Ship Tailscale, document Cloudflare as swap instructions | |

**User's choice:** Option 1 — Tailscale only
**Notes:** Matches SEED-002's "lowest-friction for solo operator" assessment. No public DNS, no cert management. Cloudflare deferred to future phase.

---

## Q5: Auth Gate Posture (REMOTE-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Fully locked — all routes require auth | Redirect to login, zero read-only surface | ✓ |
| Read-only public surface | Unauthenticated users see status (complex audit surface) | |
| Health endpoint only | `/health` unauth, everything else locked | |

**User's choice:** Option 1 — Fully locked
**Notes:** `/health` already bypasses router at endpoint level, so monitoring works regardless. Read-only surface rejected due to audit complexity and info-leak risk. Two-layer defense: Tailscale + auth.

---

## Q6: Verification Scope (36-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Local automated + documented manual smoke | Integration tests for auth gate + Compose structural validation; operator runbook for real Tailscale smoke | ✓ |
| Local only (no manual smoke docs) | CI-friendly tests only | |
| Full remote verification | Real Tailscale in CI; heavy, flaky | |

**User's choice:** Option 1 — Local automated + documented manual smoke
**Notes:** Auth gate is the security-critical contract proven by automated tests. Tailscale connectivity is infrastructure; documented runbook gives operator confidence without CI coupling.

---

## Q7: Sigra Audit → Kiln Audit.Event

| Option | Description | Selected |
|--------|-------------|----------|
| Forward into Kiln's Audit.Event | Adapter pattern, single ledger, D-12 compliance | ✓ |
| Separate `auth_audit_events` table | Two ledgers, zero integration risk | |

**User's choice:** Option 1 — Single ledger via adapter
**Notes:** INSERT-only invariant from D-12 (Phase 1) is non-negotiable. Single audit surface for queries.

---

## Q8: Session Lifetime & Security Posture

| Option | Description | Selected |
|--------|-------------|----------|
| 30-day sessions, token rotation, no login rate limit | Long-lived, matches "check from phone" pattern, Tailscale is network limiter | ✓ |
| 24-hour sessions, rotation, rate limiting | Tighter posture, daily re-auth | |
| Configurable via ENV | Default 30 days, operator-overridable | |

**User's choice:** Option 1 — 30-day sessions, no rate limit
**Notes:** Tailscale provides network-layer access control. Rate limiting deferred unless Kiln gains public-internet exposure.

---

## Q9: Bounded Context Naming

| Option | Description | Selected |
|--------|-------------|----------|
| `Kiln.Operators` / `Operator` / `operators` | New bounded context, matches Kiln terminology | ✓ |
| `Kiln.Auth` / `User` / `auth_users` | More generic, doesn't match vocabulary | |

**User's choice:** Option 1 — Kiln.Operators
**Notes:** Added to `mix check_bounded_contexts` allow-list. "Operator" is Kiln's established term for the human.

---

## Agent's Discretion

- Exact Sigra generator flags beyond `--no-organizations`
- Kiln.Scope struct field naming for operator reference
- Login page layout and microcopy (brand book compliance)
- Tailscale Docker image tag and Compose service config
- Session token rotation interval details
- Whether `mix kiln.setup_operator` includes inline passkey registration

## Deferred Ideas

- Cloudflare Tunnel sidecar (future `remote-cloudflare` profile)
- Read-only public surface (audit complexity, info-leak risk)
- Login rate limiting (Tailscale is network limiter for now)
- Push notifications (SEED-002 scope tier)
- Mobile-optimised layout
- Multi-factory orchestration (SEED-002 §4)
- OAuth / "Log in with GitHub"
- MFA (TOTP + backup codes) — passkeys already provide second factor
