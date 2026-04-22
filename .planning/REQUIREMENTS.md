# Requirements: Kiln

**Defined:** 2026-04-18
**Core Value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

**Reconciled (2026-04-22, Phase 13):** § v1 checkboxes match the **v0.1.0 shipped bundle** — `.planning/PROJECT.md` **Validated** (including the Phases 2–9 capability line) and `.planning/ROADMAP.md` Phases 1–9 marked complete. **v0.2** work stays under `PROJECT.md` **Active** (`DOGFOOD-01`, `LOCAL-DX-01`, `DOCS-ALIGN-01`); those IDs are not part of the original 55 v1 rows below.

## v1 Requirements

All v1 requirements below were treated as hypotheses until **v0.1.0** (Phases 1–9) shipped; checkboxes now record that closure. New work uses **Active** IDs in `PROJECT.md` or **§ v2 Requirements** here.

### Core Orchestration

- [x] **ORCH-01**: Workflow definition is a YAML/JSON graph, versioned in git, schema-validated (JSON Schema Draft 2020-12) at load time — Phase 2
- [x] **ORCH-02**: Stage executor runs each stage in a supervised BEAM process with crash isolation (agent failure must not kill the run) — Phase 2
- [x] **ORCH-03**: Run state machine persists to Postgres with explicit allowed transitions: queued → planning → coding → testing → verifying → (merged | failed | escalated); every transition writes an Audit.Event in the same Postgres transaction — Phase 2
- [x] **ORCH-04**: Every stage writes an artifact + event before emitting success; runs are resumable from the last checkpoint after crash or redeploy — Phase 2
- [x] **ORCH-05**: When the Verifier reports failure, the run loops back to the Planner with a structured `%VerifierResult{}` diagnostic — this is the "loop until spec met" core — Phase 5
- [x] **ORCH-06**: Bounded autonomy — per-run hard caps on retries, token spend (USD and tokens), and elapsed steps; escalation = halt with diagnostic artifact; never silently continue after repeated verification failure — Phase 5
- [x] **ORCH-07**: Idempotency — every Oban job has an insert-time unique key AND handler-level dedupe; every external side-effect (git push, GitHub API call, LLM API call, Docker op) has an `external_operations` intent-table row with two-phase (intent → action → completion) semantics — Phase 2

### Agents

- [x] **AGENT-01**: Provider-agnostic LLM adapter via `Kiln.Agents.Adapter` behaviour; Anthropic (via anthropix 0.6) shipped in v1; OpenAI, Google, and local Ollama adapters ship on Req (rolled-own, ~200 LOC each) as the workflow schema supports them
- [x] **AGENT-02**: Per-stage model selection via workflow YAML (e.g., `planner: opus`, `coder: sonnet`, `router: haiku`); ModelRegistry resolves role → model with explicit fallback chain
- [x] **AGENT-03**: Specialized agent roles as OTP processes — Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor (orchestrator-of-record). Agents supervised under per-run `Agents.SessionSupervisor`; agent crash does not kill the run
- [x] **AGENT-04**: Agent-shared memory implemented as native Ecto `work_units` current-state table + `work_unit_events` append-only ledger + Phoenix.PubSub broadcast (beads-equivalent, Option A per BEADS.md)
- [x] **AGENT-05**: Token + cost telemetry emitted per agent call, stored per stage and per run; `:telemetry` events + OTel spans; both `requested_model` and `actual_model_used` recorded to catch silent fallback

### Sandbox

- [x] **SAND-01**: Every stage runs in an ephemeral Docker container, auto-cleaned on completion or crash (`--rm` + explicit `docker rm` on crash paths)
- [x] **SAND-02**: Network egress blocked at the Docker bridge layer (`internal: true`) except to the Kiln-hosted DTU mock network; adversarial negative tests verify TCP/UDP/DNS/ICMP/IPv6 are all blocked
- [x] **SAND-03**: Digital Twin Universe — local HTTP mocks for GitHub API and common third-party integrations used during spec execution; mocks versioned and contract-tested weekly against real services
- [x] **SAND-04**: Git + filesystem workspace mounted read-write into sandbox; diff captured at stage end and stored in content-addressed artifact store

### Spec & Validation

