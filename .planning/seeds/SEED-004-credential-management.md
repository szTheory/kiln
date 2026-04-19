---
id: SEED-004
status: dormant
planted: 2026-04-18
planted_during: v0.1.0 / Phase 1 execution (captured mid-run from operator)
trigger_when: Phase 6 git-push work OR Phase 8 GitHub PR work OR first time operator runs Kiln on a headless / remote host
scope: Small-to-Medium (but trust-model sensitive — higher review bar than size suggests)
---

# SEED-004: GitHub / External-Account Credential Onboarding

## Why This Matters

Kiln's dark factory loop requires git push + `gh` PR creation as first-class ops (Phases 6 + 8). That means *Kiln needs real GitHub credentials* on the host it's running on. Three flavors of friction:

1. **Headless hosts (Mac Studio, cloud VM) can't do browser-based `gh auth login`** — OAuth device flow works over SSH, but it's still a friction wall the operator hits the first time.
2. **MFA requirements** — all modern GitHub accounts have 2FA. A freshly-provisioned host can't complete a login flow without an active phone/authenticator in the operator's hand at that moment.
3. **Credential refresh** — PATs expire, OAuth tokens need refresh, `gh`'s token store needs occasional re-auth. In a dark-factory context, "human intervention required to re-auth GitHub" is an escalation (`BLOCK-03`), not a silent failure.

Current state: Phase 1 has the `SEC-01` contract (secrets as references, stored in `persistent_term`, redacted via `@derive {Inspect, except: [:api_key]}`), but there's no guidance yet on *how operators actually supply those secrets* — especially `GITHUB_TOKEN` — without a local browser.

## When to Surface

- **Phase 6 git-push plan scoping** — the first phase that actually needs GitHub creds. Must be addressed before that phase lands, even if the solution is minimal ("export GITHUB_TOKEN=ghp_xxx and restart").
- **Phase 8 PR creation work** — same applies; `gh` needs creds.
- **First time operator runs Kiln on any host that isn't their primary workstation** — the "how do I log in?" question hits immediately.
- **Any discussion of SEED-002 (remote operator control plane)** — credential management is a hard dependency of remote-host Kiln.

## Scope

**Small-to-Medium in code. Higher trust-model review bar** because it's the bridge between Kiln and an external account with repo-write permissions.

### 1. Supported credential sources (Small)
In priority order:
- **`GITHUB_TOKEN` env var** (fine-grained PAT). Loaded at boot into `persistent_term` per `SEC-01`. Simplest, works on any host, MFA-compatible (PATs bypass interactive MFA by design, but the operator had MFA when they minted the PAT).
- **`gh` CLI token store** (`~/.config/gh/hosts.yml`). Kiln reads it as a fallback if `GITHUB_TOKEN` env var is unset. Convenient for operators who already use `gh` for their own work.
- **macOS Keychain / Linux secret-service** (optional, Medium) — nicer for long-lived hosts; delegates to OS secret store. Nice-to-have, not v1 critical.

### 2. Minting guidance (Small)
- Docs walkthrough: "How to mint a fine-grained PAT for Kiln with only the scopes it actually needs" (contents: `repo`, `workflow`, `pull_requests`, `issues`; org-level: nothing). Include a screenshot and direct link to `github.com/settings/tokens?type=beta`.
- Recommended PAT lifetime: 90 days (shorter is safer; longer is less churn). Kiln surfaces expiry warning 7 days before, via an `audit_events` row + dashboard banner.

### 3. Runtime UX (Small–Medium)
- **Missing creds at boot:** BootChecks (`Phase 1 / Plan 01-06`) SHOULD fail loudly if `$GITHUB_TOKEN` is unset AND `~/.config/gh` is absent. Operator sees "Kiln refused to start: no GitHub credentials found. Set `$GITHUB_TOKEN` or run `gh auth login`."
- **Creds present but invalid:** First git push operation fails with 401/403 → `BLOCK-03` (auth) escalation → operator rotates PAT → restart → resume.
- **Creds expiring soon:** Background check (daily) hits `/user` endpoint; if `X-RateLimit-*` headers show token nearing expiry window, emit `block_raised` audit event of kind `credential_rotation_required` (NOT a hard block yet — gives the operator a week of warning).

