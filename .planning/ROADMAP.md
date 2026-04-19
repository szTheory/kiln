# Roadmap: Kiln

**Created:** 2026-04-18
**Granularity:** standard (9 phases)
**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Overview

Kiln is a software dark factory: a single Phoenix 1.8 app that orchestrates external LLM agents through a deterministic workflow graph (spec -> plan -> code -> verify -> commit -> push -> loop) with no human approval gates. The roadmap is ordered so the durability floor (Phase 1) and safety groundwork (Phases 2-3) are in place before the first end-to-end run exists; the closed loop (Phases 4-6) is proven before any polished UI is built over it (Phases 7-8); and the whole system is validated by Kiln building Kiln on a real spec (Phase 9). Every HIGH-cost pitfall from PITFALLS.md (cost runaway, idempotency, sandbox escape, prompt injection, secrets-in-sandbox) is engineered-against as an architectural invariant before any stage runs agent-generated code.

The category's reliability lessons are loud and consistent: dark factories fail from unbounded autonomy, silent model fallback, retry storms, and stuck loops. Kiln inverts those by treating the scenario runner as the sole acceptance oracle (UAT-01/02), confining human intervention to a typed short list (BLOCK-01..04), and surfacing the factory's health as a first-class operator concern (OPS-01..05, UI-07..09).

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED) — none at creation

- [ ] **Phase 1: Foundation & Durability Floor** - Project skeleton, Postgres, Oban, structured logging, append-only audit ledger, external_operations intent table, CI baseline
- [ ] **Phase 2: Workflow Engine Core** - YAML workflow schema + loader + graph compile + run state machine + checkpointing + idempotent job wrapper
- [ ] **Phase 3: Agent Adapter, Sandbox, DTU & Safety** - Provider-agnostic LLM adapter, ephemeral Docker sandbox with egress-blocked DTU, secret references, adaptive model routing, typed block reasons, cost budget circuit breaker
- [ ] **Phase 4: Agent Tree & Shared Memory** - Mayor/worker OTP process tree, specialized agent roles, native beads-equivalent work-unit store with PubSub
- [ ] **Phase 5: Spec, Verification & Bounded Loop** - Spec editor + executable BDD scenarios + deterministic verifier + holdout scenarios + loop-until-spec-met + bounded autonomy caps + stuck detector + zero-human-QA enforcement
- [ ] **Phase 6: GitHub Integration** - Idempotent git commit/push, PR creation via `gh`, GitHub Actions status read/write
- [ ] **Phase 7: Core Run UI (LiveView)** - Run board, run detail with stage graph + diff + logs + agent chatter, workflow registry, cost dashboard, audit ledger view, brand book applied
- [ ] **Phase 8: Operator UX (Intake, Ops, Unblock, Onboarding)** - Intake inbox + spec drafts, provider health panel, cost intelligence, diagnostic snapshot, unblock panel, desktop notifications, first-run onboarding wizard, global factory header, per-run progress indicator, agent activity ticker
- [ ] **Phase 9: Dogfood & Release (v0.1.0)** - Kiln builds Kiln on a small real spec; CI for Kiln itself; full OTel span coverage; README validated against fresh clone; v0.1.0 tagged

## Phase Details

### Phase 1: Foundation & Durability Floor
**Goal**: Project boots reproducibly, writes every side effect through a durability- and idempotency-safe baseline, and fails loudly when invariants are violated.
**Depends on**: Nothing (first phase)
**Requirements**: LOCAL-01, LOCAL-02, OBS-01, OBS-03
**Success Criteria** (what must be TRUE):
  1. A fresh clone of the repo runs `docker compose up` and reaches a green health check (app + Postgres + DTU mock network container up) with no manual steps beyond copying a sample `.env`.
  2. `asdf install` and `mix setup` succeed against `.tool-versions` pinning Elixir 1.19.5 / Erlang 28.1+; `mix.exs` pins Phoenix 1.8.5 / LiveView 1.1.28.
  3. Every log line emitted by the app (including from Oban workers and Tasks) carries `correlation_id`, `causation_id`, `actor`, `run_id`, `stage_id` in JSON via `logger_json`; a contrived multi-process test proves metadata threads across `Task.async_stream` and Oban job boundaries.
  4. Attempting `UPDATE` or `DELETE` on `audit_events` in Postgres is rejected at the DB level (`CREATE RULE ... DO INSTEAD NOTHING`); INSERT is the only mutation path; a migration test proves this.
  5. The `external_operations` intent table, the Kiln base Oban worker (`max_attempts: 3` default), and the supervision-tree skeleton are in place and covered by CI; no GenServer in the tree is unsupervised.