- [x] **SPEC-01**: Spec editor in LiveView — markdown body with embedded BDD scenarios (Given/When/Then); saved versioned to Postgres
- [x] **SPEC-02**: BDD scenarios compile to executable acceptance tests run inside the sandbox against the produced software
- [x] **SPEC-03**: Verifier is deterministic-first: the scenario runner's exit code is authoritative pass/fail; LLM verifier *explains* failures but never overrides the scenario runner's verdict
- [x] **SPEC-04**: Holdout scenarios — a subset of scenarios stored where Coder, Planner, and Reviewer agents cannot read them; only the Verifier process accesses them at verification time (StrongDM holdout pattern, closes FEATURES.md Gap G-06)

### Security & Secrets

- [x] **SEC-01**: Kiln stores secret *references* only (names, not values); values are fetched from `persistent_term` at point-of-use, redacted via `@derive {Inspect, except: [:api_key]}`, never rendered to UI or logs, never persisted to the sandbox workspace. Short-lived credentials where the provider supports them. (Closes FEATURES.md Gap G-01; maps to Pitfalls P5 and P21.)

### GitHub Integration

- [x] **GIT-01**: Kiln drives `git` (commit, push, branch, worktree) via `System.cmd` in the workspace; every git mutation is wrapped in an Oban worker with idempotency key `{run_id, stage_id, op_name}` and `git ls-remote` precondition
- [x] **GIT-02**: Kiln opens pull requests via `gh` CLI when the workflow has a PR stage; PR metadata (title, body, base, reviewers) derived from run artifacts
- [x] **GIT-03**: Kiln reads and updates GitHub Actions status on PRs (checks API); run board surfaces CI status inline
- [x] **GIT-04**: Kiln's own GitHub repository ships a GitHub Actions workflow running `mix check` (mix test, credo, dialyzer, xref, sobelow, mix_audit) on every push and PR

### UI (LiveView Dashboard)

- [x] **UI-01**: Run board — kanban-style columns by state (queued / planning / coding / testing / verifying / merged / failed / escalated); real-time updates via PubSub + LiveView streams; no unbounded assigns
- [x] **UI-02**: Run detail view — stage graph (topologically laid out), per-stage diff viewer, bounded log buffer, event timeline, agent chatter stream; streams for all list-shaped data
- [x] **UI-03**: Workflow registry — read-only viewer for loaded workflow YAMLs; shows version history; no web-based workflow authoring (anti-feature)
- [x] **UI-04**: Token + cost dashboard — per run, per workflow, per agent; daily/weekly spend view; projection to end-of-run based on burn rate
- [x] **UI-05**: Audit ledger view — append-only events, filterable by run/stage/actor/event-type; time-range picker; event payload inspectable
- [x] **UI-06**: Kiln brand book applied globally — Inter + IBM Plex Mono typography; coal/char/iron/bone/ash/ember palette; borders over shadows; state-aware components (loading/empty/success/warning/error/focus/disabled); operator microcopy ("Start run", "Verify changes", "Build verified", "Verification failed", "Retry step", "Waiting on upstream")

### Observability & Audit

- [x] **OBS-01**: Structured JSON logging via logger_json with correlation_id, causation_id, actor, run_id, stage_id on every log line; Logger metadata propagates through Oban/Task boundaries via explicit threading (never `Process.put/2`) — **Done (Plan 01-05)**
- [x] **OBS-02**: OpenTelemetry traces (Erlang SDK, stable as of 2026) — spans per stage, per agent call, per Docker op, per LLM call; `opentelemetry_process_propagator` wired through Oban workers
- [x] **OBS-03**: Append-only audit ledger (`audit_events` table) with three-layer INSERT-only enforcement at the Postgres level (REVOKE UPDATE/DELETE/TRUNCATE from runtime role; `BEFORE UPDATE/DELETE/TRUNCATE` trigger `audit_events_immutable()`; `CREATE RULE … DO INSTEAD NOTHING` safety net — see 01-CONTEXT.md D-12); time-travel query support via event replay — **Done (Plan 01-03)**
- [x] **OBS-04**: Stuck-run detector — sliding window over (stage, failure-class) tuples; halts run with `escalated` state + diagnostic artifact when the same failure class repeats N times (N configurable per workflow, defaults to 3)

### Local Dev & Distribution