### 4. Rotation flow (Medium)
- Ideal: operator mints new PAT, sets new env var, `SIGHUP` / hot-reload without restart. In practice, a restart is fine for v1.
- Non-goal for v1: automatic token refresh. OAuth refresh tokens are a trust-model escalation (Kiln holding a long-lived refresh token that can mint new access tokens is a bigger surface than a short-lived PAT).

### 5. Trust model notes
- Kiln NEVER logs the token value (per `SEC-01` `@derive {Inspect, except: [:api_key]}`).
- Kiln NEVER commits the token to the workspace (per `SEC-01` "never persist to workspace").
- Kiln NEVER renders the token in the UI (operator sees only the *name* of the secret reference + `<redacted>`).
- On `BLOCK-03` escalation, the diagnostic artifact includes "which secret by name" — never the value.
- Sandbox containers have `internal: true` network (Plan 01-01) — even if a token leaked into a sandbox process's env, it can't exfiltrate.

## MFA / 2FA specifics

- **Personal Access Tokens bypass the interactive MFA flow by design** — when you mint a PAT, you authenticate with your MFA once at mint time; the resulting token is MFA-equivalent. GitHub treats a PAT as "authenticated user + MFA ✓" for the token's lifetime.
- **OAuth device flow** (what `gh auth login` does on headless hosts) prompts the operator to open a URL + enter a device code on any browser. That browser login does MFA; the resulting access token is also MFA-equivalent. Works for headless hosts as long as the operator has *any* browser-capable device at login time.
- **Conclusion:** PAT is the simplest path for Kiln. Device flow is a usability upgrade. Neither requires Kiln to handle TOTP codes / WebAuthn directly.

## Relationship to existing scope

- **Depends on `SEC-01`** (Phase 1 / Plan 01-01) — the secret-reference plumbing already exists. This seed is about *operator onboarding* for the specific case of GitHub creds.
- **Consumed by Phase 6** (git push) and **Phase 8** (PR creation) — these phases assume creds exist; this seed makes that assumption concrete.
- **Enables SEED-002** (remote operator) — remote-host Kiln is unusable without sane credential onboarding.
- **Related to `BLOCK-03`** (auth-type block reason) — credential rotation and re-auth flow through the existing typed-block machinery.

## Breadcrumbs

- `.planning/PROJECT.md` Constraints → "Secrets are references, not values" (`SEC-01`).
- `.planning/phases/01-foundation-durability-floor/01-RESEARCH.md` — `SEC-01` implementation notes.
- `CLAUDE.md` Conventions § "Secrets are references, not values" — the full SEC-01 contract.
- `.planning/REQUIREMENTS.md` `BLOCK-03` — typed auth block.
- `.planning/seeds/SEED-002` — remote host use case that makes this seed load-bearing.
- GitHub docs: `docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens` (reference when writing the minting walkthrough).

## Design open questions

- Does Kiln support multiple GitHub accounts (personal + work) in v1? Probably no — single-operator, single-PAT is simpler. A `GITHUB_TOKEN_{ORG}` multi-key scheme is v2+.
- Do we need to support GitHub App auth (more fine-grained than PAT, better for orgs)? Probably v2+.
- Where does the credential-rotation-required audit event surface? Dashboard banner? Email? osascript notification? Likely reuses whatever the escalation UX picks (D-17 op_kind).

## Recommended next step when triggered

1. Before Phase 6 (git-push) planning, run `/gsd-discuss-phase 6` and include this seed in the context.
2. Ship the minimal credential contract as part of Phase 6: `$GITHUB_TOKEN` env var, BootChecks failure if missing, `BLOCK-03` on runtime 401/403.
3. Add the PAT minting walkthrough to the docs site (backlog 999.1) alongside the first-run LOCAL-01 walkthrough.
4. Revisit rotation UX when SEED-002 triggers (remote host makes the "restart to pick up new token" friction more visible).
