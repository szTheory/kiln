# Project Research Summary

**Project:** Kiln — software dark factory
**Domain:** Elixir/Phoenix LiveView operator dashboard + OTP-native LLM agent orchestrator + Docker sandbox runner + Postgres-durable workflow engine (solo-operator, local-first)
**Researched:** 2026-04-18
**Confidence:** HIGH

## Executive Summary

Kiln is a **software dark factory**: a single Phoenix 1.8 application that orchestrates external LLM agents through a deterministic workflow graph (spec → plan → code → verify → commit → push → loop) with no human approval gates. The "dark factory" product category crystallized around three public reference points — StrongDM's internal factory (no-human-reads, holdout scenarios, Digital Twin Universe), Steve Yegge's Gas Town (Mayor/worker hierarchy, Beads durable work ledger), and Fabro (workflow-as-code with stage checkpoints) — and Kiln's legitimate differentiation sits at their intersection implemented BEAM-natively: OTP supervisors map 1:1 to the mayor/worker pattern without a coordination layer bolted on, Postgres + Oban form the durability floor, and Phoenix PubSub + LiveView drive the real-time operator control-room UI.

The **recommended build** is a single (non-umbrella) Phoenix app on **Elixir 1.19.5 / OTP 28.1+ / Phoenix 1.8.5 / LiveView 1.1.28 / Ecto 3.13 / Oban 2.21 OSS + Oban Web 2.12 (now OSS, mounted at `/ops/oban`) / Bandit 1.10 / Req 0.5 / Anthropix 0.6 behind a `Kiln.Agents.Adapter` behaviour / yaml_elixir 2.12 + JSV 0.18 (Draft 2020-12) / OpenTelemetry for traces / Docker CLI via `System.cmd` for sandboxes**. The architecture resolves around a single non-negotiable invariant: **Postgres is the source of truth for run state; OTP processes are transient accelerators that hydrate from it.** Work unit tracking (the "beads" equivalent) is built **native in Ecto + PubSub** — not by shelling out to the `bd` Go binary — because the data model is what's valuable, the Dolt dependency has recent public data-loss incidents, and a ~200 LOC JSONL adapter preserves the migration path to `bd` if federation ever matters.

The **dominant risk** is unbounded autonomy. Every public postmortem in the category (GSD-2, Gas Town, Fabro, AutoGPT) reports the same failure shape — stuck loops, retry storms, cost runaway, silent fallback to cheaper or alias-drifted models. **Five HIGH-cost pitfalls must be engineered-against from Phase 1 as architectural invariants, not features**: cost runaway (per-LLM-call budget checks), idempotency violations (intent-then-action pattern with external_operations table), sandbox escape (no Docker socket mount, egress blocked at Docker network layer, negative tests), prompt injection from fetched content (typed tool allowlist + untrusted-content markers), and secrets-in-sandbox (short-lived credentials, never inline values). Prevention is the groundwork Phase 1 lays before any end-to-end run exists.

## Key Findings

### Recommended Stack