- [x] **LOCAL-01**: `docker compose` runs **Postgres** + **DTU** + internal sandbox network (and optional OTel/Jaeger); **Phoenix runs on the host** (`mix phx.server`). See `README.md` and `.planning/research/LOCAL-DX-AUDIT.md`. Optional “app in Compose” / devcontainer = **Phase 12** (v0.2.0).
- [x] **LOCAL-02**: `.tool-versions` pins Elixir 1.19.5 / Erlang 28.1+ for `asdf`; Phoenix 1.8.5 + LiveView 1.1.28 pinned in `mix.exs`
- [x] **LOCAL-03**: README with zero-to-first-run walkthrough — Phase 9 / LOCAL-03

### Automation & Zero-Human Verification

- [x] **UAT-01**: All scenarios (including SPEC-04 holdouts) are executable in the sandbox by the deterministic scenario runner; `mix check` + GitHub Actions CI runs them automatically. Zero manual QA steps for code paths — the scenario runner's exit code is the acceptance oracle.
- [x] **UAT-02**: Human intervention is reserved for a short, explicit, typed list: credential/secret provisioning, first-time external integration auth, budget approvals above configured cap, and hard escalations (ORCH-06). Nothing else is allowed to require a human; anything else that blocks automatically escalates as a bug against Kiln itself.

### Unblock Flow (when human IS required)

- [x] **BLOCK-01**: Typed block reasons — `:missing_api_key`, `:invalid_api_key`, `:rate_limit_exhausted`, `:quota_exceeded`, `:gh_auth_expired`, `:gh_permissions_insufficient`, `:budget_exceeded`, `:unrecoverable_stage_failure`, `:policy_violation`. Each reason maps to a remediation playbook.
- [x] **BLOCK-02**: Unblock panel — when a run blocks, LiveView surfaces a clear panel with: what happened (typed reason), what to do (exact commands / config changes), "I fixed it — retry" action that resumes from last checkpoint. Panels are scannable at a glance.
- [x] **BLOCK-03**: Desktop notification (macOS/Linux via `osascript`/`notify-send` shell-out, configurable) when a run enters blocked/escalated state; optional email/webhook integration for remote operators (v1.1+).
- [x] **BLOCK-04**: First-run onboarding wizard — on empty-state (`docker compose up` fresh clone), the UI walks the operator through provisioning API keys (Anthropic required, others optional), GitHub App install, sandbox prerequisites check. No run can start until the wizard passes.

### Intake (how work enters the factory)

- [x] **INTAKE-01**: New-spec entry points: (a) freeform text in the LiveView spec editor, (b) import markdown file, (c) convert a GitHub issue (by URL or `owner/repo#N`) into a spec draft — title+body+labels populate; operator edits and commits.
- [x] **INTAKE-02**: Inbox view — list of spec drafts not yet promoted to runs; operator can triage (promote, archive, edit). `INTAKE-01(c)` issues land here by default.
- [x] **INTAKE-03**: Feedback loop — when a produced PR is merged and real-world usage reveals a bug or missing capability, a "File as follow-up" button on the run detail view creates a new spec draft in the inbox pre-populated with the run's artifacts as context.

### Operations & SRE (self-healing where possible, hands-off where not)

- [x] **OPS-01**: Provider health panel — per-LLM-provider status card showing: API key present/valid, last successful call timestamp, rate-limit headroom (from provider response headers), recent error rate, token budget remaining today. Red-amber-green indicators. No digging through logs to answer "why did my run stall?"
- [x] **OPS-02**: Adaptive model routing — on HTTP 429 (rate limit) or 5xx (provider outage), `Kiln.ModelRegistry` automatically falls back to the workflow-configured alternate model/provider for the same role; both `requested_model` and `actual_model_used` recorded on the stage; operator notified if fallback crosses a tier (e.g., Opus→Sonnet acceptable, Sonnet→Haiku warns).
- [x] **OPS-03**: Opinionated model-profile presets — Kiln ships with profiles keyed to software type: `elixir_lib` / `phoenix_saas_feature` / `typescript_web_feature` / `python_cli` / `bugfix_critical` / `docs_update`. Each preset maps `{role → model}` pairs. Operator selects a profile when starting a run; workflow YAML can override per-stage. Presets documented, not magic.
- [x] **OPS-04**: Cost intelligence — per-run / per-workflow / per-agent / per-provider spend broken down; daily/weekly/monthly views; "you're spending $X/week on Opus for the Coder role; `phoenix_saas_feature_budget` profile would cost $Y with these tradeoffs" advisory.
- [x] **OPS-05**: Diagnostic snapshot — one-click "bundle last 60 minutes of runs + config + logs" into a sharable zip for support/debugging (secrets redacted).

### Progress Visibility

