---
id: SEED-011
status: parked
planted: 2026-04-25
planted_during: v0.8.0 milestone open / pre-Phase-36 scoping (operator surfaced from prior knowledge of own Sigra repo)
trigger_when: Phase 36 (Remote Access & Operator Auth) scoping begins OR SEED-002 / SEED-004 light up OR any later milestone introduces multi-operator / RBAC / SSO needs
scope: Small-Medium (library evaluation + integration spike; could subsume most of 36-01 if adopted)
---

# SEED-011: Adopt Sigra as Kiln's Auth Library (Build vs Adopt for Phase 36)

## Why This Matters

Phase 36 (Remote Access & Operator Auth) in v0.8.0 introduces the first auth surface in Kiln. Per `.planning/milestones/v0.8.0-ROADMAP.md` it covers:

- **36-01**: Single-operator auth (password / passkey) for the Phoenix dashboard
- **36-02**: Remote Docker Compose profile (Tailscale / Cloudflare sidecar)
- **36-03**: Verify remote connectivity & auth-gate posture

Sigra (`~/projects/sigra`, MIT, v0.2.4, same author) is a Phoenix 1.8+ auth library that already ships exactly the 36-01 surface — and more. Reusing it would avoid Kiln re-implementing security-critical primitives (password hashing, WebAuthn ceremonies, MFA, session token rotation, rate limiting) which are easy to get wrong and expensive to maintain. The hard parts of auth aren't the LiveViews; they're the cryptographic edges, and those are exactly what Sigra centralizes.

The note here is *not* "adopt Sigra" — it's "make build-vs-adopt a deliberate first-turn question when Phase 36 discussion opens, instead of defaulting to bespoke Kiln auth code."

## What Sigra provides that overlaps Phase 36

From `~/projects/sigra/.planning/PROJECT.md` and source survey:

- Argon2id password hashing (with bcrypt migration path)
- WebAuthn / FIDO2 passkeys (via `wax_`)
- Database-backed sessions with device + IP metadata + revocation
- MFA: TOTP (`NimbleTOTP`) + backup codes
- OAuth 2.0 / OIDC (via `assent`, 20+ providers — useful if Kiln ever exposes "Log in with GitHub" for the operator, which would also compose with SEED-004 GitHub credential work)
- Magic links (Swoosh mailer)
- Rate limiting (Hammer, optional)
- API tokens (JWT or bearer reference tokens)
- Structured audit logging
- Optional admin LiveView panel

License: MIT. Phoenix `~> 1.8`, Ecto `~> 3.12`, Elixir `~> 1.18` — compatible with Kiln's stack (Phoenix 1.8.5, Ecto 3.13, Elixir 1.19.5).

## Integration model

Sigra is a Hex library + generators (Pow-style hybrid):

1. `{:sigra, "~> 0.2"}` in `mix.exs`
2. `mix sigra.install <Context> <Module> <table>` (e.g. `mix sigra.install Operators User operators`) generates context + schemas + migrations + routes + LiveViews **into Kiln**
3. Generated code is plain Elixir we own and customize freely
4. Security-critical code stays inside the library and receives patches via `mix deps.update`
5. Generator branches let us pick a minimal surface: `--no-live` (controllers only), `--api` (JWT/bearer), `--admin`, `--no-passkeys`, `--no-organizations`

This composes well with Kiln's bounded-context discipline: the generated context can drop straight into a new `Kiln.Operators` (or similar) context without crossing existing boundaries.

## When to Surface

- **First turn of Phase 36 discussion** — frame as "build vs adopt Sigra" before any 36-01 plan is drafted.
- **Earlier if SEED-002 (Remote Operator Control Plane) or SEED-004 (Credential Management) light up** — both already lean on auth.
- **Any future milestone** that introduces multi-operator, RBAC, SSO, or organization concepts (Sigra ships those today; Kiln would otherwise build them from scratch).

## Decisions to make at trigger time

