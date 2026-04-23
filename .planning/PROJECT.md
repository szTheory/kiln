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
- [x] **LOCAL-01** — `docker compose` runs **Postgres** (required for dev), **DTU** + internal sandbox network for stage sandboxes, and optional **OTel/Jaeger**. **Canonical:** **Phoenix on the host** (`mix phx.server`; Elixir/OTP per `.tool-versions`) with Compose as the data plane — see **Phase 12** + `README.md` quick start. **Optional (Phase 21):** [`.devcontainer/`](.planning/phases/21-containerized-local-operator-dx/) + README “Optional: Dev Container” — same Compose + DooD model; BEAM may run in a Linux devcontainer for reproducible toolchain / minimal host installs. — Phase 1 + Phase 12 + Phase 21 operator docs (2026-04-23).
- [x] **LOCAL-02** — `.tool-versions` pins Elixir/Erlang — Phase 1.
- [x] **LOCAL-03** — README zero-to-first-run walkthrough — Phase 9.
- [x] **Phases 2–9 (v0.1.0 capability bundle)** — ORCH-05/06; AGENT-01..05; SAND-01..04; SPEC-01..04; GIT-01..04; UI-01..09; OBS-02, OBS-04 (OBS-01/OBS-03 were Phase 1); UAT-01/02; BLOCK-01..04; INTAKE-01..03; OPS-01..05 — shipped per `.planning/ROADMAP.md` Phases 2–9 (2026-04-20–22). REQ IDs remain the stable vocabulary for audits and future milestones.
- [x] **DOCS-ALIGN-01** — `PROJECT.md` **Validated**, `REQUIREMENTS.md` § v1 checkboxes, and `ROADMAP.md` stay mutually consistent at milestone boundaries — Phase 13 (`13-01-PLAN.md`).
- [x] **LOCAL-DX-01** — Optional **`justfile`** task-runner layer (host Phoenix + Compose data plane; no second official quick-start). README optional subsection + `LOCAL-DX-AUDIT.md` pointer — **Validated in Phase 12: local-docker-dx** (2026-04-22). **Phase 21** adds optional **Dev Container** tier (see **LOCAL-01**); `justfile` remains thin sugar over the same primitives.
- [x] **DOGFOOD-01** — Kiln-side **external-repo vertical slice** for the Game Boy emulator path: spec + workflow + BDD + bounded caps scaffolding (`rust_gb_dogfood_v1`, scenario argv-only shell oracle, `priv/dogfood/gb_vertical_slice_spec.md`, tests) — **Phase 11** (2026-04-22). Full ROM-backed `cargo test` on a disposable clone remains **operator-owned** per `GB-SPIKE.md`.
- [x] **WFE-01** — Workflow + spec template library with instantiate action — **Validated in Phase 17: template-library-onboarding-specs** (2026-04-22).
- [x] **ONB-01** — ≥3 vetted onboarding templates incl. fast happy path — **Validated in Phase 17: template-library-onboarding-specs** (2026-04-22).
- [x] **PARA-01** — Fair parallel run scheduling — **Validated in Phase 14: fair-parallel-runs** (2026-04-22).
- [x] **PARA-02** — Run comparison view — **Validated in Phase 15: run-comparison** (2026-04-22).
- [x] **REPL-01** — Read-only run timeline / replay MVP — **Validated in Phase 16: read-only-run-replay** (2026-04-22).
- [x] **COST-01**, **COST-02** — Advisory cost hints + budget threshold alerts — **Validated in Phase 18: cost-hints-budget-alerts** (2026-04-22).
- [x] **SELF-01**, **FEEDBACK-01** — Merged-run post-mortem artifact + non-blocking operator nudge audit path — **Validated in Phase 19: post-mortems-soft-feedback**; formal verification + planning SSOT in **Phase 20** (`19-VERIFICATION.md`, archived **`.planning/milestones/v0.3.0-REQUIREMENTS.md`**) (2026-04-22).
- [x] **DOCS-08** — Merge authority SSOT in `.planning/PROJECT.md` (`## Merge authority`) + compact README pointer to `#merge-authority`; Phase 12 `12-01-SUMMARY.md` cited for local PARTIAL vs CI — **Validated in Phase 22: merge-authority-operator-docs** (2026-04-23).
- [x] **NYQ-01** — Phases 14, 16, 17, and 19 now end with explicit Nyquist compliant or waiver posture — **Validated in Phase 23: nyquist-validation-closure** (2026-04-23).
- [x] **UAT-03** — Template -> run LiveView smoke with stable ids and verification citation — **Validated in Phase 24: template-run-uat-smoke** (2026-04-23).

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
| **Scenario runner is sole acceptance oracle** — UAT/integration/E2E fully automated; zero manual QA | Dark factory thesis depends on no manual verification bottleneck; shift-left into CI; human unblocks only for typed blockers (credentials, auth, budget, escalation) | ✓ Active policy |
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
## Next Milestone Setup

No milestone is currently open. **v0.4.0** shipped on 2026-04-23 and its requirements, roadmap snapshot, and audit now live under `.planning/milestones/`.