- [x] **UI-07**: Global factory header — visible on every page: active runs count, blocked runs count (with color/badge), spend today, provider-health summary lights. One-click to the relevant detail.
- [x] **UI-08**: Per-run progress indicator — percent-complete (stages done / total), elapsed time, estimated remaining (from historical stage-duration percentiles when the workflow has prior runs), "last activity" timestamp with staleness color ramp (green <30s, amber <5min, red ≥5min). Surfaces on run board cards and run detail header.
- [x] **UI-09**: Agent activity ticker — live-updating rolling log of agent events across all active runs ("Coder completed `lib/foo.ex` — 430 tokens, $0.013", "Verifier running 12 scenarios"); makes it unmistakable that the factory IS doing something.

## v2 Requirements

Deferred to a future milestone. Tracked here so they don't become ambiguous later.

### Parallel & Multi-run

- **PARA-01**: Multiple runs executing in parallel with fair-share scheduling
- **PARA-02**: Run comparison view (two runs side-by-side, diff artifacts, cost compared)

### Replay & Time-Travel

- **REPL-01**: Full event-sourced replay UI (scrub through run history)
- **REPL-02**: "What would have happened if…" hypothetical re-execution from a checkpoint with modified spec

### Workflow Ecosystem

- **WFE-01**: Workflow template library (Elixir library, Phoenix SaaS, TypeScript CLI, Rust lib, etc.)
- **WFE-02**: Workflow YAML signing (sigstore or GPG) for supply-chain trust
- **WFE-03**: Diagnostic artifact bundle (auto-packaged when a run escalates)

### Cost & Operations

- **COST-01**: Cost optimization advisor — suggests cheaper model for stages where quality tolerates it
- **COST-02**: Budget alerts (hit 50% / 80% / 100% of run cap → notify)

### Team & Multi-tenant (explicit v2+ — deferred per PROJECT.md)

- **TEAM-01**: Multi-user workspaces with RBAC
- **TEAM-02**: Workspace-level policies (who can approve escalated runs, budget caps per user)
- **TEAM-03**: SSO / OIDC
- **TEAM-04**: Audit log export APIs for compliance

### Self-Evaluation & Continuous Improvement (v1.5)

Originally surfaced in `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` lines 238–260 during Phase 1 discussion. Formalized here so the cluster is addressable by ID instead of being buried in a phase context file.

- **SELF-01**: Run post-mortem record — every merged run emits structured artifact (token usage by stage/agent/role, wall time, retry counts, `requested_model` vs `actual_model_used`, scenario verdict trail, BLOCK reasons hit, escalations, checkpoint resumes). Stored in `run_postmortems` table or typed artifact file.
- **SELF-02**: Operator subjective rating — after each merged run, prompt 1–5 satisfaction + free-text "what went wrong / right"; stored alongside the run.
- **SELF-03**: Aggregated insights view — "Across the last N runs, the Coder role on profile X averaged Y tokens / $Z / T minutes; switching to model M would save A%, drop scenario pass rate by B%."
- **SELF-04**: Spec-to-result LLM-judge quality scoring — layered on top of scenario pass rate (which remains the deterministic oracle); LLM-judge is *advisory only*, never overrides scenario verdict.
- **SELF-05**: Model bake-off workflow — when a new Anthropic / OpenAI / Google model ships, run canned spec against old vs new; compare cost, latency, scenario pass rate; recommend profile updates. Closes the loop on `OPS-02/03` over time.
- **SELF-06**: Kiln-builds-Kiln learning artifact — each Kiln self-run produces a "Kiln-on-Kiln learnings" summary that informs the next Kiln spec. (Phase 9 dogfoods once; the *loop* is this v1.5 item.)
- **SELF-07**: External signal capture — post-merge GitHub Actions outcomes, real-world bug reports filed against produced PRs (`INTAKE-03` is the entry point), runtime telemetry of shipped code when Kiln has access.
- **FEEDBACK-01**: In-flight async operator nudges — during a run, Kiln periodically surfaces a lightweight "what I'm doing right now" summary (text + screenshot/video/diff/diagram depending on stage) via the operator UI or a notification channel. Operator can leave one-line async feedback that Kiln considers as *soft guidance* on subsequent stages — NOT a blocking approval gate (preserves dark-factory autonomy per `UAT-01/02`). Feedback is persisted as an `audit_events` row of kind `operator_feedback_received`; subsequent runs and model-bake-offs can train on it. Distinct from `INTAKE-03` (post-PR follow-up filing) and from `BLOCK-01..04` (typed unblock). This is *steering*, not *gating*. See `.planning/seeds/SEED-001-operator-feedback-loop.md` for full context, open questions, and design constraints.