Elixir 1.19.5 / OTP 28.1+ on Phoenix 1.8 is the current stable baseline as of April 2026 — PROJECT.md currently pins Elixir 1.18+/OTP 27+, which is one major behind from day one. **Flag this for user acceptance during the roadmap phase.** The four load-bearing picks beyond the locked core are: **Oban OSS** for transactionally-inserted durable jobs (the insert-in-same-tx-as-checkpoint guarantee is *the* correctness lever for Kiln's stage pattern); **Req over raw Finch** so the HTTP-adapter step pipeline is reusable across the four LLM providers; **JSV (not ex_json_schema)** for Draft 2020-12 workflow validation; **yaml_elixir (not fast_yaml)** to avoid a C build dep at workflow-file scale. LLM SDK strategy is behaviour-first: `Kiln.Agents.Adapter` with Anthropix for Anthropic and ~200 LOC per provider rolling own on Req for OpenAI / Google / Ollama — LLM APIs drift monthly and community SDKs lag.

**Decisions locked by research:**
- Single Phoenix app, **not** umbrella
- Docker CLI via Port (`System.cmd`), **not** docker socket
- YAML workflows: yaml_elixir + JSV (Draft 2020-12), **not** ex_json_schema
- LLM adapter: Anthropix 0.6.2 behind a behaviour; roll own for OpenAI/Google/Ollama on Req
- Run state: Ecto field + command module (**not** `:gen_statem`, **not** Machinery/Fsmx/ExState)
- Beads pattern: native Ecto `work_units` + PubSub; migration to `bd` binary is a ~200 LOC adapter if ever needed
- Event ledger: append-only enforced at DB level via PostgreSQL `RULE ... DO INSTEAD NOTHING`
- Oban Web OSS (Apache-2.0 as of v2.12.2) mounted at `/ops/oban`

**Core technologies:**
- **Elixir 1.19.5 / OTP 28.1+** — 4x faster compile, improved type checker, required by Phoenix 1.8 generators
- **Phoenix 1.8.5 + LiveView 1.1.28** — real-time operator UI; LazyHTML replaced Floki in LiveViewTest
- **Ecto 3.13 + Postgrex 0.22 + Postgres 16** — single source of truth; `Repo.transact/2`
- **Oban 2.21 OSS + Oban Web 2.12 OSS** — durable jobs, unique insert keys, cron; zero paid tier needed for v1
- **Bandit 1.10** — Phoenix default since 1.7.11; pure Elixir, h2spec/Autobahn compliant
- **Req 0.5** — sole HTTP client on named Finch pools per provider
- **Anthropix 0.6** — wrapped behind `Kiln.Agents.Adapter` so swap is <1 day
- **yaml_elixir 2.12 + JSV 0.18** — YAML parsing + JSON Schema Draft 2020-12 validation
- **OpenTelemetry 1.6** (+ `opentelemetry_phoenix|bandit|ecto|oban`) — traces stable; metrics/logs *development* in Erlang SDK → use `:telemetry` + LiveDashboard for metrics in v1
- **logger_json 7.0** — structured JSON with correlation_id/causation_id/actor/run_id/stage_id on every line
- **Docker CLI via `System.cmd` + `ex_docker_engine_api` 1.43** for introspection; `testcontainers` for integration tests only

### Expected Features

The category has 20 settled table-stakes — all 20 map to existing REQ-IDs in PROJECT.md except **two gap-fills the features research recommends surfacing to the user for explicit roadmap decision**. Kiln's legitimate differentiation is narrow: BEAM-native agent tree, portable YAML workflow graphs, DTU out of the box, OTel-first observability, dogfoodable v1, operator-microcopy brand UX. Twelve anti-features (synchronous human approval gates, multi-tenant/RBAC, web-based workflow authoring, chat-as-UX, mid-stream agent steering, opaque "ACU" billing tokens, etc.) are as load-bearing to the product thesis as the feature list; PROJECT.md Out of Scope captures them correctly.

**Two proposed gap-fill requirements (surface to user during roadmap phase):**
- **SEC-01** — Kiln stores secret *references* only; never renders values in UI or logs; secrets injected into sandbox via short-lived credentials; rotated per-run where possible. (Closes Gap G-01 from FEATURES.md; table-stakes for unattended systems; maps to Pitfalls 5 and 8 prevention.)
- **SPEC-04** — Verifier scenarios stored where Coder/Planner agents **cannot read them**; only Verifier accesses them. StrongDM's pioneering "holdout scenarios" pattern; the single highest-impact quality feature not yet in PROJECT.md v1.

**Must have (v1 table stakes, all in PROJECT.md Active):**
- Workflow YAML schema + state machine + checkpointing + idempotent retries (ORCH-01/03/04/07)
- Provider-agnostic LLM adapter + per-stage model + cost telemetry (AGENT-01/02/05)
- Docker sandbox + egress block + DTU mocks + workspace mount (SAND-01/02/03/04) — **ship as a unit**
- Specialized agent roles + native shared memory / beads-equivalent (AGENT-03/04)
- Executable spec scenarios + verifier + loop + bounded autonomy + stuck detector (SPEC-01/02/03 + ORCH-05/06 + OBS-04)
- git/gh/Actions integration (GIT-01/02/03)
- Structured logging + OTel traces + append-only audit ledger (OBS-01/02/03)
- LiveView run board, run detail, audit view, cost dashboard, workflow registry, brand book (UI-01..06)
- `docker compose up` + `.tool-versions` + README (LOCAL-01/02/03)

**Defer (v1.1+):** parallel runs, time-travel replay UI, run comparison, workflow template library, cost optimization advisor, diagnostic artifact bundle.

### Architecture Approach

Kiln is a **four-layer system** (Intent → Workflow → Execution → Control) implemented as a **single Phoenix app (not umbrella)** with twelve strict bounded contexts. Umbrellas solve multi-release/multi-deploy problems Kiln does not have; contexts plus `mix xref graph --format cycles` in CI plus the optional `boundary` lib solve the boundary problem for solo-engineer scope. The OTP supervision tree hangs a per-run transient subtree under `Kiln.Runs.RunSupervisor` (DynamicSupervisor → per-run `one_for_all` with `Run.Server` + `Agents.SessionSupervisor` + `Sandboxes.Supervisor`) alongside permanent services (`Oban`, `StuckDetector`, `DTU.Supervisor`, `RunDirector`). A `RunDirector` GenServer scans non-terminal runs on boot and re-hydrates the transient tree from Postgres — if every BEAM process died now, a fresh boot must continue every in-flight run from its last checkpoint with no human intervention.

The run state machine is an **Ecto state field driven by a command module** (`Kiln.Runs.Transitions`). Each transition opens a Postgres tx, `SELECT … FOR UPDATE`, asserts guard, updates state + writes `Audit.Event` in the same tx, commits, broadcasts on PubSub. Work-unit tracking (`AGENT-04`, beads-equivalent) is native Ecto: `work_units` current-state table + `work_unit_events` append-only ledger + PubSub broadcast on every mutation; no GenServer-per-unit (that's the "organize code around processes" Elixir anti-pattern).

**Major components (12 contexts, 4 layers):**
1. **Intent** — `Kiln.Specs`, `Kiln.Intents`
2. **Workflow** — `Kiln.Workflows` (YAML loader, JSV validation, graph compile with topological sort + cycle detection)
3. **Execution** — `Kiln.Runs`, `Kiln.Stages`, `Kiln.Agents`, `Kiln.Sandboxes`, `Kiln.GitHub` (stages are Oban jobs wrapped by ephemeral Tasks the run GenServer monitors)
4. **Control** — `Kiln.Audit`, `Kiln.Telemetry`, `Kiln.Policies` (Audit + Telemetry are leaves; read-only for everything else)

### Critical Pitfalls

From 21 cataloged pitfalls, **five are HIGH recovery-cost and must shape Phase 1** as architectural invariants:

1. **Cost runaway from retry storms** — per-run token + USD caps checked *before every LLM call* (not at run boundary); per-workflow caps; global "spend in last 60 min > $Y → pause" circuit breaker; retry backoff capped at 3 attempts with jitter for LLM workers. *Dollars spent on tokens are unrecoverable; prevention is the only mitigation.*
2. **Idempotency violations (duplicate git pushes / API calls)** — Oban unique jobs are **insert-time only**, NOT execution-time; must pair with an `external_operations` intent table keyed by `{run_id, stage_id, op_name}`, two-phase (intent → action → completion), and `git ls-remote` precondition on push.
3. **Sandbox escape via Docker socket / egress** — **never mount `/var/run/docker.sock` into stage containers**; egress blocked at Docker bridge layer with `internal: true` (adversarial negative tests for TCP, DNS, ICMP, IPv6); rootless Docker; `--cap-drop=ALL`; memory/cpu/pid/ulimit caps; secrets never inside sandbox. *Only pitfall whose recovery cost is "rebuild the dev machine."*
4. **Prompt injection from fetched content** — untrusted-content markers in system prompts; typed tool-call allowlist (no raw `run_shell`; only `run_test()`, `commit(message)`, etc.); rate-limit tool calls per minute; egress firewall as backstop.
5. **Secrets in sandbox** — secret references only, never inline; short-lived credentials scoped to the sandbox's mock-network-only; redact via `@derive {Inspect, except: [:api_key]}` + `persistent_term` lookup so keys never land in logs, crash dumps, or changeset errors.

Seven additional MED-cost pitfalls shape ordering: silent retry-forever loops, context-window bloat across stages, mock-vs-real divergence (DTU drift), flaky non-deterministic verifier, Oban `max_attempts: 20` default footgun, model deprecation breaking hard-coded workflows, GenServer overuse wrapping pure logic.

## Implications for Roadmap

**Phase ordering converges across three of the four research dimensions** (FEATURES dependency graph, ARCHITECTURE context DAG, PITFALLS recovery-cost ordering). Use this convergence to seed a **high-confidence eight-phase structure**. Phases 1-3 establish the durability floor and safety groundwork such that every HIGH-cost pitfall is engineered-against before the first end-to-end run exists.

### Phase 1: Foundation & Durability Floor
**Rationale:** Zero-to-first-boot plus the invariants every later phase writes through. Every HIGH-cost pitfall has its structural precondition here: Oban base worker with `max_attempts: 3` default (not 20); structured logging with correlation IDs from line 1; append-only audit ledger enforced at DB level via PostgreSQL `RULE ... DO INSTEAD NOTHING`; `external_operations` table skeleton for idempotency; supervisor tree + restart strategies set deliberately before the first GenServer.
**Delivers:** `docker compose up` boots app + Postgres; health check responds; CI runs `mix check`; append-only audit ledger with insert-only enforcement.
**Addresses:** LOCAL-01, LOCAL-02, OBS-01, OBS-03 (ledger write path).
**Uses:** Elixir 1.19.5, Phoenix 1.8 skeleton, Ecto 3.13, Bandit, Oban OSS, logger_json, OpenTelemetry skeleton.
**Implements:** `Kiln.Audit`, `Kiln.Telemetry`, supervision tree baseline.
**Avoids pitfalls:** P9 (Oban default `max_attempts: 20`), P11 (GenServer overuse), P12 (unsupervised processes), P13 (LiveView memory leaks). Engineers groundwork for P2 (circuit breaker) and P3 (idempotency intent table).

### Phase 2: Workflow Engine Core
**Rationale:** ORCH-01 (workflow YAML schema) blocks everything downstream — without it there is no "run." Must pair with ORCH-03 (state machine), ORCH-04 (checkpointing), ORCH-07 (idempotency) because they share the same write-path discipline.
**Delivers:** YAML workflow loads + JSV Draft-2020-12 validates; compile produces topologically-sorted stage graph; runs start, transition through state machine, checkpoint per stage, resume from checkpoint on crash.
**Addresses:** ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07.
**Uses:** yaml_elixir 2.12, JSV 0.18, Ecto state field + command module pattern, Oban transactional insert, Postgres `SELECT … FOR UPDATE`.
**Implements:** `Kiln.Workflows`, `Kiln.Runs`, `Kiln.Stages`, `Kiln.Runs.RunDirector`, `Kiln.Runs.RunSupervisor`.
**Avoids pitfalls:** P1 (stuck run — sliding-window detector wired in), P3 (idempotency — intent table populated), P4 (context bloat — stage input-contract schema declared here).

### Phase 3: Agent Adapter + Sandbox + DTU
**Rationale:** The safety foundation. All five HIGH-cost pitfalls live in this phase's scope; this is where Kiln becomes "safe to leave running unattended." SAND-01/02/03/04 ship as a unit. `Kiln.Agents.Adapter` behaviour + per-LLM-call budget check + ModelRegistry (role→model with fallback) is the full defense against cost runaway. DTU design deserves a mini-ADR before build.
**Delivers:** Provider-agnostic LLM adapter invokable from a stage; per-stage model routing via workflow YAML; cost telemetry per agent per stage; ephemeral Docker sandbox with egress blocked at Docker network layer; DTU mocks bound to the sandbox network; workspace mount; diff capture.
**Addresses:** AGENT-01, AGENT-02, AGENT-05, SAND-01..04, **SEC-01 (proposed gap-fill)**.
**Uses:** Req 0.5 on named Finch pools per provider; Anthropix 0.6 behind `Kiln.Agents.Adapter`; `System.cmd("docker", ...)` + `ex_docker_engine_api`; Mox behaviour tests; `persistent_term` secret store with `@derive {Inspect, except: [:api_key]}`.
**Implements:** `Kiln.Agents`, `Kiln.Sandboxes`, `Kiln.Sandboxes.DTU.Supervisor`, `Kiln.ModelRegistry`.
**Avoids pitfalls:** P2 (cost runaway), P5 (sandbox escape), P6 (DTU drift), P8 (prompt injection), P10 (model deprecation). Closes SEC-01 gap.

### Phase 4: Agent Tree + Shared Memory (beads-equivalent)
**Rationale:** With adapter + sandbox in place, specialize the agents (Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor) as OTP processes. Native Ecto `work_units` + `work_unit_events` + PubSub — **not** shell-out to `bd` binary, **not** GenServer-per-unit. Migration path to `bd` interop is ~200 LOC JSONL adapter if federation ever matters.
**Delivers:** Mayor/worker process tree; agents coordinate via `Kiln.WorkUnits`; LiveView dashboards subscribe to PubSub topics; `bd ready`-equivalent query uses `blockers_open_count` denormalized cache.
**Addresses:** AGENT-03, AGENT-04.
**Uses:** Ecto + PubSub (no new deps); topic tiers `"work_units"`, `"work_units:<id>"`, `"work_units:run:<run_id>"`.
**Implements:** `Kiln.WorkUnits`, `Kiln.Agents.SessionSupervisor` per run.
**Avoids pitfalls:** Beads incident #2363 class (no destructive CLI suggestions, no `--force` recovery paths, migrations are human-only via `mix ecto.migrate`).

### Phase 5: Spec, Verification, Bounded Loop
**Rationale:** Close the dark-factory loop. **Deterministic verifier first, LLM verifier second** — authoritative pass/fail comes from the actual BDD scenario runner's exit code; LLM's role is to *explain* failure, not *decide* pass/fail. Bounded-autonomy cap semantics is the category's hardest unsolved problem; deserves a focused research pass during planning.
**Delivers:** Spec editor + executable BDD scenarios + deterministic verifier + loop-until-spec-met + bounded autonomy caps (retries, tokens, elapsed steps, escalation = halt + diagnostic artifact) + stuck-run detector (sliding window over (stage, failure-class) tuples).
**Addresses:** SPEC-01, SPEC-02, SPEC-03, ORCH-05, ORCH-06, OBS-04, **SPEC-04 (proposed gap-fill — holdout scenarios)**.
**Uses:** Verifier at `temperature: 0`, `top_p: 1`; JSON-schema-validated typed `%VerifierResult{}`.
**Implements:** `Kiln.Specs`, verifier agent, `Kiln.Policies`, `Kiln.Policies.StuckDetector`.
**Avoids pitfalls:** P1 (stuck run — sliding window active), P2 (cost runaway — global circuit breaker), P7 (flaky verifier). Closes SPEC-04 gap.

### Phase 6: GitHub Integration
**Rationale:** The loop has to close in git for the thesis to hold. `git`/`gh` via `System.cmd` is boring and standard; idempotency is where attention goes — every push and PR op wrapped in an Oban worker with `{run_id, stage_id, "git_push"}` unique key plus `git ls-remote` precondition.
**Delivers:** Commit + push + PR via `gh`; GitHub Actions status read/update on PRs.
**Addresses:** GIT-01, GIT-02, GIT-03.
**Uses:** `Kiln.Git` + `Kiln.GitHub` thin shell-out modules; `external_operations` intent table from Phase 1.
**Implements:** `Kiln.GitHub`, idempotency enforced via DB unique constraint + two-phase intent → action → completion.
**Avoids pitfalls:** P3 (idempotency — duplicate pushes/PRs).

### Phase 7: Operator UI (LiveView Dashboard)
**Rationale:** Build after execution path works — brand-book UI over broken executor wastes effort. LiveView streams + PubSub patterns are well-established; brand book locked in `kiln-brand-book.md`.
**Delivers:** Run board (kanban by state); run detail (stage graph + per-stage diff + logs + events + agent chatter); workflow registry (read-only YAML viewer); token/cost dashboard; audit ledger view; brand book applied globally. Oban Web at `/ops/oban`, LiveDashboard at `/ops/dashboard`.
**Addresses:** UI-01..06.
**Uses:** LiveView 1.1 streams, `stream_async/4`, LazyHTML tests.
**Implements:** `KilnWeb.RunBoardLive`, `KilnWeb.RunDetailLive`, `KilnWeb.AuditLive`, `KilnWeb.WorkflowLive`, `KilnWeb.DashboardLive`.
**Avoids pitfalls:** P13 (LiveView memory leaks — streams, not append-to-assigns; bounded log buffers).

### Phase 8: Dogfood + Polish
**Rationale:** Kiln builds Kiln. End-to-end validation on a real spec. OTel polish once traces flow through every stage/agent call. README finalized after actual first run.
**Delivers:** GitHub Actions workflow for Kiln itself (mix test, credo, dialyzer, xref, sobelow, mix_audit via `mix check`); full OTel span coverage; README with zero-to-first-run walkthrough validated against a fresh clone.
**Addresses:** GIT-04, OBS-02, LOCAL-03.

### Phase Ordering Rationale

- **Durability floor before features.** Audit ledger, idempotency intent table, structured logging, Oban base worker defaults — all the write-path invariants later phases depend on — land in Phase 1 so nothing retrofits them.
- **Safety groundwork as architecture, not feature.** Phases 2-3 bake in every HIGH-cost pitfall's prevention: stuck-loop detector, per-call budget check, external_operations intent table, no-socket-mount sandbox, secrets-as-references, typed tool allowlist, ModelRegistry. By Phase 4's first full agent run, "unsafe" outcomes are architecturally excluded.
- **Grouping by coupled subsystem.** SAND-01/02/03/04 ship together (sandbox without DTU is un-verifiable); ORCH-03/04/OBS-03 share write-path discipline; AGENT-01/02/05 are one subsystem; SPEC-01/02/03 + ORCH-05/06 are one subsystem (the loop can't close partially).
- **UI trails execution.** Running a factory on a pre-brand UI is fine; shipping brand UI around a broken executor is not.
- **Dogfood last.** `GIT-04` is pointless until there's enough Kiln to test.

### Research Flags

Phases likely needing deeper research during planning (`/gsd-research-phase`):

- **Phase 2 (moderate):** Workflow YAML schema design is opinion-heavy — research Fabro DOT + GitHub Actions YAML + Temporal workflow schemas; mini-ADR on workflow YAML signing scheme.
- **Phase 3 (HIGH):** DTU mock generation pipeline is novel territory — only StrongDM has a public writeup. Also: streaming SSE → PubSub → LiveView backpressure pattern (prototype needed). Also: sandbox resource limits policy (memory/cpu/pids/ulimit values). Also: Oban queue taxonomy for cost/rate-limit modeling per provider.
- **Phase 4 (HIGH):** Beads-equivalent behaviors (compaction, ready-queue semantics, cross-agent claim atomicity) — Gas Town Dolt approach has public fragility reports (beads issue #2363 data-loss); Kiln must not recreate those failure modes.
- **Phase 5 (HIGH):** Bounded autonomy cap semantics — the category's hardest unsolved problem.

Phases with standard patterns (skip `/gsd-research-phase`):
- **Phase 1:** Oban + Phoenix + supervision-tree patterns well-established.
- **Phase 6:** `gh` CLI + git shell-out is boring and standard.
- **Phase 7:** LiveView streams + PubSub patterns well-established; brand book locked.
- **Phase 8:** Standard dogfood + docs work.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against Hex.pm and docs current as of April 2026; one MEDIUM sub-item (Anthropix single-maintainer, mitigated by adapter behaviour). |
| Features | HIGH | 12-system competitor matrix from Context7 + official docs + Q1 2026 public writeups; 20 table-stakes all map to existing REQs except SEC-01 and SPEC-04 gap-fills. |
| Architecture | HIGH | 4-layer model → 12 contexts validated against Elixir/Phoenix/Ecto/LiveView/Oban best-practices deep-research; all decisions grounded. |
| Pitfalls | HIGH on technical grounding; MEDIUM-HIGH on public postmortem citations | 21 pitfalls verified against current Elixir/Phoenix/Oban/LiveView/Ecto docs, OWASP LLM Top-10 2025, Docker socket escape literature. Fabro-specific public postmortems are thin. |
| Beads decision | HIGH | Option A (native Ecto + PubSub) scores dominantly 6/8 dimensions; data model from beads source; migration-to-`bd` path sized. |

**Overall confidence:** HIGH.

### Gaps to Address

Research gaps still open for the planning phase (not roadmap-blocking; each is a phase-internal decision):

- **Streaming SSE → PubSub → LiveView backpressure pattern** — Req supports streaming but some providers are fussy; Phase 3 prototype before committing.
- **Sandbox resource limits policy** — specific values for `--memory`, `--cpus`, `--pids-limit`, `--ulimit nofile` → Phase 3 ADR.
- **Oban queue taxonomy** — how many queues (`stages`, `github`, `audit_async`, `dtu`, plus cost/rate-limit segregation per provider)? Phase 2/3.
- **Dialyzer enable/disable gate** — deep-research doc is ambivalent; recommendation is enable with cached PLT, non-gating on early merges; early call needed.
- **Workflow YAML signing scheme** — should workflow files be signed? Mini-ADR during Phase 2.
- **Parallel runs in v1 vs v1.1** — PROJECT.md currently implies sequential v1; operator UX decision pending.
- **Constraint update** — PROJECT.md Constraints pins Elixir 1.18+/OTP 27+; STACK research shows 1.19.5/OTP 28.1+ is the current stable baseline. **Flag for user acceptance during roadmap phase.**

## Sources

### Primary (HIGH confidence)
- `/Users/jon/projects/kiln/.planning/PROJECT.md` — 32 v1 REQs, 10 key decisions
- `/Users/jon/projects/kiln/.planning/research/STACK.md` — Elixir 1.19/OTP 28 + Phoenix 1.8 + Oban + Bandit + OpenTelemetry + anthropix + Req + yaml_elixir + JSV
- `/Users/jon/projects/kiln/.planning/research/FEATURES.md` — 12-system competitor matrix, 20 table stakes, 10 differentiators, 12 anti-features, gap-fills SEC-01 + SPEC-04
- `/Users/jon/projects/kiln/.planning/research/ARCHITECTURE.md` — 4-layer model → 12 contexts, OTP supervision tree, Ecto-field run state machine, Docker CLI sandbox
- `/Users/jon/projects/kiln/.planning/research/PITFALLS.md` — 21 pitfalls with phase mapping and recovery costs
- `/Users/jon/projects/kiln/.planning/research/BEADS.md` — Option A (native Ecto + PubSub); schema + migration sketched; ~200 LOC `bd` adapter path
- `/Users/jon/projects/kiln/prompts/*.md` — Elixir, Phoenix, LiveView, Ecto, system-design deep-research docs
- Hex.pm + HexDocs (Elixir 1.19, Phoenix 1.8.5, LiveView 1.1.28, Ecto 3.13.5, Oban 2.21.1, Oban Web 2.12.2, Bandit 1.10.4, Req 0.5.17, yaml_elixir 2.12.1, JSV 0.18.1, Postgrex 0.22.0)
- `github.com/steveyegge/beads` + `github.com/steveyegge/gastown` local clones
- OWASP LLM Top-10 2025; 2026 prompt-injection taxonomy

### Secondary (MEDIUM confidence)
- Yegge, "Welcome to Gas Town" (Medium); Software Engineering Daily, Feb 2026
- StrongDM "Software Factory" writeup (Feb 2026) via Simon Willison + Stanford CodeX
- Cognition Devin 2026 review; Factory.ai GA + Code Droid; OpenHands 1.6.0; Replit Agent 4; Claude Code Agent Teams docs
- beads issue #2363 (data-loss incident)
- "Agents at Work: 2026 Playbook" (promptengineering.org); Northflank/E2B/Koyeb sandbox comparisons; NVIDIA sandboxing guidance
- phoenix_live_view GitHub issue #3784 (unbounded assigns memory growth)

### Tertiary (LOW confidence — flagged for validation)
- Fabro-specific public postmortems (thin; patterns drawn from adjacent sources)
- OTel metric/log SDK status in Erlang (marked *development* April 2026; re-verify at Phase 8)

---
*Research completed: 2026-04-18*
*Ready for roadmap: yes*
