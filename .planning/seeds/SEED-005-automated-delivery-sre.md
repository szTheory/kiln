---
id: SEED-005
status: dormant
planted: 2026-04-18
planted_during: v0.1.0 / Phase 1 execution (captured mid-run from operator)
trigger_when: Phase 9 dogfood complete OR v1.0 release-prep OR first time an operator asks "my code works — how do I actually ship it?"
scope: Large (cross-cutting — spans output delivery, CI/CD, SRE, and operator UX)
---

# SEED-005: Automated Delivery & Ongoing SRE Lifecycle

## Why This Matters

Pure code-generation tools treat "merged PR" as the finish line. Kiln's DNA is louder: *success is the operator getting and using the software Kiln built*. The first-run experience should culminate not in "your PR merged" but in a **clickable link to a running service**, a **download URL for a binary**, or a **`pip install xyz`-style registry handle** — whichever of those three shapes matches the spec.

Two related gaps this seed closes:

1. **Happy-path gap.** `PROJECT.md` says Kiln "ships working software" — but today "ships" is ambiguous. Merged-to-git is the current mechanical meaning; deployed/published is the intended meaning. A spec that builds a webapp has not actually succeeded until the operator can visit `https://...`. A spec that builds a CLI has not succeeded until `curl <url> | sh` (or `brew install`, or `npm i -g`) works. A spec for a library has not succeeded until `mix deps.get` (or `pip install`, or `npm install`) finds it on the registry.
2. **Lifecycle gap.** Software improvement is a *loop*, not a one-shot. Subsequent runs against the same spec should **re-deploy / re-publish automatically** — including version bump, changelog regeneration, and basic SRE telemetry (is the deployed thing up? did downloads grow? are error rates spiking?). Without this, Kiln's second run is as cold as its first.

This is architectural DNA, not feature creep. v1 is strictly local-first solo-operator Docker Compose per `PROJECT.md` Constraints — we don't implement delivery automation until a natural trigger fires (see below). But the *intent* needs to be captured now so v1.5+ milestone scoping can honor it instead of rediscovering it.

## When to Surface

- **Phase 9 dogfood** — once Kiln has actually built something real, the "but where does it live?" question hits immediately. Natural point to promote this seed into concrete scope.
- **v1.0 release-prep** — if the launch narrative is "Kiln ships working software," the launch post has to show a live link / download / registry handle in the demo. Without this seed, the launch demo falls back to "look at this merged PR."
- **First time an operator asks "my code works — how do I actually ship it?"** — that question is the real-world trigger. A thoughtful answer means this seed has already been planned-for.
- **Any discussion of onboarding templates (SEED-003)** — templates aren't compelling as "Kiln built and merged X" screenshots; they're compelling as "Kiln built X and you can visit/download/install it right now."
- **Any discussion of remote operator control plane (SEED-002)** — "check in from your phone" becomes infinitely more useful when the dashboard shows a live link the operator can tap.

## Scope

**Large.** Cross-cutting: touches output-lifecycle automation, CI/CD orchestration, SRE / metrics surface, credential handling, and operator UX. Internally splits into four subsections by delivery shape + one cross-cutting SRE theme.

### 1. SaaS delivery path (Medium–Large)