**Phase artifacts**: `Kiln.Application` supervision tree; `Kiln.Repo`; `Kiln.Audit` context (INSERT-only events, replay query); `Kiln.Telemetry` context; `Kiln.Oban.BaseWorker` with safe defaults + idempotency helpers; `external_operations` migration + schema; `logger_json` config + `Kiln.Logger.Metadata` threading helper; `docker-compose.yml` (app + Postgres 16 + DTU mock-network container placeholder); `.tool-versions`; `mix check` alias (`mix test`, credo, dialyzer, xref, sobelow, mix_audit); GitHub Actions workflow running `mix check`.
**Pitfalls addressed** (from PITFALLS.md): P9 (Oban max_attempts default lowered to 3), P11 (GenServer overuse — Credo custom check), P12 (unsupervised process — supervision-tree review in CI), P14 (N+1 groundwork — preload discipline), P15 (compile-time secrets — `mix check_no_compile_time_secrets`). Engineers groundwork for P2 (circuit breaker hook point), P3 (idempotency intent table), P13 (stream-first LiveView convention documented).
**Research flag**: standard (Oban, Phoenix, supervision-tree patterns are well-established).
**Plans:** 7 plans
Plans:
- [ ] 01-01-PLAN.md — Phoenix 1.8.5 scaffold + `.tool-versions` + compose.yaml + P1 supervision tree (D-42) + `/ops/dashboard` + `/ops/oban` (LOCAL-01, LOCAL-02)
- [ ] 01-02-PLAN.md — `mix check` gate + GHA CI + custom Credo checks (`NoProcessPut`, `NoMixEnvAtRuntime`) + grep Mix tasks (LOCAL-02, T-02 compile-time secrets mitigation)
- [ ] 01-03-PLAN.md — `audit_events` table + `pg_uuidv7` + `kiln_owner`/`kiln_app` roles + three-layer enforcement (D-12) + `Kiln.Audit` context + JSV payload validation (OBS-03)
- [ ] 01-04-PLAN.md — `external_operations` intent table + `Kiln.Oban.BaseWorker` with safe defaults + 30-day TTL pruner (D-18, D-44, D-49; P3 idempotency groundwork)
- [ ] 01-05-PLAN.md — `logger_json` config + `Kiln.Logger.Metadata.with_metadata/2` + `Kiln.Telemetry.{pack_ctx,unpack_ctx,async_stream,pack_meta}` + Oban handler + contrived D-47 multi-process test (OBS-01)
- [ ] 01-06-PLAN.md — `Kiln.HealthPlug` (mounted pre-`Plug.Logger`) + `Kiln.BootChecks.run!/0` (5 invariants) + `mix kiln.boot_checks` + first_run.sh integration test (LOCAL-01, OBS-03)
- [ ] 01-07-PLAN.md — Spec upgrades D-50 (CLAUDE.md) + D-51 (ARCHITECTURE.md §9 rename) + D-52 (STACK.md pg_uuidv7) + D-53 (Elixir/OTP version drift fix)

### Phase 2: Workflow Engine Core
**Goal**: A YAML workflow loads, validates, compiles into a topologically-sorted stage graph, and a run driven by that graph transitions durably through the state machine with per-stage checkpointing and idempotent retries.
**Depends on**: Phase 1
**Requirements**: ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07
**Success Criteria** (what must be TRUE):
  1. A valid workflow YAML file loaded from disk parses and passes JSV Draft 2020-12 schema validation; a malformed or cyclic workflow halts at load time with a clear error and zero partial state persisted.
  2. Starting a run inserts a `runs` row in `queued`; an operator can observe the run transition through `planning -> coding -> testing -> verifying -> (merged | failed | escalated)` where each transition writes an `Audit.Event` in the same Postgres transaction as the state update (enforced via `Repo.transact/2` + `SELECT ... FOR UPDATE`).
  3. Killing the BEAM mid-stage and rebooting: `RunDirector` re-hydrates the transient supervisor tree from Postgres and the run continues from the last committed checkpoint with no duplicated work and no lost artifacts.
  4. Every external-side-effect intent (LLM call stub, git op stub, Docker op stub) creates a two-phase `external_operations` row (`intent -> action -> completion`); killing the process between intent and action and retrying produces exactly one completion row.
  5. A stage's input contract (typed schema) is validated before the stage runs; oversized or malformed inputs reject at the boundary, not inside the agent.
