# Phase 36: Remote Access & Operator Auth - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Secure the Phoenix dashboard for remote use: add single-operator auth (passkey + password) via Sigra, add a Tailscale-based `remote` Docker Compose profile for off-host access, and verify the auth gate and remote connectivity posture through automated tests plus a documented manual smoke runbook.

This phase does NOT add: multi-operator / RBAC / SSO, Cloudflare Tunnel support, push notifications, mobile-optimised layouts, run-kickoff-from-mobile UX, or any public-facing read-only surface. Those belong in future phases per SEED-002 scope tiers.

</domain>

<decisions>
## Implementation Decisions

### Auth library (36-01)
- **D-01:** Adopt Sigra (`{:sigra, "~> 0.2"}`) as Kiln's auth library. Run `mix sigra.install Operators Operator operators --no-organizations` to generate host-owned auth code. Passkey (WebAuthn) and password are both enabled as primary auth factors — REMOTE-01's "Passkey or Password" means either is sufficient, not pick-one. Pin to `~> 0.2`; accept pre-1.0 churn risk with version-locked upgrades at milestone boundaries. All generated LiveViews must be re-skinned to Kiln brand book (Coal/Char/Iron/Bone/Ash palette, Inter + IBM Plex Mono, calm/restrained/precise voice).
- **D-02:** Accept Sigra's `wax_` dependency for WebAuthn ceremonies. Kiln does not call `wax_` directly — Sigra owns the full ceremony flow (registration + authentication). No library swap needed.

### Session strategy (36-01)
- **D-03:** Sigra's generated session plug loads the authenticated operator from DB-backed session tokens. A downstream modification to `KilnWeb.Plugs.Scope` reads `conn.assigns.current_operator` (set by Sigra's plug) and builds `Kiln.Scope` with the operator attached. Unauthenticated requests still receive `Kiln.Scope.local()` — this is the read-only / redirect-to-login boundary. `Kiln.Scope` remains the single authority for "who is the current operator" across all LiveViews and controllers. `KilnWeb.LiveScope` on_mount updated to carry operator from session into socket assigns.
- **D-04:** Operator bootstrapped via `mix kiln.setup_operator` — an idempotent Mix task that seeds the single operator record (prompts for email + password, optionally registers a passkey). Sigra's generated registration LiveViews are stripped or gated behind "no operator exists yet" logic so the web UI cannot create additional operators. No signup flow, no email verification, no password reset email — single-operator system with no email infrastructure.
- **D-09:** Sessions are long-lived (30-day TTL), with silent token rotation on each request. No rate limiting on login — Tailscale (D-05) already limits network reach to the operator's private tailnet. This matches the "check in from phone during commute" usage pattern described in SEED-002.

### Audit integration (36-01)
- **D-08:** Sigra audit events (login, logout, failed attempt, passkey registration, session revocation) are forwarded into Kiln's existing `Audit.Event` ledger via an adapter in the generated `Kiln.Operators` context. Single-ledger invariant is non-negotiable (D-12 from Phase 1: INSERT-only with REVOKE + trigger + RULE three-layer defense). Sigra's own `auth_audit_events` migration is either not generated or the table is not created. All auth audit queries go through `Kiln.Audit`.

### Bounded context (36-01)
- **D-10:** New bounded context `Kiln.Operators` with schema `Kiln.Operators.Operator` and table `operators`. Added to `mix check_bounded_contexts` allow-list. Aligns with Kiln's existing "Operator" terminology (not "User"). Sigra generator invocation: `mix sigra.install Operators Operator operators --no-organizations`.

### Remote access (36-02)
- **D-05:** Tailscale sidecar only in the `remote` Docker Compose profile. `tailscale/tailscale` Docker image joins the operator's tailnet; dashboard reachable at a stable `https://kiln.tailnet-name.ts.net` MagicDNS address with automatic HTTPS. Requires operator-provided Tailscale account + auth key via ENV (`TS_AUTHKEY`). No public internet exposure. Cloudflare Tunnel is explicitly out of scope for v0.8.0 — can be added in a future phase.