## Docs & Release (v1.0+)

Captured in backlog as `999.1-docs-landing-site` (see `ROADMAP.md` § Parking slot). **Resolved 2026-04-22:** work shipped as **999.x parking-lot** execution; integer **Phase 10** is **Local operator readiness (v0.2.0)** — see `.planning/todos/completed/2026-04-18-phase-10-slot-decision.md`.

- **DOCS-01**: Landing / home page — single-page why-Kiln, 60–90s operator video or live demo embed, "run your first spec in 10 minutes" CTA. Brand-matched per `prompts/kiln-brand-book.md` (Inter + IBM Plex Mono, coal/char/iron/bone/ash/ember palette, borders over shadows, restrained operator voice).
- **DOCS-02**: Operator onboarding guide — zero-to-first-run walkthrough (`.env`, `docker compose up`, writing your first spec), common footguns and their fixes. Happy-path first, edge cases in collapsible sections. Supersedes/extends `LOCAL-03` (Phase 9 README walkthrough) with guided long-form content.
- **DOCS-03**: Workflow & spec authoring guide — YAML workflow schema reference, BDD scenario patterns, holdout strategy, budget-cap tuning. Examples > prose.
- **DOCS-04**: Architecture & internals — four-layer model (intent → workflow → execution → control), supervision tree, audit ledger (three-layer INSERT-only), `external_operations` idempotency table, scenario runner. Mermaid diagrams rendered from markdown in CI, kept in sync with code. Answers "how does Kiln actually work?" for both users and contributors.
- **DOCS-05**: Configuration reference — every env var, every `.planning/config.json` key, every `kiln.toml` / `workflow.yaml` field. Scannable, searchable, cross-linked from runtime error messages (so operator hitting an error has a one-click path to the docs).
- **DOCS-06**: CI/CD auto-publish — GitHub Actions workflow publishes site to `gh-pages` branch on every merge to `main`. Broken-link check + spell-check integrated into `mix check`. Automated initial setup via `mix kiln.docs_init` task or short runbook (no manual GitHub settings clicks required beyond enabling Pages).
- **DOCS-07**: Static site generator choice — decide during Phase 10 discuss. Candidates: Astro Starlight (markdown-first, type-safe), Docusaurus (React, versioning built in), VitePress (fast, Vue), MkDocs Material (Python, mature). Research reference designs — Stripe, Linear, Prisma, Tailwind, Astro, Raycast, Framer, Vercel — for lessons; do NOT clone any one of them (Fabro explicitly off-limits as a copy target, inspiration only).

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-tenant / teams / RBAC in v1 | Solo-engineer focus; team features come only after self-use is proven |
| Billing, SaaS hosting, paid product | Dogfood first; productize later if at all |
| Hosted cloud runtime (AWS/GCP IaC, K8s) | Local Docker only for v1 |
| Human approval gates in the execution loop | Anti-pattern for the dark factory model; bounded autonomy handles safety instead |
| Web-based workflow authoring UI | Workflows are YAML files versioned in git; LiveView renders read-only |
| Kiln-hosted model weights / embedded inference | Kiln calls external APIs; Ollama integration is via HTTP, not embedded |
| SSO / OIDC / enterprise auth | Solo use in v1; no login needed |
| Workflow marketplace or sharing | Single-user, single-workspace |
| Mobile app / mobile UI | Desktop-first operator dashboard |
| Synchronous human approval gates | Dark factory defining feature; mid-run steering breaks determinism |
| Chat-as-primary-UX | Agent chatter is a side channel, not the interaction model |
| Pair-programming UX with user | Opposed to "no human reads the code" thesis |
| `:gen_statem` for run state | Splits truth between DB and memory; chose Ecto-field + command module instead |
| Umbrella app layout | Umbrellas solve deploy/release problems Kiln doesn't have; single app + contexts is cleaner at this scope |
| Docker socket mount into sandbox | Equivalent to root on host; use CLI + Port instead |
| `ex_json_schema` for YAML validation | Draft 4 only, dormant; using JSV (Draft 2020-12) instead |
| `fast_yaml` | C-NIF build footgun at Kiln scale; using `yaml_elixir` instead |
| Full event sourcing on all domains | Operational cost not justified for v1; append-only audit ledger + current-state tables instead |
| Oban Pro / Oban Web paid | Oban Web became OSS in v2.12.2 (Apache-2.0); zero reason to pay |
| Manual QA step for generated code | UAT-01 / UAT-02: the scenario runner is the acceptance oracle; any manual QA is a bug against Kiln |
| Human-in-the-loop "mid-run steering" / chat-with-the-agent | BLOCK-* contract: humans unblock only via typed block reasons, never via freeform chat mid-run |
| Freeform chat as the primary unblock mechanism | Remediation playbooks are structured, not conversational — preserves determinism and audit clarity |