**Phase artifacts**: `Kiln.Workflows` (yaml_elixir loader, JSV 0.18 schema validation, graph compile with topological sort + cycle detection); `Kiln.Runs` (schema + `Kiln.Runs.Transitions` command module — NOT `:gen_statem`); `Kiln.Stages` (schema, input-contract types, artifact pointers); `Kiln.Runs.RunSupervisor` (DynamicSupervisor) + per-run `one_for_all` subtree; `Kiln.Runs.RunDirector` (GenServer — boot-time rehydration scanner); `Kiln.Runs.Transitions` command module with guarded transition matrix; Oban queue taxonomy (`stages`, `github`, `audit_async`, `dtu`).
**Pitfalls addressed**: P1 (stuck-run detector hook point wired), P3 (idempotency intent table populated), P4 (stage input-contract schema declared — token-bloat defence), P9 (base worker enforces), P19 (artifact content-addressing groundwork).
**Research flag**: moderate. Before planning: mini-ADR on **workflow YAML schema** (compare Fabro DOT / GitHub Actions YAML / Temporal workflow shapes), **Oban queue taxonomy** (per-provider vs per-concern segregation), **workflow YAML signing** (defer-or-now decision).
**Plans**: TBD

### Phase 3: Agent Adapter, Sandbox, DTU & Safety
**Goal**: A stage can invoke an LLM via a provider-agnostic adapter inside an ephemeral Docker container with network egress blocked except to DTU mocks, under per-call budget and typed-block-reason supervision, with secrets never materializing in the sandbox.
**Depends on**: Phase 2
**Requirements**: AGENT-01, AGENT-02, AGENT-05, SAND-01, SAND-02, SAND-03, SAND-04, SEC-01, BLOCK-01, BLOCK-03, OPS-02, OPS-03
**Success Criteria** (what must be TRUE):
  1. A stage calls the Anthropic adapter (Anthropix 0.6 behind `Kiln.Agents.Adapter` behaviour) through a per-provider Finch pool; `requested_model` and `actual_model_used` are both recorded on the stage row; cost + tokens-in + tokens-out emit as `:telemetry` events and OTel spans.
  2. An adversarial negative-test suite verifies a sandbox container cannot reach the public internet over TCP, UDP, DNS, ICMP, or IPv6; it CAN reach the DTU mock network; container has `--cap-drop=ALL`, `--pids-limit`, `--memory`, `--cpus`, `--ulimit nofile` set; `/var/run/docker.sock` is never mounted.
  3. A simulated HTTP 429 from a provider causes `Kiln.ModelRegistry` to fall back to the workflow-configured alternate for the same role; `actual_model_used` reflects the fallback; a Sonnet->Haiku cross-tier fallback emits an operator-visible warning event; fallback across a provider is recorded and visible.
  4. Starting a run with a missing API key halts before any LLM call with a typed `:missing_api_key` block reason mapped to a remediation playbook; `osascript`/`notify-send` fires a desktop notification; no partial sandbox or run state is persisted.
  5. Selecting the `phoenix_saas_feature` model-profile preset at run start resolves role->model pairs deterministically from `Kiln.ModelRegistry`; workflow YAML per-stage overrides win; the preset's resolved mapping is recorded on the run so spend is attributable.
  6. `@derive {Inspect, except: [:api_key]}` + `persistent_term` secret store prove in a test that a crash dump, Logger line, and changeset error never contain the raw API key; `docker inspect` on a running stage container shows no provider secrets in env.
**Phase artifacts**: `Kiln.Agents.Adapter` behaviour + `Kiln.Agents.Adapters.Anthropic` (Anthropix wrap); OpenAI / Google / Ollama adapters scaffolded (~200 LOC each on Req 0.5); `Kiln.ModelRegistry` (role->model resolution, fallback chain, model-profile presets: `elixir_lib`, `phoenix_saas_feature`, `typescript_web_feature`, `python_cli`, `bugfix_critical`, `docs_update`); `Kiln.Agents.BudgetGuard` (per-call token+USD check BEFORE every LLM call); `Kiln.Sandboxes` (`System.cmd("docker", ...)` CLI + `ex_docker_engine_api` for introspection); `Kiln.Sandboxes.DTU.Supervisor` + per-provider DTU mock; Docker Compose `networks.dtu_only: internal: true`; `Kiln.Secrets` (`persistent_term` store, reference-only persistence); `Kiln.Blockers` (typed reason enum + remediation-playbook registry); `Kiln.Notifications` (`osascript`/`notify-send` shell-out); telemetry events `[:kiln, :agent, :call, :stop]` with cost/token measurements; sandbox escape regression test suite.
**Pitfalls addressed**: **All five HIGH-cost** — P2 (cost runaway: per-call BudgetGuard + global circuit breaker), P5 (sandbox escape: no socket mount, egress block, negative tests), P8 (prompt injection: typed tool allowlist, untrusted-content markers groundwork), P21 (secrets in sandbox: short-lived creds, never inline). Plus P6 (DTU drift: weekly contract-test harness scaffolded), P10 (model deprecation: workflows reference roles not IDs), P20 (LLM JSON parse failure: structured output mode).
**Research flag**: HIGH. Before planning, run `/gsd-research-phase`:
  - DTU mock generation pipeline (only StrongDM has a public writeup — novel territory)
  - Streaming SSE -> PubSub -> LiveView backpressure pattern (prototype required before commit)
  - Sandbox resource-limits policy values (`--memory`, `--cpus`, `--pids-limit`, `--ulimit nofile`)
  - Structured-output enforcement per provider