**Next command:** `/gsd-new-milestone`

Use the next milestone to define the next requirements slice, keep integer phase numbering moving forward from **25**, and decide whether backlog item **999.3** should remain parked or be promoted into milestone scope.

## Merge authority

**Policy:** A pull request may merge into **`main`** once **GitHub Actions** is green for that pull request. Exact enforcement (required checks, review counts) lives in GitHub branch protection; this section maps what operators see in the Actions UI to jobs in **`.github/workflows/ci.yml`**.

| Tier | Role | Job `name:` (today) | What it proves |
|------|------|---------------------|----------------|
| **A** | PR merge gate | **`mix check`** | `mix compile --warnings-as-errors`, then full **`mix check`** (format, tests, Credo, Dialyzer, Sobelow, `mix_audit`, xref cycle gate, grep gates) on the workflow **Postgres 16** service container |
| **B** | Durability / DB invariants | Same `check` job | Step **`Kiln boot checks (CI parity — D-34)`** — `KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks` |
| **C** | Compose integration smoke | **`integration smoke (first_run.sh)`** | After `check`: `bash test/integration/first_run.sh` (Compose + host boot path drift) |
| **D** | UI / shift-left acceptance | **`Playwright e2e (14 routes x light/dark x mobile/desktop + axe)`** | After `check`: `mix kiln.e2e` coverage for the operator UI path with Playwright + axe |
| **E** | Tag-only | **`tag vs mix.exs version`** | Runs only on **`v*`** tags; not required for ordinary PRs |

**Workflow SSOT:** reconcile UI labels with YAML `name:` fields in `.github/workflows/ci.yml` — `mix check`, `integration smoke (first_run.sh)`, `Playwright e2e (14 routes x light/dark x mobile/desktop + axe)`, `tag vs mix.exs version`.

### Recommended before push (optional, not merge authority)

These improve local signal **only**; they are **not** merge gates unless duplicated in CI **and** required by branch protection:

- **`just planning-gates`** — CI-parity `mix check` (defaults mirror `.github/workflows/ci.yml`; Postgres must be reachable).
- **`just shift-left`** — `mix check`, `test/integration/first_run.sh`, then `mix kiln.e2e`; best local mirror of the CI acceptance stack.
- **`script/precommit.sh`** / **`mix precommit`** — `templates.verify` + `mix check` with CI-like defaults when `.env` is missing.
- **`DOCS=1 mix docs.verify`** — site/docs link and orphan checks when enabled.

### Local vs CI

CI runs the gates above on GitHub’s **Postgres 16** service and cached PLT. **Local** `mix check` or compose smoke may report **PARTIAL** or fail when Postgres, Docker, Dialyzer PLTs, or environment variables differ from CI. Factual operator log: `.planning/phases/12-local-docker-dx/12-01-SUMMARY.md` (Phase 12 verification; Self-Check: PARTIAL).

**Phase 21** (optional devcontainer) stays documented in `README.md` **below** the canonical host quick start; it does **not** replace GitHub Actions as merge authority for PRs to **`main`**.

## Current State (as of 2026-04-23)

- **v0.1.0 (Phases 1–9)** — Shipped. See `.planning/milestones/v0.1.0.md`.
- **v0.2.0 (Phases 10–13)** — Shipped; tag **`v0.2.0`**; archives under `.planning/milestones/v0.2.0-*`.
- **v0.3.0 (Phases 14–21)** — **Shipped**; tag **`v0.3.0`**; archives `.planning/milestones/v0.3.0-ROADMAP.md`, `v0.3.0-REQUIREMENTS.md`, `v0.3.0-MILESTONE-AUDIT.md`. Execution scale (14–16), templates (17), cost hints + alerts (18), post-mortems + soft feedback (19), verification SSOT (20), optional container-first operator DX (21) with **`.devcontainer/`** + **`docker_operator.yml`** CI drift gate; host Phoenix + Compose remains canonical.
- **v0.4.0 (Phases 22–24)** — **Shipped**; tag **`v0.4.0`**; archives `.planning/milestones/v0.4.0-ROADMAP.md`, `v0.4.0-REQUIREMENTS.md`, and `v0.4.0-MILESTONE-AUDIT.md`. Scope: merge-authority SSOT, Nyquist closure for carried-over partial validations, and the template -> run LiveView regression.
- **Backlog (shipped 999.2):** Operator **demo vs live** shell chrome (`Kiln.OperatorRuntime`, `OperatorChromeHook`, `Layouts.app` strip) plus provider readiness / config presence (names only, **SEC-01**). See `.planning/ROADMAP.md` and `.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-VERIFICATION.md`.
- **Tech debt carryover:** `12-01-SUMMARY.md` **Self-Check: PARTIAL** — CI + Postgres-backed workstation remain merge authority for `mix check`.
- **Known operator action:** Host port `5432` may conflict with other Postgres instances.

---
*Last updated: 2026-04-23 — v0.4.0 archived and ready for `/gsd-new-milestone`*
