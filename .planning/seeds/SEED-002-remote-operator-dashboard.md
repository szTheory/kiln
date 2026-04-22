---
id: SEED-002
status: parked
planted: 2026-04-18
planted_during: v0.1.0 / Phase 1 execution (captured mid-run from operator)
trigger_when: Phase 7 operator-dashboard scoping OR v1.0 release-prep OR first time operator says "I wish I could check progress from my phone"
scope: Large (spans deployment, auth, UI, and trust model)
---

# SEED-002: Remote Operator Control Plane

## Why This Matters

v1 Kiln is strictly local-first / solo-operator / Docker Compose (PROJECT.md hard constraint). That's correct for v1 — simplifies the trust model, scoping, and dogfood loop. But the moment Kiln works well, the shape of the usage flips:

- Operator wants a **powerful always-on host** (Mac Studio at home, a dedicated cloud instance) chugging on runs 24/7.
- Operator is NOT at that host. They're on a laptop in a coffee shop, or on a phone during a commute, or tethered from a hotel.
- Operator wants to **check in** (status, current stage, a screenshot of what's being built, recent audit-event stream), **give a nudge** (see SEED-001 — in-flight feedback), and possibly **kick off a new run** from a pre-vetted template — all remotely.
- Operator wants to supervise **multiple parallel dark factories** — not just one Kiln building one thing, but N Kilns each building something, all visible in a single remote view.

The local-first constraint is right for v1; the remote-access shape is how operators will actually *live* with Kiln once it works.

## When to Surface

- **Phase 7 (v0.1.0) operator-dashboard scoping** — the LiveView dashboard work naturally prompts "how far can I log in from?". Answering "localhost only" is a conscious scoping decision, not a default.
- **Post-v1 retrospective** — first natural checkpoint where the "one local Kiln" assumption can be relaxed.
- **First time the operator runs Kiln on a dedicated host** (Mac Studio, dedicated VM) and immediately reaches for phone/laptop to check status.
- **Any milestone touching auth / secrets management / multi-machine deployment.**

## Scope

**Large.** This is a cross-cutting capability spanning:

### 1. Deployment target (Small–Medium)
- Kiln running on a Mac Studio / dedicated Linux box / cloud VM as a long-lived service.
- `compose.yaml` stays the operational unit but gains a "remote access profile" (Tailscale, Cloudflare Tunnel, or Caddy+Let's Encrypt) so the LiveView dashboard reachable from external network.
- Existing `kiln-sandbox` network `internal: true` stays — only the `/ops` + operator UI surface is exposed.

### 2. Auth (Medium)
- v1 assumes local-only, no auth. Remote access needs real auth.
- Minimum: single-operator password or passkey on the LiveView dashboard; session tokens in cookies; everything else stays solo-operator scope.
- SSO integrations (Google, GitHub OAuth) are Large and out of scope for the first iteration — operator-local passkey is enough to unblock.
- MFA: if SSO, delegate MFA to the IdP. If local passkey, WebAuthn handles the second factor natively.

### 3. GitHub / external-account credentials (Medium — see also SEED-004)
- For `gh` / git push to actually work on a remote host, the host needs durable GitHub creds.
- GitHub fine-grained PAT + `gh auth login --with-token` is the cleanest path for headless hosts.
- MFA: fine-grained PATs satisfy 2FA requirements; no browser flow needed.
- Stored per Kiln's existing SEC-01 contract — reference (secret name), not value, in the DB; actual token lives in `persistent_term` after boot, sourced from `$GITHUB_TOKEN` env var.
- Refresh flow: when token expires, Kiln escalates with `BLOCK-03` (auth) — operator rotates PAT, updates env, restart (or HUP if we add live reload).
- **This is SEED-004** — spun out separately because it's non-trivial and applies even to local v1 once we ship real `gh` integration.

### 4. Multi-project / multi-factory orchestration (Medium–Large)
- v1 is one Phoenix app, one Postgres, one set of runs. Many are fine — they're just more `runs` rows. But *many concurrent runs across different repos / different workflows / different model budgets* raises:
  - Resource contention (Docker container cap, model token budget per tenant-ish project)
  - Isolation (one factory's crash shouldn't cascade; already handled by `RunSupervisor` transient subtrees, but worth re-verifying under load)
  - Dashboard surface: "all factories" overview + per-factory drill-down
- Still solo-operator — this is one person supervising many of their own projects, NOT multi-tenant SaaS.
- May surface a lightweight "project" concept (not a Kiln term yet — would sit above `workflow` + `spec`) to group related runs.

### 5. Remote kickoff UX (Small–Medium)
- From phone/laptop: operator picks a template, fills in 2–3 prompts, submits.
- Server-side: Kiln turns that into a `spec` + `workflow` + enqueues a run via existing P3/P4 machinery.
- Key: the operator doesn't need a local checkout to start a run. The factory runs on the host; the operator only watches.

## Sub-themes to decide

- **Where does remote access draw the line?** Dashboard + read-only status + nudges (light) vs full run kickoff + spec authoring + workflow editing (heavy).
- **Tailscale vs Cloudflare Tunnel vs Caddy+LE** — each has different operator ergonomics. Tailscale is lowest-friction for solo operator; Cloudflare Tunnel easiest for mobile; Caddy+LE most self-owned.
- **Mobile UI constraint:** LiveView works on mobile but needs thoughtful layout for the "3-line status + last screenshot + nudge box" view on a phone screen.
- **Notifications:** push notifications to phone for checkpoints / blocks / escalations. Apple Push / Firebase / ntfy.sh / just Slack webhook.

## Relationship to existing scope

- **Reinforces SEED-001** (in-flight operator feedback): remote access is a *precondition* for async nudges to be valuable. If you can only nudge from the machine running Kiln, nudging is just typing in another tab — remote makes it genuinely async.
- **Precondition for SEED-003** (onboarding templates): templates are most valuable when operators can kick off a run in 30 seconds from any device.
- **Extends Phase 7** (operator dashboard) rather than replacing it — the v1 LiveView surface is the foundation, this seed adds the "but from anywhere, with auth" layer on top.
- **Distinct from multi-tenancy** — PROJECT.md says multi-tenant/SaaS/team is out of scope for v1. This seed is *single-operator remote access*, not team-oriented. A natural v2+ extension would be multi-operator with RBAC, but that's a separate future.

## Breadcrumbs

- `PROJECT.md` Out of Scope — re-read "Multi-tenant / SaaS / team features" to confirm single-operator remote access does NOT violate the constraint (it doesn't — still one operator, just not at the host).
- `prompts/kiln-brand-book.md` — mobile UI still honors the brand voice (calm, precise, restrained); "Operator: Kiln is on Stage 3/7. Tap to nudge." style.
- `.planning/research/ARCHITECTURE.md` — `LiveView` surface already exists in the 4-layer model; this seed extends it, doesn't reshape it.
- `.planning/seeds/SEED-001` — complementary (async steering needs remote access to matter).
- `.planning/seeds/SEED-003` — complementary (onboarding templates + remote kickoff = first-run magic).
- `.planning/seeds/SEED-004` — dependency (credential management for remote git push).

## Recommended next step when triggered

1. Run `/gsd-explore` for "remote operator control plane" — Socratic ideation to decide where to draw the scope line.
2. Split decision: ship as a v1.1 polish milestone (pure LiveView auth + Tailscale docs) vs v2.0 feature milestone (full remote kickoff + multi-factory view).
3. Reference SEED-001 / SEED-003 / SEED-004 in the discussion log — these cluster naturally.