**Plans**: TBD

### Phase 4: Agent Tree & Shared Memory
**Goal**: Specialized agents (Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor) run as supervised OTP processes per-run and coordinate through a native Ecto work-unit store with PubSub — no shell-out to `bd`, no GenServer-per-unit.
**Depends on**: Phase 3
**Requirements**: AGENT-03, AGENT-04
**Success Criteria** (what must be TRUE):
  1. Starting a run spawns a `Kiln.Agents.SessionSupervisor` with the seven agent processes under per-run `one_for_all`; killing a single agent process (e.g., Coder) does not kill peer agents or terminate the run — the run either recovers or escalates with a typed reason.
  2. Any agent can create, claim, block, unblock, and close a work unit via `Kiln.WorkUnits`; every mutation appends to `work_unit_events` and broadcasts on three-tier PubSub topics (`"work_units"`, `"work_units:<id>"`, `"work_units:run:<run_id>"`).
  3. A `bd ready`-equivalent query (work units with zero open blockers, ordered by priority) is served from the `blockers_open_count` denormalized cache with sub-20ms latency under 1000 work units.
  4. No CLI surface of `Kiln.WorkUnits` has a destructive-by-default operation, a `--force` recovery path, or a migration invoked without `mix ecto.migrate` — beads issue #2363 data-loss class is architecturally excluded.
**Phase artifacts**: `Kiln.WorkUnits` context (current-state table `work_units` + append-only `work_unit_events` + denormalized `blockers_open_count` cache); `Kiln.Agents.SessionSupervisor` + one module per role (`Planner`, `Coder`, `Tester`, `Reviewer`, `UIUX`, `QAVerifier`, `Mayor`); agent roles implement a common `Kiln.Agents.Role` behaviour; PubSub topic design doc; `~200 LOC` JSONL adapter stub (migration path to `bd` federation if ever needed).
**Pitfalls addressed**: Beads #2363-class data-loss (no destructive CLI defaults, migrations human-driven), P11 (agents are OTP processes with real state, not GenServer wrappers around pure functions), P12 (all agents supervised).
**Research flag**: HIGH. Before planning, run `/gsd-research-phase`:
  - Beads-equivalent behaviors: compaction policy, ready-queue semantics, cross-agent claim atomicity (Gas Town Dolt has public fragility reports — design must avoid those failure modes)
  - Agent-to-agent handoff protocol (how Mayor delegates; how QA reports back)
**Plans**: TBD

### Phase 5: Spec, Verification & Bounded Loop
**Goal**: The dark-factory loop closes — a spec with BDD scenarios drives the Verifier (deterministic runner is authoritative, LLM explains), the loop-until-spec-met is gated by bounded-autonomy caps and a stuck-run detector, and the scenario runner is the sole acceptance oracle with zero manual QA.
**Depends on**: Phase 4
**Requirements**: SPEC-01, SPEC-02, SPEC-03, SPEC-04, ORCH-05, ORCH-06, OBS-04, UAT-01, UAT-02
**Success Criteria** (what must be TRUE):
  1. An operator writes a spec in the LiveView editor (markdown + Given/When/Then scenarios); on save, scenarios compile to executable acceptance tests runnable inside the sandbox.
  2. A Verifier run uses the deterministic scenario runner's exit code as authoritative pass/fail; the LLM verifier may *explain* a failure but cannot override the exit-code verdict; a contrived disagreement test (runner=fail, LLM=pass) results in `failed`, never `merged`.
  3. Holdout scenarios (SPEC-04) stored in `holdout_scenarios` are accessible only to the Verifier role; a provenance test proves Coder, Planner, and Reviewer agents have no read path to them at workflow-compile or execution time.
  4. A run that hits its per-run retry cap, USD cap, token cap, or elapsed-step cap transitions to `escalated` with a diagnostic artifact written to `audit_events`; it never silently continues past the cap.
  5. The stuck-run detector (sliding window over `(stage, failure-class)` tuples) halts a run that sees the same failure class N times (default N=3) per workflow; `OBS-04` telemetry makes the detection visible.
  6. `mix check` and GitHub Actions CI both run the full scenario suite (including SPEC-04 holdouts); zero code-path success criteria require manual QA — anything that would auto-block for human eyes is recorded as a Kiln bug, not a valid blocker.
  7. Human intervention is reserved for and only for: credential/secret provisioning, first-time external integration auth, budget approvals above cap, and ORCH-06 hard escalations. Anything else triggering a block is reportable as a bug.
