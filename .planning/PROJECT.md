# Kiln

## What This Is

Kiln is a **software dark factory** — an Elixir/Phoenix LiveView application that orchestrates external LLM agents (Claude, OpenAI, Google, local) to autonomously produce shipped software end-to-end. Given a spec, Kiln plans, codes, tests, verifies, commits, pushes, and iterates until the spec is met. A live LiveView dashboard shows the factory "cranking" — stages progressing, agents talking, diffs landing, CI passing — with no human intervention in the loop. Inspired by Gas Town (agent hierarchy + durable work tracking), Fabro (deterministic workflow graphs + stage-level checkpointing), and StrongDM (scenario-based validation + digital twin universe for mocked externals).

## Core Value

**Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.**

That single promise is what the whole system must deliver. Every design tradeoff defers to it.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- [x] **OBS-01**, **OBS-03** — validated in Phase 1 (Foundation & Durability Floor).
- [x] **ORCH-01** Workflow definition format: YAML/JSON graph, versioned in git, schema-validated at load — validated in Phase 2 (Workflow Engine Core).
- [x] **ORCH-02** Stage executor runs each stage in a supervised BEAM process with crash isolation — validated in Phase 2.
- [x] **ORCH-03** Run state machine: queued → planning → coding → testing → verifying → (merged | failed | escalated); persisted to Postgres — validated in Phase 2.
- [x] **ORCH-04** Checkpointing: every stage writes an artifact + event before emitting success; runs resumable from last checkpoint — validated in Phase 2.
- [x] **ORCH-07** Idempotency: every Oban job has idempotency key; every external side-effect is retry-safe — validated in Phase 2.
- [x] **LOCAL-01** — `docker compose` runs **Postgres** (required for dev), **DTU** + internal sandbox network for stage sandboxes, and optional **OTel/Jaeger**. The **Phoenix app runs on the host** (`mix phx.server`; Elixir/OTP per `.tool-versions`). Single-command “Kiln in Compose” / devcontainer is **not** v0.1.0 scope — see **Phase 12** and `.planning/research/LOCAL-DX-AUDIT.md`. — Phase 1 + operator docs (wording corrected 2026-04-22).
- [x] **LOCAL-02** — `.tool-versions` pins Elixir/Erlang — Phase 1.
- [x] **LOCAL-03** — README zero-to-first-run walkthrough — Phase 9.
- [x] **Phases 2–9 (v0.1.0 capability bundle)** — ORCH-05/06; AGENT-01..05; SAND-01..04; SPEC-01..03; GIT-01..04; UI-01..09; OBS-02, OBS-04 (OBS-01/OBS-03 were Phase 1); UAT-01/02; BLOCK-01..04; INTAKE-01..03; OPS-01..05 — shipped per `.planning/ROADMAP.md` Phases 2–9 (2026-04-20–22). REQ IDs remain the stable vocabulary for audits and future milestones.

### Active

<!-- v0.2 — operator dogfood + DX. Promoted from backlog / phase plans when execution starts. -->

- [ ] **DOGFOOD-01** — First **external** repo run from local Kiln (Game Boy emulator **vertical slice**: spec + workflow + BDD + bounded caps; open test ROMs only). Context: `.planning/phases/11-gameboy-dogfood-vertical-slice/GB-SPIKE.md`, Phase **11** plan.
- [ ] **LOCAL-DX-01** — Optional single-command / containerized dev environment (devcontainer vs Compose `app` vs task runner — **TBD**). **Phase 12** (after Phase **10** runbook).
- [ ] **DOCS-ALIGN-01** — Keep `PROJECT.md` / `REQUIREMENTS.md` / roadmap in sync at each milestone boundary. **Phase 13**.

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
- **Manual QA on generated code** — scenario runner is the acceptance oracle; any manual QA is a Kiln bug
- **Freeform chat as the primary unblock mechanism** — unblocks are typed + playbook-driven, not conversational (preserves determinism + audit clarity)

## Context

