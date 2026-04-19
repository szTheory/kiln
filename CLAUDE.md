<!-- GSD:project-start source:PROJECT.md -->
## Project

**Kiln** — a software dark factory written in Elixir/Phoenix LiveView that orchestrates external LLM agents to autonomously produce shipped software end-to-end. Given a spec, Kiln plans, codes, tests, verifies, commits, pushes, and iterates until the spec is met. A live LiveView dashboard shows the factory "cranking" with no human intervention in the loop.

**Core Value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

**Persona:** Solo engineer, local-first, Docker Compose. Multi-tenant/SaaS/team features are explicitly out of scope in v1.

See `.planning/PROJECT.md` for full context, requirements, constraints, and key decisions.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:STACK.md -->
## Technology Stack

- **Elixir 1.19.5+ / OTP 28.1+** — baseline runtime
- **Phoenix 1.8.5 + LiveView 1.1.28** — operator dashboard; Bandit 1.10 HTTP server
- **Ecto 3.13 + Postgres 16** — single source of truth for run state
- **Oban 2.21 OSS + Oban Web 2.12 OSS** — durable jobs, mounted at `/ops/oban`
- **Req 0.5** — sole HTTP client, named Finch pools per LLM provider
- **Anthropix 0.6** — Anthropic SDK, wrapped behind `Kiln.Agents.Adapter` behaviour
- **yaml_elixir 2.12 + JSV 0.18** — workflow YAML parsing + JSON Schema Draft 2020-12 validation
- **OpenTelemetry 1.6** (Erlang SDK) — traces stable; use `:telemetry` + LiveDashboard for metrics in v1
- **logger_json 7.0** — structured JSON logging with correlation_id/run_id/stage_id metadata
- **Docker CLI via `System.cmd`** — sandbox driver (NOT socket mount); `ex_docker_engine_api` for introspection only
- **Testing:** ExUnit + LiveViewTest + LazyHTML + StreamData + Mox
- **Static analysis:** Dialyxir + Credo + `mix xref graph --format cycles`
- **Security:** mix_audit + sobelow via `mix check` meta-runner

See `.planning/research/STACK.md` for verified versions, alternatives, and installation.
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

- **Postgres is source of truth.** OTP processes are transient accelerators that hydrate from the database on boot. If every BEAM process died now, a fresh boot must continue every in-flight run from its last checkpoint with no human intervention.
- **Append-only audit ledger is non-negotiable.** Every state transition writes an `Audit.Event` in the same Postgres transaction as the state change. INSERT-only is enforced at the DB level via `CREATE RULE ... DO INSTEAD NOTHING`.
- **Idempotency everywhere.** Oban unique jobs are **insert-time only**, not execution-time — pair every external side-effect with an `external_operations` intent-table row (two-phase intent → action → completion).
- **No Docker socket mounts.** Sandboxes use `System.cmd("docker", ...)` + `--cap-drop=ALL` + rootless + egress blocked at the Docker network layer (`internal: true`). Never mount `/var/run/docker.sock`.
- **Secrets are references, not values.** `SEC-01`: store secret names, fetch from `persistent_term` at point-of-use, redact via `@derive {Inspect, except: [:api_key]}`, never persist to workspace, never render to UI/logs.
- **Bounded autonomy.** Per-run hard caps on retries, token USD, elapsed steps. Escalation = halt with diagnostic artifact; never silently continue after repeated verification failure.
- **Scenario runner is the sole acceptance oracle.** UAT/integration/E2E automated in CI; zero manual QA. Human intervention reserved only for typed blockers (credentials, first-time auth, budget approvals, hard escalations).
- **Typed block reasons, not chat.** `BLOCK-01`: unblocks use structured remediation playbooks, not freeform chat — preserves determinism and audit clarity.
- **Adaptive model routing.** Record both `requested_model` and `actual_model_used` on every stage to catch silent fallback. ModelRegistry falls back on 429/5xx with operator notification when a tier is crossed.
- **Run state is an Ecto field + command module** (`Kiln.Runs.Transitions`), NOT `:gen_statem` (splits truth between DB and memory).
- **No umbrella app.** Single Phoenix app with 12 strict bounded contexts; `mix xref graph --format cycles` in CI enforces boundaries.
- **No GenServer-per-work-unit.** Work units are Ecto rows + PubSub (beads-equivalent, Option A per BEADS.md); GenServers are for *behavior*, not *data organization*.
- **Elixir-specific anti-patterns to avoid:** boolean obsession (use enums), GenServer overuse, `Process.put/2` for state, event sourcing everywhere, `Mix.env` at runtime, secrets in compile-time config, `apply/3` on hot paths.