**Phase artifacts**: `Kiln.Specs` context (markdown + scenario storage, versioning); `Kiln.Specs.Scenarios` (Given/When/Then parser, compile-to-runner); `Kiln.Agents.Roles.QAVerifier` (deterministic-first, LLM-explain); `holdout_scenarios` table with Verifier-role-only access; `Kiln.Policies` (bounded-autonomy caps: retries / tokens / USD / elapsed steps); `Kiln.Policies.StuckDetector` (sliding window over failure-class tuples); `%VerifierResult{}` typed struct (JSON-schema validated); scenario runner at `temperature: 0, top_p: 1`; `mix check` runs scenarios; UAT enforcement lint (`mix check_no_manual_qa_gates` scans code for TODO/FIXME/ASK-HUMAN markers in code paths).
**Pitfalls addressed**: P1 (stuck-run detector live), P2 (global circuit breaker + per-run caps enforced), P7 (flaky verifier: deterministic-first), P10 (roles not IDs), closes FEATURES.md Gap G-06 (holdout scenarios), architecturally excludes UAT-02 violations.
**Research flag**: HIGH. Before planning, run `/gsd-research-phase`:
  - **Bounded-autonomy cap semantics** — the category's hardest unsolved problem. What counts as a "step"? How do retries and cost caps interact? When does a cap trigger escalation vs retry-with-backoff?
  - Holdout scenario access-control enforcement mechanism (filesystem permissions? Ecto scope? both?)
**Plans**: TBD