**Origin.** Ambitious attempt to productize the "dark software factory" pattern — as seen at StrongDM (their public "no human reads the code" factory), Gas Town (Steve Yegge's multi-agent orchestration system with "beads" durable work tracking), and Fabro (open-source dark factory platform with stage graphs and cloud sandboxes). Kiln is the Elixir/Phoenix/OTP-native take: use BEAM processes, supervisors, and PubSub as the natural substrate for agent orchestration instead of bolting a coordination layer on top of a language that doesn't have one.

**Prior art consumed.** Five upstream research docs in `prompts/` cover Elixir, Phoenix, LiveView, Ecto, and Elixir system-design best practices (all current to 2026). Two vision docs (`software dark factory prompt.txt`, `software dark factory prompt feedback.txt`) define the product intent and a tightened constitution for how agents should operate. `dark_software_factory_context_window.md` establishes the four-layer mental model (Intent → Workflow → Execution → Control) that the architecture should reflect. `kiln-brand-book.md` locks the visual/voice contract.

**Reliability lessons.** Public feedback on GSD/GSD-2 and Fabro shows these systems become fragile when autonomy, retries, and artifacts are not tightly bounded — stuck loops, repeated retries, cost runaway. Kiln optimizes for *bounded autonomy*, not maximum autonomy: hard caps, explicit escalation conditions, never silently continue after repeated verification failure.

**Dogfood goal.** Kiln should eventually build Kiln features. v1 end-to-end validation is a small spec that Kiln actually ships (e.g., a tiny Elixir CLI library), proving every layer works together on real code.

## Constraints

- **Tech stack (locked)**: Elixir 1.19.5+ / OTP 28.1+ / Phoenix 1.8.5+ / LiveView 1.1.28+ / Postgres 16+ / Oban 2.21+ OSS / Bandit 1.10+ / OpenTelemetry (traces stable). Deviate only with explicit written reason in a Key Decisions row.
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
| **Scenario runner is sole acceptance oracle** — UAT/integration/E2E fully automated; zero manual QA | Dark factory thesis depends on no manual verification bottleneck; shift-left into CI; human unblocks only for typed blockers (credentials, auth, budget, escalation) | — Pending |
| **Typed block reasons + remediation playbooks** (not freeform chat) | Structured unblock UX preserves determinism and audit clarity; chat-to-unblock breaks replay and hides intent | — Pending |
| **Adaptive model routing** with automatic 429/5xx fallback + recorded `actual_model_used` | Avoids Fabro-class silent-fallback cost/quality drift; makes quota/rate-limit visible, not hidden | — Pending |
| **Opinionated model-profile presets** per software-type scenario; switchable per run/stage | Good defaults are the difference between "it works out of the box" and "another config nightmare"; stays switchable so operators keep control | — Pending |
| Bump Elixir/OTP baseline to **1.19.5 / 28.1+** per STACK research | Current stable as of April 2026; Phoenix 1.8 generators assume it; starting one major behind on day one is avoidable cost | — Pending |

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
## Current State (as of 2026-04-22)

- **Milestone v0.1.0 (Phases 1–9)** — Shipped per `.planning/ROADMAP.md`. Runtime: Postgres + DTU + optional OTel via Compose; Phoenix on host; LiveView operator UI; sandbox + agents + GitHub path; dogfood CI on Kiln itself.
- **Next milestone v0.2** — Operator dogfood (Phases **10–13**); plans under `.planning/phases/10-*` … `13-*`. **Phase 11 plan 11-01 (2026-04-22):** Kiln-side scenario **shell** oracle bridge, `rust_gb_dogfood_v1` workflow YAML, `priv/dogfood/gb_vertical_slice_spec.md`, and README **D-1105** wiring — external Rust clone + `cargo test` argv swap still operator-owned per GB-SPIKE.
- **Validated requirements:** See **Validated** section above (Phase 1 items + Phases 2–9 bundle line).
- **Known operator action:** Host port `5432` may conflict with other Postgres instances — change host port in Compose or stop the other service.
- **New seeds planted:** SEED-002, SEED-003, SEED-004 — dormant until their trigger conditions fire.

## Next milestone goals (v0.2)

1. Run Kiln locally against a **throwaway git remote** and complete at least one bounded run for an external spec (Game Boy emulator vertical slice).
2. Decide and optionally implement **one** local DX improvement in **Phase 12** after Phase **10**.
3. Milestone-close hygiene: `PROJECT.md` / `REQUIREMENTS.md` / `ROADMAP.md` stay aligned (**DOCS-ALIGN-01** / **Phase 13**).

---
*Last updated: 2026-04-22 — Phase 11 plan 11-01 executed (Kiln-side dogfood prerequisites)*