## Traceability

Populated by `gsd-roadmapper` during roadmap creation. Each v1 requirement maps to exactly one phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORCH-01 | Phase 2 | Complete |
| ORCH-02 | Phase 2 | Complete |
| ORCH-03 | Phase 2 | Complete |
| ORCH-04 | Phase 2 | Complete |
| ORCH-05 | Phase 5 | Complete |
| ORCH-06 | Phase 5 | Complete |
| ORCH-07 | Phase 2 | Complete |
| AGENT-01 | Phase 3 | Complete |
| AGENT-02 | Phase 3 | Complete |
| AGENT-03 | Phase 4 | Complete |
| AGENT-04 | Phase 4 | Complete |
| AGENT-05 | Phase 3 | Complete |
| SAND-01 | Phase 3 | Complete |
| SAND-02 | Phase 3 | Complete |
| SAND-03 | Phase 3 | Complete |
| SAND-04 | Phase 3 | Complete |
| SPEC-01 | Phase 5 | Complete |
| SPEC-02 | Phase 5 | Complete |
| SPEC-03 | Phase 5 | Complete |
| SPEC-04 | Phase 5 | Complete |
| SEC-01 | Phase 3 | Complete |
| GIT-01 | Phase 6 | Complete |
| GIT-02 | Phase 6 | Complete |
| GIT-03 | Phase 6 | Complete |
| GIT-04 | Phase 9 | Complete |
| UI-01 | Phase 7 | Complete |
| UI-02 | Phase 7 | Complete |
| UI-03 | Phase 7 | Complete |
| UI-04 | Phase 7 | Complete |
| UI-05 | Phase 7 | Complete |
| UI-06 | Phase 7 | Complete |
| OBS-01 | Phase 1 | Complete (Plan 01-05 — 5888aac, 0a5ba87) |
| OBS-02 | Phase 9 | Complete |
| OBS-03 | Phase 1 | Complete (Plan 01-03 — ea6b174, aeede36, 00a3782) |
| OBS-04 | Phase 5 | Complete |
| LOCAL-01 | Phase 1 | Complete (Plan 01-01 — structural f567c7e; Plan 01-06 — BootChecks + HealthPlug + first_run.sh smoke, a271a6a/a82d070/6e88813) |
| LOCAL-02 | Phase 1 | Complete (Plan 01-01 — `.tool-versions` + `mix.exs` pins, f567c7e; Plan 01-02 — `mix check` gate + GHA CI, cb05fa1/18de9a4) |
| LOCAL-03 | Phase 9 | Complete |
| UAT-01 | Phase 5 | Complete |
| UAT-02 | Phase 5 | Complete |
| BLOCK-01 | Phase 3 | Complete |
| BLOCK-02 | Phase 8 | Complete |
| BLOCK-03 | Phase 3 | Complete |
| BLOCK-04 | Phase 8 | Complete |
| INTAKE-01 | Phase 8 | Complete |
| INTAKE-02 | Phase 8 | Complete |
| INTAKE-03 | Phase 8 | Complete |
| OPS-01 | Phase 8 | Complete |
| OPS-02 | Phase 3 | Complete |
| OPS-03 | Phase 3 | Complete |
| OPS-04 | Phase 8 | Complete |
| OPS-05 | Phase 8 | Complete |
| UI-07 | Phase 8 | Complete |
| UI-08 | Phase 8 | Complete |
| UI-09 | Phase 8 | Complete |

**Coverage:**
- v1 requirements: 55 total
- Mapped to phases: 55 (all mapped)
- Unmapped: 0

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-22 — Phase 13: § v1 checkboxes + traceability Status aligned to v0.1.0 shipped scope (`PROJECT.md` Validated, `ROADMAP.md` Phases 1–9).*