### Phase 6: GitHub Integration
**Goal**: Kiln's output lands in git idempotently — commits, pushes, PRs via `gh`, and GitHub Actions status reads — so the dark-factory loop closes externally.
**Depends on**: Phase 5
**Requirements**: GIT-01, GIT-02, GIT-03
**Success Criteria** (what must be TRUE):
  1. A stage completion triggers a commit+push via `System.cmd("git", ...)` wrapped in an Oban worker with idempotency key `{run_id, stage_id, "git_push"}`; killing the worker mid-push and retrying produces exactly one commit on the remote (verified by `git ls-remote` precondition + commit SHA diff).
  2. A workflow with a PR stage opens a pull request via `gh` CLI with title/body/base/reviewers derived from run artifacts; retrying the same PR op produces one PR, not N.
  3. The Verifier can read the GitHub Actions status of a PR via the checks API; when CI passes on the PR, the run transitions to `merged`; when it fails, the run loops back to the Planner with the CI failure diagnostic attached.
  4. A mid-flight failure during `git push` surfaces as a typed `:gh_permissions_insufficient` or `:gh_auth_expired` block (from Phase 3's typed-block contract) with a remediation playbook — never a silent retry-forever.
**Phase artifacts**: `Kiln.Git` (thin `System.cmd` wrapper with `git ls-remote` precondition on push); `Kiln.GitHub` (PR creation via `gh`, checks API reader); Oban workers `Kiln.GitHub.PushWorker`, `Kiln.GitHub.OpenPRWorker`, `Kiln.GitHub.CheckPoller` — all use the `external_operations` intent table from Phase 1; integration test that simulates push race + mid-flight kill.
**Pitfalls addressed**: P3 (idempotent git push + PR — the canonical failure mode), P6 (GitHub API mock-vs-real contract test weekly).
**Research flag**: standard (`gh` + git shell-out is boring).
**Plans**: TBD

### Phase 7: Core Run UI (LiveView)
**Goal**: An operator can watch a run work, inspect any stage's diff/logs/events/agent chatter, see the workflow that's executing, see spend, and audit every event — all under the Kiln brand book.
**Depends on**: Phase 6
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06
**Success Criteria** (what must be TRUE):
  1. A run board loads under 200ms with 10+ concurrent runs, groups runs into kanban columns by state, updates in real time via PubSub, and uses LiveView streams (not unbounded assigns) so the LV process heap stays below 50MB in a 1-hour load test.
  2. A run detail page shows the stage graph (topologically laid out), per-stage unified diff viewer (raw/pretty toggle), bounded log buffer, event timeline, and agent chatter stream — every list-shaped data uses streams and every `handle_event` has an auth check path even if v1 is solo-use.
  3. The workflow registry renders the loaded YAML read-only with version history; there is no web-based workflow editor (anti-feature enforced).
  4. The cost dashboard breaks spend down by run / workflow / agent / provider; shows daily/weekly views and projects end-of-run spend from burn rate; numbers reconcile with the telemetry events from Phase 3.
  5. The audit ledger view filters events by run/stage/actor/event-type with time-range picker; event payloads are inspectable; the view is served from append-only `audit_events` with no write path from UI.
  6. Every UI surface uses Inter + IBM Plex Mono; coal/char/iron/bone/ash/ember palette; borders over shadows; state-aware components (loading/empty/success/warning/error/focus/disabled); operator microcopy ("Start run", "Verify changes", "Build verified", "Retry step") — a brand-book compliance checklist passes on every page.
**Phase artifacts**: `KilnWeb.RunBoardLive`, `KilnWeb.RunDetailLive`, `KilnWeb.WorkflowLive`, `KilnWeb.CostLive`, `KilnWeb.AuditLive`; LiveView stream scaffolds; `stream_async/4` for slow views; `LazyHTML` test helpers; brand-book component library (`KilnWeb.Components.*`); Oban Web mounted at `/ops/oban`; LiveDashboard at `/ops/dashboard`; PubSub topic design doc; bounded log buffer utility.
**Pitfalls addressed**: P13 (LiveView memory leaks — streams everywhere, dynamic container IDs), P14 (N+1 — query-count gates per view in dev), P16 (PubSub topic explosion — topic cardinality bounded), P17 (OTel span context into LV — `opentelemetry_process_propagator`), P18 (LV event auth — every `handle_event` auth-checked even solo).
**Research flag**: standard (LiveView streams + PubSub patterns well-established; brand book locked in `kiln-brand-book.md`).
**Plans**: TBD
**UI hint**: yes

### Phase 8: Operator UX (Intake, Ops, Unblock, Onboarding)
**Goal**: Kiln is operable as a factory — new work enters through intake, ops surfaces (health/cost/diagnostic) answer "why did my run stall?" without log-digging, unblock is a typed clear-action panel rather than a chat, a first-run wizard gets operators from zero to first run, and global surfaces (factory header, per-run progress, agent ticker) make it unmistakable the factory IS doing something.
**Depends on**: Phase 7
**Requirements**: BLOCK-02, BLOCK-04, INTAKE-01, INTAKE-02, INTAKE-03, OPS-01, OPS-04, OPS-05, UI-07, UI-08, UI-09
**Success Criteria** (what must be TRUE):
  1. An operator can create a new spec draft via (a) freeform text in the editor, (b) markdown file import, or (c) a GitHub issue URL/slug that populates title + body + labels; the draft lands in the inbox.
  2. The inbox view lists drafts with promote / archive / edit actions; a "File as follow-up" button on any shipped run creates a new inbox draft pre-populated with that run's artifacts as context.
  3. The provider health panel shows per-provider status cards (API key present+valid, last successful call, rate-limit headroom from response headers, recent error rate, today's token budget) with RAG indicators; a provider outage turns its card red within one poll cycle.
  4. The cost intelligence view shows per-run/per-workflow/per-agent/per-provider spend with daily/weekly/monthly pivots and at least one advisory callout ("You're spending $X/week on Opus for the Coder role; `phoenix_saas_feature_budget` profile would cost $Y").
  5. A one-click "Bundle last 60 minutes" button produces a secrets-redacted zip containing runs, configs, and logs — operator can share for support/debugging.
  6. When a run blocks, the unblock panel surfaces: what happened (typed reason), what to do (exact commands/config changes from remediation playbook), and "I fixed it — retry" which resumes from last checkpoint. Panels are scannable at a glance.
  7. A fresh clone with no API keys lands the operator in the first-run onboarding wizard; the wizard walks through Anthropic API key, optional OpenAI/Google/Ollama, GitHub auth (`gh auth status`), and Docker prerequisites; no run can start until the wizard passes.
  8. The global factory header is visible on every page showing active-runs count, blocked-runs count with color/badge, spend today, and provider-health summary lights; clicking any element navigates to the relevant detail.
  9. A run board card and run detail header both show a progress indicator (stages done / total, elapsed, estimated remaining from historical percentiles, "last activity" timestamp with green/amber/red staleness ramp).
  10. The agent activity ticker on the home page live-updates a rolling feed across all active runs ("Coder completed `lib/foo.ex` — 430 tokens, $0.013", "Verifier running 12 scenarios") so it is unmistakable the factory IS doing something.
**Phase artifacts**: `KilnWeb.InboxLive` (+ `INTAKE-01` drafts from freeform / markdown / GitHub issue importer `Kiln.Intents.GitHubIssueImporter`); `Kiln.Intents` context (draft CRUD, "file as follow-up" generator); `KilnWeb.ProviderHealthLive` (polls `Kiln.ModelRegistry` + adapter health probes); `KilnWeb.CostIntelLive` (advisor rules over telemetry); `Kiln.Diagnostics.Snapshot` (redactor + zipper); `KilnWeb.UnblockPanelComponent` (rendered in `RunDetailLive` when state is `blocked`); `KilnWeb.OnboardingLive` (wizard with gate check, runs once on empty state); `KilnWeb.Components.FactoryHeader`, `KilnWeb.Components.RunProgress`, `KilnWeb.Components.AgentTicker`; PubSub topic `"agent_ticker"` (rate-limited fan-out).
**Pitfalls addressed**: P16 (ticker + header PubSub topic cardinality bounded), P18 (onboarding/unblock actions all auth-checked), P6 (onboarding's `gh auth status` catches mock-vs-real auth drift at first-run time).
**Research flag**: standard (LiveView + PubSub + forms patterns established). Optional: onboarding UX prototype (wizard flow vs checklist flow) — lightweight decision.
**Plans**: TBD
**UI hint**: yes

### Phase 9: Dogfood & Release (v0.1.0)
**Goal**: Kiln builds Kiln on a real small spec end-to-end, validating every v1 requirement in concert; OTel span coverage is complete; README walks a fresh clone to first-run; v0.1.0 is tagged.
**Depends on**: Phase 8
**Requirements**: GIT-04, OBS-02, LOCAL-03
**Success Criteria** (what must be TRUE):
  1. A real small spec (e.g., "add a `Kiln.Version` module returning the release version string, with tests") is written in the Kiln UI, runs through the full loop (plan -> code -> test -> verify -> commit -> push), produces a PR on `github.com/szTheory/kiln`, passes Kiln's own CI (`mix check`), and merges with zero human intervention beyond the initial spec write.
  2. Kiln's own GitHub Actions workflow runs `mix check` (mix test, credo, dialyzer, xref, sobelow, mix_audit) on every push and PR; a CI-green badge is on the README.
  3. An OpenTelemetry trace of the dogfood run shows spans per stage, per agent call, per Docker op, and per LLM call, with `trace_id` correlated across Oban job boundaries via `opentelemetry_process_propagator`; visiting a trace backend (Jaeger/Honeycomb) renders the full span tree.
  4. A second machine clones the repo, follows only the README, runs `docker compose up`, completes the onboarding wizard, and starts its own first run — the walkthrough is validated against a fresh clone with no tribal knowledge required.
  5. `v0.1.0` is tagged on the `main` branch with a release notes CHANGELOG entry listing every v1 requirement as shipped + validated.
**Phase artifacts**: `.github/workflows/ci.yml` (Kiln's own CI); full `opentelemetry_phoenix|bandit|ecto|oban` wiring; README.md with screenshots from the dogfood run; CHANGELOG.md; `mix check` alias finalized; release notes; v0.1.0 git tag.
**Pitfalls addressed**: P17 (OTel context propagation validated end-to-end); validation that no HIGH-cost pitfall surfaces in a real run (treated as release-blocking).
**Research flag**: standard (polish + docs). Verify OTel metric/log SDK status in Erlang (still marked *development* April 2026 per STACK research — recheck before wiring metrics).
**Plans**: TBD

## Coverage

All 55 v1 requirements mapped to exactly one phase. No orphans, no duplicates.

| Phase | Requirement Count | Requirements |
|-------|-------------------|--------------|
| 1 | 4 | LOCAL-01, LOCAL-02, OBS-01, OBS-03 |
| 2 | 5 | ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07 |
| 3 | 12 | AGENT-01, AGENT-02, AGENT-05, SAND-01, SAND-02, SAND-03, SAND-04, SEC-01, BLOCK-01, BLOCK-03, OPS-02, OPS-03 |
| 4 | 2 | AGENT-03, AGENT-04 |
| 5 | 9 | SPEC-01, SPEC-02, SPEC-03, SPEC-04, ORCH-05, ORCH-06, OBS-04, UAT-01, UAT-02 |
| 6 | 3 | GIT-01, GIT-02, GIT-03 |
| 7 | 6 | UI-01, UI-02, UI-03, UI-04, UI-05, UI-06 |
| 8 | 11 | BLOCK-02, BLOCK-04, INTAKE-01, INTAKE-02, INTAKE-03, OPS-01, OPS-04, OPS-05, UI-07, UI-08, UI-09 |
| 9 | 3 | GIT-04, OBS-02, LOCAL-03 |
| **Total** | **55** | |

## Cross-Cutting Invariants

Three themes cross every phase and must survive each transition — they are not owned by a single phase but all phases write through them:

- **Zero-human-QA (UAT-01/UAT-02).** Primary home is Phase 5 (scenario runner as sole oracle), but enforcement is cross-cutting: Phase 1 CI wires `mix check`, Phase 2 rejects non-scenario-backed workflows, Phase 3's typed block reasons ensure human touchpoints are on the short list, Phase 5 closes the loop semantically, Phase 8 onboarding ensures no manual-QA UX creeps in. Any code-path success criterion that auto-blocks for human review is a Kiln bug.
- **Typed-block contract (BLOCK-01..04).** Block reasons (Phase 3), unblock panel (Phase 8), notifications (Phase 3), onboarding wizard (Phase 8). Humans interact with Kiln only via this typed surface; freeform chat as an unblock mechanism is an anti-feature.
- **Adaptive model routing + recorded `actual_model_used` (OPS-02).** Lives in Phase 3's `Kiln.ModelRegistry` but every downstream phase (cost dashboard Phase 7, cost intel Phase 8, dogfood validation Phase 9) depends on `actual_model_used` being present on every agent-call record, so silent fallback cannot hide.

## Five HIGH-Cost Pitfalls — Architectural Invariants from Phase 1

These are NOT features; they are invariants engineered into the system from the durability floor onward. They are never retrofitted:

| Pitfall | Primary Invariant | Phase Seeded | Phase Validated |
|---------|-------------------|--------------|-----------------|
| P2 Cost runaway | Per-call `BudgetGuard` check before every LLM call; per-run + global circuit breaker | P1 (hook point), P3 (per-call), P5 (run caps) | P3 test + P5 test + P9 dogfood |
| P3 Idempotency violations | `external_operations` intent table + two-phase intent->action->completion + Oban unique insert + `git ls-remote` precondition | P1 (table), P2 (wrapper), P6 (git) | P2 test (kill mid-stage) + P6 test (kill mid-push) |
| P5 Sandbox escape | No Docker socket mount, egress blocked at Docker network layer, `--cap-drop=ALL`, resource limits, negative tests | P1 (compose skeleton), P3 (full sandbox) | P3 negative test suite + P9 dogfood |
| P8 Prompt injection | Typed tool-call allowlist (no raw `run_shell`), untrusted-content markers, egress firewall as backstop, rate-limited tool calls | P3 (groundwork), P4 (per-agent enforcement) | P3 + P4 + P9 |
| P21 Secrets in sandbox | Secret references only (`persistent_term`), `@derive {Inspect, except: [:api_key]}`, never in env, short-lived creds | P1 (pattern), P3 (full) | P3 test + P9 `docker inspect` |

## Research Flags Summary

Phases needing `/gsd-research-phase` before planning:

| Phase | Flag | What Needs Research |
|-------|------|---------------------|
| 2 | moderate | Workflow YAML schema design; Oban queue taxonomy; workflow signing defer-or-now |
| 3 | **HIGH** | DTU mock generation pipeline; SSE->PubSub->LV backpressure; sandbox resource-limit values; structured-output per provider |
| 4 | **HIGH** | Beads-equivalent compaction/ready-queue/claim-atomicity; agent handoff protocol |
| 5 | **HIGH** | Bounded-autonomy cap semantics (what is a "step"? cap interactions?); holdout access-control enforcement |
| 1, 6, 7, 8, 9 | standard | Patterns established |

## Progress

**Execution Order:** 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Durability Floor | 0/TBD | Not started | - |
| 2. Workflow Engine Core | 0/TBD | Not started | - |
| 3. Agent Adapter, Sandbox, DTU & Safety | 0/TBD | Not started | - |
| 4. Agent Tree & Shared Memory | 0/TBD | Not started | - |
| 5. Spec, Verification & Bounded Loop | 0/TBD | Not started | - |
| 6. GitHub Integration | 0/TBD | Not started | - |
| 7. Core Run UI (LiveView) | 0/TBD | Not started | - |
| 8. Operator UX (Intake, Ops, Unblock, Onboarding) | 0/TBD | Not started | - |
| 9. Dogfood & Release (v0.1.0) | 0/TBD | Not started | - |

---
*Roadmap created: 2026-04-18*
*Phases derived from 55 v1 requirements + research convergence (FEATURES dependency graph + ARCHITECTURE context DAG + PITFALLS recovery-cost ordering)*