### Auth gate posture (36-01 + 36-03)
- **D-06:** Fully locked dashboard — all routes require authentication. Unauthenticated requests to any route redirect to the login page. Only `/health` is unauthenticated (already handled by `Kiln.HealthPlug` at the endpoint level before the router pipeline — see comment in `router.ex`). No read-only public surface. Two-layer defense: Tailscale limits network reach, auth gates application access.

### Verification scope (36-03)
- **D-07:** Local automated verification (CI-friendly): integration tests assert that every route redirects to login when unauthenticated and passes through when authenticated. Compose `remote` profile verified via `docker compose --profile remote config` structural validation plus a test that the Tailscale service definition exists with correct bindings. No real Tailscale connection tested in CI. A documented manual remote smoke runbook is provided for operators: "start `remote` profile with your Tailscale auth key, access `https://kiln.tailnet-name.ts.net` from another device, confirm login gate."

### Agent's Discretion
- Exact Sigra generator flags beyond `--no-organizations` (e.g., `--no-magic-links`, `--no-totp`) — agent should strip features Kiln doesn't need in v0.8.0.
- Exact `Kiln.Scope` struct field naming for the operator reference (`scope.operator` vs `scope.current_operator`).
- Login page layout and microcopy, as long as it follows the Kiln brand book.
- Exact Tailscale Docker image tag and Compose service configuration details.
- Exact session token rotation interval (per-request is the default; agent may adjust if Sigra docs recommend otherwise).
- Whether `mix kiln.setup_operator` also offers passkey registration inline or defers that to the web UI after first login.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth
- `.planning/milestones/v0.8.0-ROADMAP.md` — Phase 36 scope (36-01, 36-02, 36-03), milestone ordering
- `.planning/milestones/v0.8.0-REQUIREMENTS.md` — REMOTE-01, REMOTE-02, REMOTE-03 acceptance criteria
- `.planning/PROJECT.md` — solo-operator posture, bounded-autonomy model, brand book pointer, key decisions
- `.planning/STATE.md` — current milestone posture, v0.8.0 readiness

### Seeds (design intent)
- `.planning/seeds/SEED-002-remote-operator-dashboard.md` — remote access vision, scope tiers, tunnel options analysis, auth requirements
- `.planning/seeds/SEED-011-sigra-auth-library-integration.md` — build-vs-adopt framing, Sigra capability survey, integration model, risks, decisions checklist
- `.planning/seeds/SEED-004-credential-management.md` — complementary seed for external API key management (not in Phase 36 scope, but referenced by SEED-002 and SEED-011)

### Prior phase contracts (relevant invariants)
- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — D-12: Audit.Event INSERT-only three-layer defense (REVOKE + trigger + RULE). Auth audit emission MUST comply.
- `prompts/kiln-brand-book.md` — visual/voice contract for any generated or new UI (login page, passkey registration)

### Sigra library (auth source)
- `~/projects/sigra/mix.exs` — v0.2.5, deps, compatibility
- `~/projects/sigra/README.md` — install + generator usage + flags
- `~/projects/sigra/.planning/PROJECT.md` — Sigra capability map

### Codebase integration points
- `lib/kiln_web/router.ex` — current route structure, no auth pipeline yet, `/health` handled by endpoint plug
- `lib/kiln_web/plugs/scope.ex` — `Kiln.Scope.local()` unconditional assignment + `KilnWeb.LiveScope` on_mount (both need operator-aware extension)
- `lib/kiln_web/endpoint.ex` — `Kiln.HealthPlug` mounted before router (unauth health probe contract)
- `compose.yaml` — current services (db, dtu, otel-collector, jaeger), no `remote` profile yet