- **Targets:** Fly.io, Cloudflare Workers, Render, Railway, Vercel, any "git-push-to-deploy" provider. Operator picks once per spec (or Kiln infers from stack heuristics — see Open Questions).
- **Tooling:** CLI tools the host already has — `flyctl` (Fly.io), `wrangler` (Cloudflare), `vercel` / `railway` / `render` CLIs. Invoked via `System.cmd/3` per PROJECT.md "No Docker socket mounts. Sandboxes use `System.cmd("docker", ...)`" pattern. Consistent with existing posture of *shell out to operator tools, don't pull in SDKs*.
- **First deploy:** Kiln provisions the app (subdomain on provider's default namespace — `my-spec-xyz.fly.dev`), then prompts operator once to attach a custom domain if desired. First-deploy auth flow is one of the hardest Design Open Questions below.
- **Subsequent deploys:** re-deploy on every run that produces new code, scoped by the spec's identity. Deploy operation flows through `Kiln.ExternalOperations` (Plan 01-04) so repeated retries produce exactly one completion per run.
- **Preview URLs:** each run optionally produces an ephemeral preview URL alongside the production one, so operator can inspect before promoting. Aligns with scenario-runner-as-sole-acceptance-oracle contract — the preview is for *the operator's subjective review*, not for the gate.
- **Rollback:** on deploy failure OR post-deploy SRE failure, the next run restores the last-known-good deployment. Deploy operations must be idempotent per run.

### 2. CLI binary delivery path (Medium)

- **Targets:** GitHub Releases (primary). Homebrew tap / Scoop bucket / apt repo as follow-ons, but not v1.5 scope.
- **Tooling:** `gh release create` + `gh release upload` for artifacts. Builds produce multi-arch binaries — start with darwin-arm64, darwin-x64, linux-x64, linux-arm64; windows-x64 is a fast-follow. Host-side build may use GitHub Actions (free minutes, native arch matrix) OR Kiln's local sandbox (slower, more isolation-consistent). Decide per spec.
- **Version bumping:** parse Conventional Commits between last release and `HEAD`, bump semver accordingly (feat = minor, fix = patch, breaking change = major). No human decision required.
- **Changelog:** auto-generate from the same commit log; section headings per commit type. Operator sees the rendered changelog in the run-completion UI + on the GitHub release page.
- **Artifact naming convention:** `<binary>_<version>_<os>_<arch>.tar.gz` (or `.zip` on Windows). SHA-256 checksums alongside. No code-signing in first iteration (operator-local trust); macOS notarization + Windows signing are fast-follows gated on operator interest.

### 3. Library publish path (Medium)

- **Targets:** match the library's ecosystem — Hex for Elixir, PyPI for Python, npm for JavaScript/TypeScript, RubyGems for Ruby, crates.io for Rust, Maven Central for Java/Kotlin, pkg.go.dev auto-indexes from a tagged git commit (Go). Kiln detects stack from the repo (`mix.exs` → Hex, `pyproject.toml` → PyPI, `package.json` → npm, etc.).
- **Tooling:** the ecosystem's native publisher — `mix hex.publish`, `twine upload`, `npm publish`, `cargo publish`, `gem push`. All invoked via `System.cmd/3`.
- **Version bumping + changelog:** same Conventional Commits flow as the CLI path. Single shared helper module.
- **Registry handle shown to operator:** `Kiln published your library → https://hex.pm/packages/your-lib/1.0.0` on the run-completion surface. Operator can copy-paste the install command (`{:your_lib, "~> 1.0"}` / `pip install your-lib==1.0.0` / `npm i your-lib@1.0.0`) without leaving Kiln.

### 4. Ongoing SRE / metrics loop (Medium — cross-cutting)

- **Post-deploy smoke (SaaS):** after every deploy, Kiln pings the deployed URL with a minimal health check (HTTP 200 on `/` or `/health`). Failure triggers rollback + `escalation_triggered` audit event + `BLOCK-04`-style escalation to operator.
- **Uptime + error-rate surface (SaaS):** lightweight polling (every N minutes, configurable) of the deployed URL; track response code distribution + P50/P95 latency. Surface as a run-detail tile. No full APM — we're not building Datadog — but "is this thing alive and responding" is first-class. Leans on existing `:telemetry` + LiveDashboard posture from CLAUDE.md so no new deps.
- **Download count (CLI):** poll GitHub Releases API for download counts per artifact; surface as a tile on the same run-detail page. Useful signal: "does anyone actually use this?"
- **Registry stats (library):** poll registry API for download count / dependent count. Same tile shape as CLI.
- **Feeds the feedback loop (SEED-001):** if a deploy is erroring post-launch, that's an *implicit operator nudge* — the next run's prompt context includes "prior deploy of this spec is erroring with X" so the agent can address it without the operator typing it.
- **Out of scope for v1.5:** full-fidelity APM, distributed tracing of deployed services, log aggregation. Those are properly-the-domain of observability products Kiln can *integrate with* later (e.g., emit OpenTelemetry spans that a Grafana Cloud / Honeycomb / Datadog account captures) but shouldn't re-implement.

## Sub-themes

- **Build identity: GitHub Actions vs Kiln-internal CI.** For public repos, GitHub Actions is free + native; Kiln drives it with `.github/workflows/release.yml` templates it generates. For private repos (v2+ territory), Kiln's local sandbox could build instead, sacrificing some arch coverage. Start with GHA; fall back to local only when needed.
- **Deploy credential handling.** Deploy tokens (Fly.io API token, Cloudflare API token, Hex API key, npm token, PyPI token) handled through the same `SEC-01` contract: names stored in DB as references, values in `persistent_term` after boot, sourced from env vars at host startup. Reuses the credential-onboarding story from **SEED-004** — same mechanism, different scope of tokens.
- **Idempotency for re-deploys.** Every deploy / release / publish op is a row in `external_operations` (Plan 01-04) with a deterministic idempotency key — `(spec_id, run_id, op_kind)`. Killing a worker mid-deploy + retrying MUST NOT produce double-deploys or double-version-bumps. The two-phase intent discipline already established in Phase 1 covers this; this seed just confirms it extends to delivery ops.
- **Version monotonicity.** Subsequent runs can only bump version forward. If commit history doesn't warrant a bump (no `feat:` / `fix:` / breaking changes since last release), the publish step is a no-op — not a failure. Operator sees "No publishable changes since v1.2.3" in the run-completion UI.
- **Multi-target specs.** A spec could produce BOTH a SaaS deploy AND a companion CLI (e.g., "a cron service + the CLI to configure it"). Plumbing supports this natively because each output shape is its own operation kind.
- **Rollback + incident response.** Failed deploys trigger `BLOCK-04` escalation with a diagnostic artifact. Not an automated rollback to an arbitrary prior version — just restore last-known-good. Anything fancier is v2 territory.

## Relationship to existing scope

- **Extends Phase 6 (GitHub Integration)** — Phase 6 stops at "PR opened / merged" per ROADMAP.md; this seed carries the story through "released / deployed / published." Phase 6's idempotent git push machinery is a hard prerequisite.
- **Extends Phase 8 (Operator UX)** — Phase 8 ships intake inbox + ops panels + onboarding wizard. This seed adds a new surface: "delivery status" tile on the run-detail view showing deploy URL + last deploy time + post-deploy smoke result. Operator UX is the consumer of the delivery automation, not just the plumbing.
- **Extends Phase 9 (Dogfood & Release)** — Phase 9 currently ends at merged PR per ROADMAP.md. This seed's v1.5 scope turns Phase 9 into a true loop: Kiln builds Kiln, publishes a new Hex release, operator sees the release landing on hex.pm.
- **Complements OPS-01..05** — OPS cluster is Kiln's *own* SRE (its own health, cost, diagnostics, routing). This seed is Kiln-output SRE. Same posture, different scope of subject. Shared primitives (`:telemetry`, LiveDashboard, audit events) — no duplication.
- **Reinforces GIT-01..04** — GIT cluster covers git commit / push / PR open. This seed adds the publishing / release half of the story that naturally comes after.
- **Reinforces INTAKE-03** — INTAKE-03 is post-PR iteration. This seed makes that iteration concrete: operator inspects the *deployed* output (not just the merged diff), files a nudge (SEED-001), next run re-deploys.
- **Depends on SEED-001 (operator feedback loop)** — once output is deployed, post-deploy reality (errors, bad UX, perf regressions) becomes the richest source of operator feedback.
- **Depends on SEED-002 (remote operator control plane)** — deploy status is MUCH more useful on a phone "check the live URL, tap to nudge" than only on a local dashboard.
- **Depends on SEED-004 (GitHub credential onboarding)** — deploy tokens (Fly.io, Cloudflare, Hex, npm) use the same onboarding + rotation mechanism as the GitHub PAT.

## PROJECT.md Core Value update recommendation (deferred)

When this seed triggers, sharpen `PROJECT.md` Core Value wording so "ships" is unambiguous. Current:

> **Core Value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

Proposed at seed-trigger time (NOT now — language should follow implementation, not precede it):

> **Core Value:** Given a spec, Kiln ships working software — built, verified, merged, and **deployed or published** — with no human intervention. Safely, visibly, durably.

Deferred because:
- Changing Core Value before we've actually delivered the capability risks committing to words we can't mechanically back.
- The exact phrasing may evolve after Phase 9 dogfood reveals what "deployed or published" actually looks like in practice.
- Seed docs are the durable anchor; Core Value is the public commitment.

## Concrete candidate requirements (candidates only — promote at trigger time)

When this seed triggers, expand `REQUIREMENTS.md` with a `DELIVERY` cluster (or equivalent name):

- **DELIVERY-01** — SaaS deploy: Kiln drives deploy to Fly.io / Cloudflare / Render via host CLI; produces a live URL shown to operator on run completion; subsequent runs re-deploy idempotently via `external_operations`.
- **DELIVERY-02** — CLI binary release: Kiln builds multi-arch binaries + uploads to GitHub Releases via `gh`; version bumped from Conventional Commits; changelog auto-generated.
- **DELIVERY-03** — Library publish: Kiln detects stack + publishes to matching registry (Hex / PyPI / npm / etc.); registry handle shown to operator.
- **DELIVERY-04** — Re-deploy loop: subsequent runs against the same spec automatically re-deploy / re-publish without operator prompt; no double-publish on retry.
- **DELIVERY-05** — Post-deploy SRE ping: every SaaS deploy is followed by a health-check smoke; failure triggers rollback + `BLOCK-04` escalation; uptime + error-rate surfaced as a run-detail tile.

These stay *candidate* inside this seed (not promoted to `REQUIREMENTS.md`) until the seed triggers and a real phase / milestone scopes them.

## Elixir-idiomatic constraints

Kiln's platform posture is Elixir-first, dep-minimal. This seed inherits both:

- **CLI tools over SDKs.** `gh`, `flyctl`, `wrangler`, `vercel`, `hex`, `mix hex.publish`, `npm`, `twine`, `cargo`, `gem` — all invoked via `System.cmd/3` + `Port`. Same pattern as PROJECT.md's Docker sandbox: "`System.cmd("docker", ...)` — sandbox driver (NOT socket mount)". No heavy SDK deps for AWS / GCP / Azure unless a specific one proves unavoidable.
- **`:telemetry` + LiveDashboard over third-party APM.** Kiln's own SRE (OPS cluster) already uses these per CLAUDE.md "use `:telemetry` + LiveDashboard for metrics in v1". Same primitives for output-SRE tiles — no new deps.
- **`:httpc` or Req 0.5 (already the sole HTTP client) for polling.** No new HTTP clients for registry-stats polls or deploy-health smoke.
- **Ecto state table over in-memory state.** Deploy status is an Ecto field on a `deployments` row (or `external_operations.response_payload`) — NOT a `GenServer`'s state. Consistent with CLAUDE.md "Postgres is source of truth. OTP processes are transient accelerators".
- **Oban workers for async ops.** Deploy + publish are long-running — they're Oban jobs, wrapped in `Kiln.Oban.BaseWorker` (Plan 01-04). Insert-time unique by `(spec_id, run_id, op_kind)` to enforce no-double-deploy at the job layer too.

## Design open questions

- **Output shape detection.** Heuristic (infer from repo — `Dockerfile` → SaaS, `mix.exs` with `:app` that's a binary → CLI, `mix.exs` with a Hex-shaped package → library) vs explicit in spec (`output: saas` / `output: cli` / `output: library`)? Recommend: explicit first, heuristic as fast-follow. Explicit keeps scope bounded.
- **First-time deploy auth flow.** First deploy of a new spec needs operator to attach a Fly.io account (or whichever provider). This is a `BLOCK-02`-style auth gate on the *first* deploy only. Subsequent deploys use the stored token. UX: a dashboard-prompted OAuth / paste-a-token flow, NOT a chat with the agent. How far this bends "bounded autonomy" is a tension to resolve at plan time.
- **Where does deploy target config live?** Options: (a) spec YAML (operator-authored, couples spec to provider); (b) workflow YAML (workflow-authored, decouples spec from provider — operator picks workflow with the right provider hook); (c) a separate `delivery.yaml` Kiln reads at deploy time. Recommend (b) since workflows already encode "how to build this," and "where to deploy" is the same shape.
- **Rollback policy on failed deploy.** (a) Immediate auto-rollback to last-known-good + escalation; (b) halt-in-broken-state + escalation; (c) operator-choice via `BLOCK-04` variant. Recommend (a) — broken prod is loudest.
- **Metrics retention.** How long does Kiln keep post-deploy uptime history? 30 days (align with `external_operations` pruner), 90 days, forever? Recommend 30 days to match existing posture; raise only on operator pressure.
- **Multi-env (staging + prod).** V1.5 is prod-only. Staging + promote-to-prod is a v2 story — keeping scope finite prevents early over-engineering.
- **Dry-run mode.** Operator says "build + test + smoke, but don't actually publish / deploy." Useful for spec iteration. Might be a flag on the workflow OR a separate workflow variant. Open question.
- **Cost attribution.** Deploys cost money (Fly.io CPU-seconds, GitHub Actions minutes). Does that cost roll up into the per-run budget circuit breaker (Phase 3)? Recommend yes — a per-run deploy-cost cap prevents runaway "re-deploy every 30 seconds" incidents.

## Breadcrumbs

- `.planning/PROJECT.md` → Core Value; the deferred update recommendation anchors here.
- `.planning/ROADMAP.md` → Phase 6 (GitHub Integration), Phase 8 (Operator UX), Phase 9 (Dogfood & Release) — all adjacent to this seed; this seed extends all three.
- `.planning/REQUIREMENTS.md` → OPS-01..05 (Kiln's own SRE; mirrored pattern for output SRE), GIT-01..04 (precedes delivery in the lifecycle), INTAKE-03 (post-PR iteration; operationally depends on "deployed output").
- `.planning/seeds/SEED-001-operator-feedback-loop.md` → in-flight nudges; post-deploy reality feeds this loop.
- `.planning/seeds/SEED-002-remote-operator-dashboard.md` → phone/laptop access; deploy status is the highest-value tile on that surface.
- `.planning/seeds/SEED-003-onboarding-templates.md` → templates are compelling as "live at URL" / "install via `pip install`", not as "merged PR."
- `.planning/seeds/SEED-004-credential-management.md` → deploy tokens reuse the same SEC-01 contract + rotation flow as GitHub PAT.
- `CLAUDE.md` Conventions § "No Docker socket mounts... `System.cmd("docker", ...)`" — same posture applied to delivery CLIs (`gh`, `flyctl`, `wrangler`, etc.).
- `CLAUDE.md` Technology Stack § "use `:telemetry` + LiveDashboard for metrics in v1" — output-SRE tiles use these primitives, not new deps.
- `prompts/kiln-brand-book.md` → delivery UI voice: "Run complete. Service live at {url}. 2 previous versions available." — no "🎉 Deployed!" / no marketing hype.

## Recommended next step when triggered

1. Run `/gsd-explore` on "automated delivery + SRE" to Socratically test the current scope lines (SaaS vs CLI vs library; prod-only vs staging; output-shape detection strategy).
2. Decide whether this ships as a v1.5 milestone of its own, a Phase-9-adjacent insertion (e.g., Phase 9.1), or a cluster spread across Phases 10-11 in a future milestone.
3. Promote `DELIVERY-01..05` from this seed's candidate list into `REQUIREMENTS.md` with real prose.
4. Scope the first delivery path (recommend SaaS-first — it has the most operator-demo impact; CLI + library follow) and plan a dedicated phase.
5. At that point, open a PR updating `PROJECT.md` Core Value to the sharpened wording in this seed; gate on the phase actually shipping.
6. Cross-reference SEED-001 (feedback loop), SEED-002 (remote control plane), SEED-004 (deploy credential onboarding) at discussion time — they naturally cluster.
