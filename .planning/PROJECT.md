# Kiln

## What This Is

Kiln is a **software dark factory** — an Elixir/Phoenix LiveView application that orchestrates external LLM agents (Claude, OpenAI, Google, local) to autonomously produce shipped software end-to-end. Given a spec, Kiln plans, codes, tests, verifies, commits, pushes, and iterates until the spec is met. A live LiveView dashboard shows the factory "cranking" — stages progressing, agents talking, diffs landing, CI passing — with no human intervention in the loop. Inspired by Gas Town (agent hierarchy + durable work tracking), Fabro (deterministic workflow graphs + stage-level checkpointing), and StrongDM (scenario-based validation + digital twin universe for mocked externals).

## Core Value

**Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.**

That single promise is what the whole system must deliver. Every design tradeoff defers to it.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

(None yet — ship to validate)

### Active

<!-- Current scope. Building toward v1. -->

**Core orchestration**
- [ ] **ORCH-01** Workflow definition format: YAML/JSON graph, versioned in git, schema-validated at load
- [ ] **ORCH-02** Stage executor runs each stage in a supervised BEAM process with crash isolation
- [ ] **ORCH-03** Run state machine: queued → planning → coding → testing → verifying → (merged | failed | escalated); persisted to Postgres
- [ ] **ORCH-04** Checkpointing: every stage writes an artifact + event before emitting success; runs resumable from last checkpoint
- [ ] **ORCH-05** Loop-until-spec-met: Verifier failure routes back to Planner with structured failure diagnostic
- [ ] **ORCH-06** Bounded autonomy: per-run caps on retries, token spend, elapsed steps; escalation = halt + diagnostic artifact
- [ ] **ORCH-07** Idempotency: every Oban job has idempotency key; every external side-effect (git push, API call) is retry-safe

**Agents**
- [ ] **AGENT-01** Provider-agnostic LLM adapter (Anthropic, OpenAI, Google, local Ollama) via behaviour-defined port
- [ ] **AGENT-02** Per-stage model selection (planner = Opus-class, coder = Sonnet-class, router = Haiku-class; configurable)
- [ ] **AGENT-03** Specialized agent roles: Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor (orchestrator-of-record)
- [ ] **AGENT-04** Agent-shared memory (beads-equivalent, native Elixir implementation)
- [ ] **AGENT-05** Token + cost telemetry per agent per run

**Sandbox**
- [ ] **SAND-01** Per-stage ephemeral Docker container, auto-cleaned
- [ ] **SAND-02** Network egress blocked except to Kiln-hosted mock services
- [ ] **SAND-03** Digital Twin Universe: local mocks for GitHub API and common HTTP integrations used during spec execution
- [ ] **SAND-04** Git + filesystem workspace mounted read-write into sandbox; diff captured at stage end

**Spec & validation**
- [ ] **SPEC-01** Spec editor (markdown + embedded BDD scenarios) in LiveView
- [ ] **SPEC-02** Scenarios are executable acceptance tests against the produced software
- [ ] **SPEC-03** Verifier runs all scenarios in sandbox; pass = done, fail = loop

**GitHub integration**
- [ ] **GIT-01** Kiln drives `git commit` / `git push` via shell in workspace
- [ ] **GIT-02** Kiln opens PR via `gh` when workflow has a PR stage
- [ ] **GIT-03** Kiln reads/updates GitHub Actions status on PRs
- [ ] **GIT-04** GitHub Actions workflow shipped for Kiln itself (mix test, credo, dialyzer, xref)

**UI (LiveView dashboard)**
- [ ] **UI-01** Run board (kanban-style columns by state); real-time via PubSub
- [ ] **UI-02** Run detail: stage graph, per-stage diff viewer, logs, events, agent chatter
- [ ] **UI-03** Workflow registry: list, view YAML, show version history
- [ ] **UI-04** Token/cost dashboard per run, per workflow, per agent
- [ ] **UI-05** Audit ledger view (append-only events, filterable)
- [ ] **UI-06** Kiln brand book applied globally (Inter/IBM Plex Mono, coal palette, border-first components, operator microcopy)

**Observability & audit**
- [ ] **OBS-01** Structured logging with correlation_id, causation_id, actor, run_id, stage_id on every log line
- [ ] **OBS-02** OpenTelemetry traces — Kiln emits spans per stage/agent call
- [ ] **OBS-03** Append-only audit ledger with time-travel query support
- [ ] **OBS-04** Stuck-run detector: alerts + halts when no progress for configurable interval

**Local dev & distribution**
- [ ] **LOCAL-01** `docker-compose up` spins up Kiln + Postgres + sandbox runtime
- [ ] **LOCAL-02** `.tool-versions` pins Elixir/Erlang for `asdf`
- [ ] **LOCAL-03** README with zero-to-first-run walkthrough

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- **Multi-tenant / teams / RBAC** — solo-engineer focus; team features come only after self-use is proven
- **Billing, SaaS hosting, paid product** — dogfood first; productize later if at all
- **Hosted cloud runtime** — local Docker only; no K8s deploy, no AWS/GCP IaC in v1
- **Human approval gates / synchronous review UI** — anti-pattern for the dark factory model; bounded autonomy handles safety instead
- **Web-based workflow authoring UI** — workflows are YAML files versioned in git; LiveView renders them read-only
- **Kiln-hosted model weights / embedded inference** — Kiln calls external APIs; it does not run local models itself (Ollama integration is via its HTTP API, not embedded)
- **SSO / OIDC / enterprise auth** — solo use, no login needed in v1
- **Workflow marketplace or sharing** — single-user, single-workspace
- **Mobile app / mobile UI** — desktop-first operator dashboard