### Brand contract (every UI surface)

- **Typography:** Inter primary sans; IBM Plex Mono; Geist for marketing only.
- **Palette:** Coal #121212, Char #1B1D21, Iron #262B31, Bone #F5EFE6, Ash #C7BFB5, Smoke #8C857D, Clay #9A5634, Ember #E07A3F, Paper #FAF6F0, Ink #161514.
- **Voice:** precise, calm, grounded, competent, restrained. No hype, no slang, no "AI magic." Short sentences. Concrete nouns. Active verbs. Always say what happened, what happens next, user action.
- **Microcopy:** "Start run", "Resume run", "Verify changes", "Promote build", "View trace", "Build verified", "Verification failed", "Retry step", "Waiting on upstream", "Manual review required".
- **UI rules:** rectangles first, slightly softened corners; borders over shadows; clear state hierarchy; every component has loading/empty/success/warning/error/focus/disabled states. Operator clarity beats decorative flourish.
- **Avoid:** cyberpunk neon, sparks, flames, robots, AI brains, mascots, fantasy forge imagery, loud gradients, factory clip art.

See `.planning/PROJECT.md` Constraints + Key Decisions; `prompts/kiln-brand-book.md` for full brand contract.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Kiln is a **four-layer system** (Intent → Workflow → Execution → Control) implemented as a **single Phoenix app** with 12 strict bounded contexts:

- **Intent layer:** `Kiln.Specs`, `Kiln.Intents`
- **Workflow layer:** `Kiln.Workflows` (YAML loader, JSV schema validation, topological graph compile)
- **Execution layer:** `Kiln.Runs`, `Kiln.Stages`, `Kiln.Agents`, `Kiln.Sandboxes`, `Kiln.GitHub`
- **Control layer:** `Kiln.Audit`, `Kiln.Telemetry`, `Kiln.Policies` (read-only leaves for everything else)

**OTP supervision tree:** `Kiln.Application` → Repo + PubSub + Registries + Oban + `RunDirector` GenServer + `RunSupervisor` DynamicSupervisor + `DTU.Supervisor` + `StuckDetector` + Endpoint. Each run hangs a transient subtree under `RunSupervisor` with `Run.Server` + `Agents.SessionSupervisor` + `Sandboxes.Supervisor`. Agent sessions are `:temporary` + monitored (not linked) so misbehaving agents die without killing the run.

**Run state machine:** Ecto `state` field + `Kiln.Runs.Transitions` command module. Every transition opens a Postgres tx, `SELECT … FOR UPDATE`, asserts guard, updates state + writes `Audit.Event` in the same tx, broadcasts on PubSub. Allowed transitions: `queued → planning → coding → testing → verifying → (merged | failed | escalated)`.

**Work units (beads-equivalent):** `work_units` current-state table + `work_unit_events` append-only ledger + PubSub broadcast. No GenServer per unit (would be process explosion + Elixir anti-pattern).

**Sandbox:** `System.cmd("docker", ...)` + Port; ephemeral container per stage; Docker bridge network `internal: true`; DTU mocks on the same bridge; workspace mounted RW; diff captured at stage end.

See `.planning/research/ARCHITECTURE.md` for full supervision tree, Ecto schemas, anti-patterns, and directory layout.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills yet. Add skills to `.claude/skills/` with a `SKILL.md` index file as the project matures. Candidates for skill-ification after Phase 9: `kiln-workflow-authoring`, `kiln-adding-provider`, `kiln-writing-spec`.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.

### Project-specific gates

- **Research-before-planning** is enabled for Phases 3, 4, and 5 (HIGH research flags). Run `/gsd-research-phase N` before `/gsd-plan-phase N` for those.
- **No application code** has been written yet — Phase 1 is the first phase that produces Elixir/Phoenix source.
- **Public repo:** all work lands on `github.com/szTheory/kiln` via GitHub Actions CI (`mix check`).

Next action after project init: `/gsd-discuss-phase 1` (gather context) then `/gsd-plan-phase 1`.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` — do not edit manually.
<!-- GSD:profile-end -->