1. **Schema alignment** — does Sigra's `Accounts.User` shape compose with Kiln's `SEC-01` secret-reference contract (secret names in DB, values in `persistent_term`, redacted via `@derive {Inspect, except: [...]}` )? Sigra encrypts sensitive fields via `cloak_ecto`; Kiln's `SEC-01` is reference-only. These are not in conflict but must be reconciled (likely: store *user records* via Sigra, store *external API keys* via Kiln's existing pattern).
2. **Session plug ownership** — Kiln LiveViews adopt Sigra's generated session plug as-is, or wrap it to enforce Kiln-specific bounded-context invariants?
3. **Audit ledger compatibility** — Sigra emits structured audit events. Kiln's `Audit.Event` ledger is INSERT-only with three-layer defense (REVOKE + trigger + RULE — see `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` D-12). Either Sigra's audit shape is forwarded into Kiln's `Audit` context (preferred) or a separate `auth_audit_events` table is admitted. Decide explicitly.
4. **Version pinning** — Sigra is pre-1.0. Either pin to a specific version + accept upgrade work milestone-by-milestone, or fork at integration time and own the diff. Pre-1.0 means breaking changes are possible.
5. **UI / brand alignment** — Sigra's generated LiveViews must be re-skinned to Kiln's brand contract (`prompts/kiln-brand-book.md`: Coal/Char/Iron/Bone/Ash palette, Inter/Plex Mono typography, calm/restrained/precise voice). Generator output is unlikely to match out of the box; budget the re-skin.

## Risks / Open questions

- **Audit-ledger contract mismatch** — Kiln's INSERT-only Postgres-trigger contract is a hard invariant. Any Sigra code path that updates or deletes audit rows would need to be excised or routed elsewhere. Verify before adoption.
- **Pre-1.0 churn** — `0.2.x` implies architectural stability but breaking-change tolerance. A locked Phase 36 surface would either pin a version or fork.
- **Brand drift** — generators emit serviceable but generic auth UIs; Kiln's brand bar (calm, restrained, "no AI magic") will require a re-skin pass.
- **Bounded-context boundary** — generated `Accounts` context must respect Kiln's 13-context layout (D-97) and `mix check_bounded_contexts` enforcement. Naming and placement matter.
- **Same-author bias** — easy adoption story can mask integration work. The build-vs-adopt question should be answered honestly on technical merits, not on familiarity.

## Relationship to existing scope

- **Reinforces SEED-002 (Remote Operator Control Plane)** — SEED-002 already discusses "Auth (Medium)" and explicitly names "single-operator passkey" / WebAuthn for the dashboard. Sigra is the concrete library that implements that surface.
- **Composes with SEED-004 (Credential Management)** — SEED-004 covers `gh` / git-push credentials (which Kiln stores as secret references). Sigra covers *operator-facing* auth. The two are complementary, not overlapping. Sigra's OAuth (assent) could later let the operator use GitHub OAuth as the dashboard login, which would unify the two surfaces — but that's a SEED-004-meets-SEED-011 v2 question.
- **Lands inside Phase 36 if adopted** — this seed does not become its own phase. The decision is "use Sigra inside 36-01" vs "hand-roll inside 36-01."
- **Distinct from multi-tenancy** — `PROJECT.md` Out of Scope rules out multi-tenant / SaaS / team in v1. Sigra ships organization support; we'd keep it disabled (`--no-organizations`) for v1, leave the door open for later.

## Breadcrumbs

- `~/projects/sigra/.planning/PROJECT.md` — Sigra capability source
- `~/projects/sigra/README.md` — install + generator usage
- `~/projects/sigra/mix.exs` — version, deps, hex publishing status
- Kiln `.planning/seeds/SEED-002-remote-operator-dashboard.md` — cluster-mate (auth slice)
- Kiln `.planning/seeds/SEED-004-credential-management.md` — cluster-mate (external creds)
- Kiln `.planning/milestones/v0.8.0-ROADMAP.md` — Phase 36 spec source of truth
- Kiln `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — D-12 audit ledger INSERT-only contract (relevant to decision #3)
- Kiln `prompts/kiln-brand-book.md` — re-skin contract for any generated LiveViews

## Recommended next step when triggered

1. Open Phase 36 discussion (`/gsd-discuss-phase 36`) with **"build vs adopt Sigra"** as the framing question for 36-01 — don't let the bespoke-auth path become the silent default.
2. Run a 1–2 hour spike on a throwaway branch:
   - `mix sigra.install Operators User operators --no-organizations`
   - Inspect generated context, schemas, migration, routes, LiveViews
   - Map each generated module to Kiln's bounded-context layout — identify any boundary or `mix xref --format cycles` violations
   - Verify Sigra's audit emission can be redirected into Kiln's `Audit.Event` ledger without violating INSERT-only
3. Document spike outcome as Phase 36 CONTEXT input; the decision (adopt / fork / hand-roll) gets recorded as a phase decision (D-NN) before plans are drafted.
4. If adopted, plan the brand re-skin as an explicit 36-01 sub-task — generated UI does not ship as-is.