### Roadmap quirk
- `.planning/ROADMAP.md` — Phase 36 entry is inside a `<details>` block; `roadmap.get-phase` may not see it. Source of truth for Phase 36 scope is `v0.8.0-ROADMAP.md` + `v0.8.0-REQUIREMENTS.md`, not the top-level ROADMAP.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KilnWeb.Plugs.Scope` + `KilnWeb.LiveScope` — already wired into every route and LiveView on_mount; the natural seam for carrying operator identity
- `Kiln.HealthPlug` — endpoint-level health probe, already bypasses the router; no changes needed for auth gate
- `Kiln.Audit` context + `Audit.Event` schema — the target for Sigra audit event forwarding
- `KilnWeb.CoreComponents` — `<.input>`, `<.icon>`, `<.form>` components for building the login page
- `KilnWeb.Layouts` — `<Layouts.app>` wrapping pattern for all LiveViews

### Established Patterns
- Bounded contexts enforced by `mix check_bounded_contexts` — new `Kiln.Operators` context must be added to the allow-list
- `mix kiln.*` task namespace — operator bootstrap task follows `mix kiln.setup_operator` convention
- INSERT-only audit ledger with REVOKE + trigger + RULE — hard invariant for any new audit emission
- Brand book compliance — Coal/Char/Iron/Bone/Ash palette, Inter + Plex Mono, borders over shadows, state-aware components

### Integration Points
- `router.ex` — needs new `:authenticated` pipeline with Sigra session plug, splitting routes into authenticated vs unauthenticated live_sessions
- `compose.yaml` — needs `remote` profile with Tailscale service definition
- `mix.exs` — needs `{:sigra, "~> 0.2"}` dependency
- `config/` — needs Sigra configuration (session TTL, token rotation, WebAuthn relying party)
- Ecto migrations — operator table, session table (generated by Sigra)

</code_context>

<specifics>
## Specific Ideas

- SEED-011 recommends a 1–2 hour spike on a throwaway branch before planning. The user chose to adopt directly (D-01) rather than spike first, so the planner should account for potential generator-output surprises (bounded-context violations, migration conflicts) as known risks in the plan, not as blockers.
- Sigra's `--no-organizations` flag is confirmed. The planner should also evaluate `--no-magic-links` and `--no-totp` since Kiln has no email infrastructure and MFA beyond passkeys is not in v0.8.0 scope.
- The operator's dev host has a known `sigra-uat-postgres` container that has historically conflicted on port 5432. This is a pre-existing deferred item (since Phase 1) and is NOT a Phase 36 concern — `KILN_DB_HOST_PORT` ENV override already exists in `compose.yaml`.

</specifics>

<deferred>
## Deferred Ideas

- **Cloudflare Tunnel sidecar** — alternative to Tailscale for operators who prefer public DNS + Cloudflare Access. Deferred per D-05; can be a future `remote-cloudflare` Compose profile.
- **Read-only public surface** — unauthenticated dashboard view for status monitoring. Deferred per D-06; adds audit complexity for "what counts as read-only" and risks leaking operator context.
- **Login rate limiting** — Hammer-based rate limiting on auth endpoints. Deferred per D-09; Tailscale already limits network reach. Can be added if Kiln ever supports public-internet access.
- **Push notifications** — SEED-002 mentions ntfy.sh / Slack webhook for checkpoint/block/escalation alerts. Not in Phase 36 scope.
- **Mobile-optimized layout** — SEED-002 notes LiveView needs thoughtful mobile layout. Not in Phase 36 scope; current dashboard works on mobile browsers, just not optimised.
- **Multi-factory orchestration** — SEED-002 §4, supervising N Kilns from one view. Out of scope for v0.8.0 entirely.
- **OAuth / "Log in with GitHub"** — Sigra ships OAuth via assent. Deferred; would compose with SEED-004 credential work in a future milestone.
- **MFA (TOTP + backup codes)** — Sigra ships these. Passkeys already provide phishing-resistant second factor via WebAuthn. TOTP deferred unless operator requests it.

</deferred>

---

*Phase: 36-remote-access-and-operator-auth*
*Context gathered: 2026-04-25*