## Context

**Origin.** Ambitious attempt to productize the "dark software factory" pattern — as seen at StrongDM (their public "no human reads the code" factory), Gas Town (Steve Yegge's multi-agent orchestration system with "beads" durable work tracking), and Fabro (open-source dark factory platform with stage graphs and cloud sandboxes). Kiln is the Elixir/Phoenix/OTP-native take: use BEAM processes, supervisors, and PubSub as the natural substrate for agent orchestration instead of bolting a coordination layer on top of a language that doesn't have one.

**Prior art consumed.** Five upstream research docs in `prompts/` cover Elixir, Phoenix, LiveView, Ecto, and Elixir system-design best practices (all current to 2026). Two vision docs (`software dark factory prompt.txt`, `software dark factory prompt feedback.txt`) define the product intent and a tightened constitution for how agents should operate. `dark_software_factory_context_window.md` establishes the four-layer mental model (Intent → Workflow → Execution → Control) that the architecture should reflect. `kiln-brand-book.md` locks the visual/voice contract.

**Reliability lessons.** Public feedback on GSD/GSD-2 and Fabro shows these systems become fragile when autonomy, retries, and artifacts are not tightly bounded — stuck loops, repeated retries, cost runaway. Kiln optimizes for *bounded autonomy*, not maximum autonomy: hard caps, explicit escalation conditions, never silently continue after repeated verification failure.

**Dogfood goal.** Kiln should eventually build Kiln features. v1 end-to-end validation is a small spec that Kiln actually ships (e.g., a tiny Elixir CLI library), proving every layer works together on real code.

## Constraints

- **Tech stack (locked)**: Elixir 1.18+ / OTP 27+ / Phoenix 1.8+ / LiveView 1.1+ / Postgres 16+ / Oban / Bandit / OpenTelemetry. Deviate only with explicit written reason in a Key Decisions row.
- **Platform**: macOS + Linux local dev; Docker Desktop / Docker Engine 24+; GitHub as the sole source host.
- **Persona**: Solo operator. No auth, no multi-tenant, no team permissions until self-use is proven.
- **Autonomy bounds**: Every run MUST cap retries, token spend, and elapsed steps. Escalation = halt + diagnostic artifact, never silent continue.
- **Sandboxing**: Every code/test stage runs in an ephemeral Docker container with network egress blocked except to Kiln-hosted mocks.
- **Durability**: Postgres is source of truth for run state; Oban is durable job layer; append-only audit ledger is non-negotiable; full event sourcing only where replay materially pays.
- **Idempotency**: Every Oban job and every external side-effect (git push, API call, GitHub action) MUST have an idempotency key and be safe under replay/retry.
- **Observability**: Structured logging with correlation IDs is mandatory on every log line; OpenTelemetry traces per stage.
- **Brand**: Kiln brand book applies to every UI surface — Inter + IBM Plex Mono, coal/char/iron/bone/ash/ember palette, borders over shadows, state-aware components, operator microcopy ("Start run", "Verify changes", "Build verified").

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Kiln is an **orchestrator of external agents** (calls LLM APIs), not a self-contained agent framework | Product clarity: Kiln owns workflows, state, sandboxes, audit; agents are tools it invokes | — Pending |
| **Solo engineer, local-first**; no team/multi-tenant in v1 | Scope discipline; prove single-user value before investing in team primitives | — Pending |
| **Full spec → plan → code → verify → commit → push → iterate** loop in v1, not a subset | Anything less doesn't demonstrate the dark-factory thesis; partial demos would mislead | — Pending |
| Workflows defined as **YAML/JSON graph files**, not an Elixir DSL | Portable across languages/AI; human/machine-readable; versionable in git; survives Kiln rewrites | — Pending |
| **Gastown-inspired OTP supervisor/worker agent tree** (Planner, Coder, Tester, Reviewer, UI/UX, QA, Mayor) | Maps cleanly to BEAM processes; crash-isolation + fault tolerance are free; idiomatic Elixir | — Pending |
| **Language-agnostic software output**; Kiln itself is Elixir/Phoenix | Kiln must work for every project type; dogfooding Kiln-on-Kiln validates this | — Pending |
| **Provider-agnostic LLM adapter** from v1 (Anthropic/OpenAI/Google/Ollama) | Avoids vendor lock; lets per-stage model selection trade off quality/cost/latency | — Pending |
| **No human approval gates** in the execution loop | Defining feature of the dark factory model; bounded autonomy (caps + escalation) handles safety instead | — Pending |
| **Sandbox = ephemeral Docker + network egress blocked + DTU mocks** | Safety + reproducibility + offline-friendly specs; validated by StrongDM's public writeup | — Pending |
| **Public repo** at `github.com/szTheory/kiln` from day one | Dogfood GitHub/gh/Actions integration; build in public | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-18 after initialization*
