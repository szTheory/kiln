# Architecture Research

**Domain:** Elixir/Phoenix LiveView dark software factory (multi-agent LLM orchestrator)
**Researched:** 2026-04-18
**Confidence:** HIGH (stack decisions are locked; patterns validated against current Elixir 1.18/OTP 27/Phoenix 1.8/LiveView 1.1/Oban 2.21 docs and idiomatic guidance)

---

## 1. Executive Summary

Kiln is a four-layer system — **Intent**, **Workflow**, **Execution**, **Control** — implemented as a **single Phoenix 1.8 application** (not an umbrella) with strict internal bounded contexts. The BEAM substrate maps unusually well onto the dark-factory problem: each run is a supervised process tree, each agent is a crash-isolated process, PubSub is the live update backbone, and Postgres + Oban are the durable floor beneath the transient OTP state.

The architecture resolves around a single non-negotiable invariant: **Postgres is the source of truth for run state; OTP processes are transient accelerators that hydrate from it.** If every BEAM node died right now, a fresh boot must pick up every in-flight run from Postgres and Oban and continue from the last checkpoint without human intervention.

---

## 2. The Four-Layer Model → Elixir Mapping

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                       LAYER 1 — INTENT (what to build)                        │
│   Contexts: Kiln.Specs, Kiln.Intents                                          │
│   Owns: Spec markdown + BDD scenarios, Intent records, Workflow selection     │
│   UI:    KilnWeb.SpecLive, KilnWeb.IntentLive                                 │
└──────────────────────────────────┬────────────────────────────────────────────┘
                                   │  create_run(intent, workflow_id)
                                   ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                   LAYER 2 — WORKFLOW (deterministic plan)                     │
│   Contexts: Kiln.Workflows                                                    │
│   Owns: YAML/JSON DAG loader, Stage graph, Version registry, Schema validate  │
│   UI:    KilnWeb.WorkflowLive (read-only)                                     │
└──────────────────────────────────┬────────────────────────────────────────────┘
                                   │  compile(workflow) → stage_plan
                                   ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                     LAYER 3 — EXECUTION (agents do work)                      │
│   Contexts: Kiln.Runs, Kiln.Stages, Kiln.Agents, Kiln.Sandboxes, Kiln.GitHub  │
│   Owns: Run supervisor tree, Stage runners, Agent invocations, Docker ctrl    │
│   OTP:   Run.Supervisor → Stage.Worker → Agent.Session                        │
│   UI:    KilnWeb.RunBoardLive, KilnWeb.RunDetailLive                          │
└──────────────────────────────────┬────────────────────────────────────────────┘
                                   │  emit_event(event), append_audit(...)
                                   ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                     LAYER 4 — CONTROL (policy + observability)                │
│   Contexts: Kiln.Audit, Kiln.Telemetry, Kiln.Policies                         │
│   Owns: Append-only event ledger, Correlation IDs, Budget caps, Stuck-detect  │
│   UI:    KilnWeb.AuditLive, KilnWeb.DashboardLive (LiveDashboard page)        │
└───────────────────────────────────────────────────────────────────────────────┘
```

**Key property:** Layer 3 writes to Layer 4 on every state change. Layer 4 never mutates Layers 1–3; it only observes and constrains them (via policy queries that the execution layer consults).

---

## 3. Top-Level Shape: Single Phoenix App (NOT Umbrella)

**Decision: one Phoenix app, `kiln`, with strict context boundaries.**

Phoenix's official generators and the community case studies treat umbrellas as the answer when you have multiple deployable OTP apps, separate releases, or genuinely distinct subsystems. Kiln has none of those: it is one release, one operator, one dashboard, one Postgres, one Docker host. Contexts solve the boundary problem for solo-engineer scope; umbrellas add compile complexity (cross-app xref, split deps, duplicate config) without any boundary you couldn't get from a well-designed `lib/kiln/*` layout.

| Criterion | Single App | Umbrella | Winner |
|-----------|-----------|----------|--------|
| Boundary enforcement | Contexts + `mix xref` + Boundary lib | Compile-level app boundaries | Umbrella (slight) |
| Release complexity | 1 release | N releases, coordinated | Single |
| Config sharing | `config/runtime.exs` once | Cross-app config gymnastics | Single |
| Dep management | `mix.exs` once | Per-app + root | Single |
| Refactoring cost | Move files within app | Move files across apps | Single |
| Dogfooding "Kiln builds Kiln" | Simple | Kiln must understand umbrella layout | Single |
| Solo-engineer cognitive load | Low | Medium-high | Single |

**Enforce boundaries without umbrella via:**
1. `mix xref graph --format cycles` run in CI; fail on any cycle
2. Optionally `boundary` hex package for declarative cross-context call restrictions
3. Code review rule: `Kiln.<ContextA>` may only call `Kiln.<ContextB>`'s documented public API (defined in `Kiln.ContextB` module; internals live in `Kiln.ContextB.*` submodules)

---

## 4. Context / Bounded-Context Layout

Twelve contexts, grouped by the four-layer model. Each context: what it owns, public API surface, primary Ecto schemas, primary OTP processes.

### Layer 1 — Intent

#### `Kiln.Specs`
**Owns:** Spec documents (markdown + embedded BDD scenarios), scenario parsing, spec versioning.
**Public API:** `create_spec/1`, `update_spec/2`, `get_spec/1`, `parse_scenarios/1`, `list_specs/0`
**Schemas:** `Kiln.Specs.Spec`, `Kiln.Specs.Scenario` (embedded)
**Processes:** None. Pure functions over DB rows.

#### `Kiln.Intents`
**Owns:** The bridge between a spec and a run. An intent = "run this spec with this workflow under these caps."
**Public API:** `create_intent/1`, `kick_off_run/1`
**Schemas:** `Kiln.Intents.Intent` (spec_id, workflow_id, workflow_version, caps: %{max_retries, max_tokens, max_seconds}, operator_actor_id)
**Processes:** None.

### Layer 2 — Workflow

#### `Kiln.Workflows`
**Owns:** YAML/JSON workflow loading from `priv/workflows/*.yaml`, schema validation, graph compilation (topological sort, cycle detection, dependency resolution), version registry.
**Public API:** `load_workflow/1`, `compile/1`, `list_workflows/0`, `get_workflow/2` (id + version)
**Schemas:** `Kiln.Workflows.Workflow` (id, version, yaml_source, compiled_graph_json, checksum), `Kiln.Workflows.Stage` (embedded: id, agent_role, depends_on, retry_policy, timeout)
**Processes:** Optionally `Kiln.Workflows.Registry` (ETS-backed cache of compiled graphs, built lazily on first load; `:read_concurrency` on hot-read path, rebuild from DB on miss).

### Layer 3 — Execution

#### `Kiln.Runs`
**Owns:** Run lifecycle, state machine, checkpointing, resume-on-boot.
**Public API:** `start_run/1`, `get_run/1`, `list_runs/1` (filter), `transition/2`, `escalate/2`, `abort/1`, `resume_after_crash/0`
**Schemas:** `Kiln.Runs.Run` (id, spec_id, workflow_id, workflow_version, state, current_stage_id, caps, tokens_used, retries_used, started_at, finished_at, escalation_reason, correlation_id), `Kiln.Runs.Checkpoint` (run_id, stage_id, artifact_ref, events_up_to, created_at)
**Processes:** `Kiln.Runs.RunSupervisor` (DynamicSupervisor, one child per live run), `Kiln.Runs.Run.Server` (GenServer holding transient run cache + coordinating stage execution).

#### `Kiln.Stages`
**Owns:** Stage execution — the handful-of-steps unit between checkpoints. Wraps an Oban job that invokes an agent inside a sandbox.
**Public API:** `run_stage/2`, `retry_stage/1`, `get_stage_run/1`
**Schemas:** `Kiln.Stages.StageRun` (id, run_id, stage_id, state, started_at, finished_at, attempt, oban_job_id, sandbox_id, artifact_ref, diagnostic)
**Processes:** Per-stage execution is an **Oban job** (durable, retriable, crash-safe) that is supervised by an ephemeral `Kiln.Stages.Executor` task inside the run's supervisor tree. Oban is the durability layer; the task is the live process the run's GenServer monitors.

#### `Kiln.Agents`
**Owns:** Agent registry (Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor), provider-agnostic LLM adapter behaviour, prompt bundle resolution, per-role model selection.
**Public API:** `invoke/2` (agent_role, payload), `record_usage/2`, `list_agent_sessions/1`
**Schemas:** `Kiln.Agents.AgentSession` (id, run_id, stage_run_id, role, provider, model_requested, model_actual, tokens_in, tokens_out, cost_cents, started_at, finished_at)
**Behaviour:** `Kiln.Agents.LLM` with `@callback invoke(prompt, opts) :: {:ok, response} | {:error, reason}`; implementations `Kiln.Agents.LLM.Anthropic`, `.OpenAI`, `.Google`, `.Ollama`.
**Processes:** `Kiln.Agents.SessionSupervisor` (DynamicSupervisor per run; children are short-lived `Kiln.Agents.Session` GenServers that own a single agent invocation — stream tokens, enforce budget, emit telemetry). Sessions are crash-isolated: a misbehaving agent dies without killing its stage, its retry is a fresh session.

#### `Kiln.Sandboxes`
**Owns:** Docker lifecycle (create, start, mount workspace, enforce network policy, capture diff, cleanup). Digital Twin Universe (DTU) mock server management.
**Public API:** `create_sandbox/1`, `exec/2`, `capture_diff/1`, `destroy_sandbox/1`, `start_dtu/1`, `stop_dtu/1`
**Schemas:** `Kiln.Sandboxes.Sandbox` (id, run_id, stage_run_id, container_id, workspace_path, network_policy, state, created_at, destroyed_at)
**Processes:** `Kiln.Sandboxes.Supervisor` (DynamicSupervisor), `Kiln.Sandboxes.Controller` (GenServer per sandbox; owns the container's lifecycle, writes events on state change), `Kiln.Sandboxes.DTU.Supervisor` (long-lived mock HTTP servers on known ports).

#### `Kiln.GitHub`
**Owns:** `git` and `gh` shell invocations (commit, push, open PR, read/update Actions status). All idempotency-keyed.
**Public API:** `commit/2`, `push/2`, `open_pr/2`, `get_pr_status/1`
**Schemas:** `Kiln.GitHub.Operation` (id, idempotency_key, kind, run_id, payload, state, result, retries, created_at) — acts as the dedupe table.
**Processes:** `Kiln.GitHub.Worker` is an Oban worker (not a GenServer); state lives in Oban+Postgres.

### Layer 4 — Control

#### `Kiln.Audit`
**Owns:** Append-only event ledger. Time-travel queries. Correlation-ID threading.
**Public API:** `append/1`, `list_events/1` (filter by run_id, actor, event_type, time range), `replay_run/1` (materialize read model from events)
**Schemas:** `Kiln.Audit.Event` (see §9 schema definition)
**Processes:** None. Inserts are synchronous in the caller's transaction where possible; async fallback via Oban when caller is in a non-transactional context.

#### `Kiln.Telemetry`
**Owns:** `:telemetry` event handlers, OpenTelemetry span propagation, correlation-ID helpers, structured logging metadata.
**Public API:** `span/3`, `span_async/3`, `current_correlation_id/0`, `with_correlation_id/2`
**Schemas:** None. Persisted traces go to OTel collector; metrics flow to Prometheus/LiveDashboard.
**Processes:** `Kiln.Telemetry.Reporter` (supervised GenServer/telemetry poller).

#### `Kiln.Policies`
**Owns:** Bounded-autonomy enforcement. "May this run spend more tokens?" "May this stage retry again?" "Should we escalate for stuck-run?"
**Public API:** `check_cap/2`, `check_stuck/1`, `should_escalate?/2`
**Schemas:** `Kiln.Policies.Cap` (run_id, kind, limit, consumed, remaining) — materialized view / cached aggregate.
**Processes:** `Kiln.Policies.StuckDetector` (GenServer, periodic tick; configurable interval from runtime config).

### Dependency Graph (strict DAG, no cycles)

```
Kiln.Intents  →  Kiln.Specs
Kiln.Intents  →  Kiln.Workflows
Kiln.Runs     →  Kiln.Workflows, Kiln.Intents, Kiln.Policies, Kiln.Audit, Kiln.Telemetry
Kiln.Stages   →  Kiln.Runs, Kiln.Agents, Kiln.Sandboxes, Kiln.Policies, Kiln.Audit, Kiln.Telemetry
Kiln.Agents   →  Kiln.Policies, Kiln.Audit, Kiln.Telemetry
Kiln.Sandboxes→  Kiln.Audit, Kiln.Telemetry
Kiln.GitHub   →  Kiln.Sandboxes, Kiln.Audit, Kiln.Telemetry
Kiln.Audit    →  (nothing — leaf)
Kiln.Telemetry→  (nothing — leaf)
Kiln.Policies →  Kiln.Audit (read-only)
```

Layer 4 leaves (`Audit`, `Telemetry`) are leaves. Layer 3 depends on Layer 2 depends on Layer 1. Every context must be addable to `mix xref` without creating a cycle.

---

## 5. OTP Supervision Tree

### The Full Tree

```
Kiln.Application  (strategy: :one_for_one)
│
├── KilnWeb.Telemetry                         (:permanent, supervisor)
│     └── Kiln.Telemetry.Reporter             (:permanent)
│
├── Kiln.Repo                                 (:permanent)
│
├── {Phoenix.PubSub, name: Kiln.PubSub}       (:permanent)
│
├── {DNSCluster, ...}                         (:permanent; optional, for future)
│
├── Kiln.Vault                                (:permanent; secret store wrapper)
│
├── {Registry, keys: :unique, name: Kiln.Runs.Registry,
│             partitions: System.schedulers_online()}    (:permanent)
│   # Each live run registers under {:run, run_id}
│
├── {Registry, keys: :unique, name: Kiln.Agents.Registry,
│             partitions: System.schedulers_online()}    (:permanent)
│   # Each live agent session registers under {:session, session_id}
│
├── {Registry, keys: :unique, name: Kiln.Sandboxes.Registry,
│             partitions: System.schedulers_online()}    (:permanent)
│
├── Kiln.Workflows.RegistryCache              (:permanent; ETS-backed)
│
├── {PartitionSupervisor,
│     child_spec: {Task.Supervisor, []},
│     name: Kiln.TaskSupervisor,
│     partitions: System.schedulers_online()}   (:permanent)
│   # For ephemeral fire-and-forget tasks (diff capture, telemetry emit)
│
├── Kiln.Runs.RunSupervisor                   (:permanent; DynamicSupervisor)
│   │  strategy: :one_for_one; extra_arguments: []
│   │  max_restarts: 0  (we do not auto-restart a run supervisor tree;
│   │                    the RunDirector decides whether to resume)
│   │
│   └── [per-run tree, one child per active run]
│       Kiln.Runs.Run.Supervisor              (:transient)
│       │  strategy: :one_for_all
│       │  (if run coordinator dies, all its children die; RunDirector
│       │   decides to re-hydrate from Postgres)
│       │
│       ├── Kiln.Runs.Run.Server              (:permanent within its parent)
│       │    # GenServer coordinating this run; owns transient state cache
│       │
│       ├── Kiln.Agents.SessionSupervisor     (:permanent; DynamicSupervisor)
│       │    strategy: :one_for_one
│       │    │
│       │    └── Kiln.Agents.Session          (:temporary)
│       │         # One per live agent invocation; crash-isolated.
│       │         # Death of a session does NOT kill the run.
│       │
│       └── Kiln.Sandboxes.Supervisor         (:permanent; DynamicSupervisor)
│            strategy: :one_for_one
│            │
│            └── Kiln.Sandboxes.Controller    (:temporary)
│                 # One per active sandbox; owns its container lifecycle.
│
├── Kiln.Sandboxes.DTU.Supervisor             (:permanent)
│   └── [long-lived mock HTTP servers for GitHub API, etc.]
│
├── Kiln.Policies.StuckDetector               (:permanent; GenServer)
│
├── Kiln.Runs.RunDirector                     (:permanent; GenServer)
│   # On boot: scans runs in non-terminal states, schedules resume.
│   # At runtime: owns start_run → starts child under RunSupervisor.
│
├── {Oban, Application.fetch_env!(:kiln, Oban)}  (:permanent)
│   # Oban queues: :stages, :github, :audit_async, :dtu
│
└── KilnWeb.Endpoint                          (:permanent)
```

### Restart Strategies — Rationale

| Process | Strategy | Why |
|---------|----------|-----|
| `Kiln.Repo` | `:permanent` | DB loss = app dead. Restart eagerly; fail loud. |
| `Kiln.PubSub` | `:permanent` | UI blind without it. |
| Run coordinator (`Run.Server`) | `:transient` | If it dies abnormally, the per-run supervisor dies (`:one_for_all`), and `RunDirector` re-hydrates from Postgres on next tick. We explicitly do NOT auto-restart under `RunSupervisor` because that risks retry loops consuming budget without policy check. |
| `Agent.Session` | `:temporary` | A hung LLM call should die and be retried *by the stage runner*, not automatically by the supervisor. The stage decides whether to burn a retry. |
| `Sandbox.Controller` | `:temporary` | Same reasoning: a sandbox failure is a stage failure; auto-restart would leak containers. |
| `StuckDetector` | `:permanent` | Must always be watching. |
| `Oban` | `:permanent` | Durability floor. |

### Crash Isolation: How a Misbehaving Agent Dies Without Killing the Run

```
Stage.Worker (Oban job, runs in Oban's own supervised pool)
  │
  │  monitors via Kiln.Agents.Session pid
  ▼
Agent.Session GenServer  ←── crashes, exits with reason :timeout
                             └─ linked to its parent (SessionSupervisor)
                                but SessionSupervisor is :one_for_one with :temporary
                                so Session dies alone.

                         ┌─ Stage.Worker receives {:DOWN, _, :process, pid, :timeout}
                         │
                         ▼
Stage.Worker consults Kiln.Policies.check_cap(run_id, :retries)
  │
  ├─ :ok → enqueue new Oban job, fresh Agent.Session
  └─ :exhausted → Kiln.Runs.escalate(run_id, :retry_cap_exceeded)
```

**Key:** we use `Process.monitor/1` (not `Process.link/1`) between stage runners and agent sessions, because we want stage logic — which is policy-aware — to decide what to do about the crash, not the supervisor.

### Where Oban Fits

Oban is **the durability floor for every step that must survive a node restart**:

| Work Type | Runs In |
|-----------|---------|
| Per-stage execution | Oban worker (`Kiln.Stages.StageWorker`, queue `:stages`) |
| `git commit`, `git push`, `gh pr create` | Oban worker (queue `:github`), idempotency keys enforced at insert + handler |
| Async audit event writes (when we can't do sync) | Oban worker (queue `:audit_async`) |
| DTU health checks, fixture refresh | Oban cron |
| Stage retries, escalations | Scheduled Oban jobs |

Per-run coordination (starting stages, watching progress, pushing UI updates) lives in the **per-run GenServer tree**, which is transient and re-hydrates from Oban + Postgres. The transient tree is a cache over durable state, not a replacement for it.

### Where Per-Run Process Trees Live

Under `Kiln.Runs.RunSupervisor` (a `DynamicSupervisor`). On `Kiln.Runs.start_run/1`:
1. Insert Run row in Postgres (state = `:queued`).
2. `RunDirector` calls `DynamicSupervisor.start_child(RunSupervisor, {Kiln.Runs.Run.Supervisor, run_id: run.id})`.
3. That supervisor starts its three children: `Run.Server`, `Agents.SessionSupervisor`, `Sandboxes.Supervisor`.
4. `Run.Server` reads the compiled workflow, enqueues the first stage's Oban job, subscribes to relevant PubSub topics, and starts driving.

On node boot: `RunDirector` queries `Kiln.Runs.list_active/0` (state IN (`:queued`, `:planning`, `:coding`, `:testing`, `:verifying`)) and calls `resume_after_crash/1` for each, which re-spawns the per-run tree. Because state lives in Postgres and in-flight work lives in Oban, no run is lost.

---

## 6. Run State Machine

### States and Transitions

```
                    ┌──────────┐
                    │  queued  │                ← start_run/1
                    └─────┬────┘
                          │ begin_planning
                          ▼
                    ┌──────────┐
                    │ planning │ ──────┐
                    └─────┬────┘       │
                          │ plan_ready │ planner_failed (after retries)
                          ▼            │
                    ┌──────────┐       │
                    │  coding  │ ──────┤
                    └─────┬────┘       │
                          │ code_ready │ coder_failed (after retries)
                          ▼            │
                    ┌──────────┐       │
                    │ testing  │ ──────┤
                    └─────┬────┘       │
                          │ tests_pass │ tester_failed (after retries)
                          ▼            │
                    ┌──────────┐       │
                    │verifying │       │
                    └─────┬────┘       │
                          │            │
                   ┌──────┴──────┐     │
          pass     │             │  fail
                   ▼             ▼     ▼
               ┌───────┐    ┌──────────┐    (verifier_fail route
               │ merged│    │ planning │ ←── back to planning
               └───────┘    └──────────┘    with diagnostic; consumes retry)
                                │
                                │ (all retry cases also route through
                                │  check_cap; if exhausted → failed or escalated)
                                ▼
                          ┌──────────┐   ┌────────────┐
                          │  failed  │   │ escalated  │
                          └──────────┘   └────────────┘
```

### Transition Matrix

| From | To | Guard | Side Effects |
|------|----|-------|--------------|
| `queued` | `planning` | `start_run/1` called | Spawn run tree, enqueue planner job |
| `planning` | `coding` | plan artifact present, schema-valid | Record checkpoint, broadcast |
| `planning` | `failed` | policy.check_cap = exhausted | Record diagnostic, broadcast |
| `coding` | `testing` | code diff present, syntactically valid | Record checkpoint, broadcast |
| `testing` | `verifying` | all unit tests pass | Record checkpoint, broadcast |
| `verifying` | `merged` | all spec scenarios pass | Run `git push`, PR ops; final broadcast |
| `verifying` | `planning` | spec scenario failed, retries remain | Attach diagnostic, back to planner |
| `*` | `escalated` | stuck-detector fired OR budget cap OR hard fault | Halt, emit diagnostic artifact, notify operator |
| `*` | `failed` | unrecoverable error (DB corruption, container host down) | Record reason, halt |

### Implementation: Ecto State Field Driven by Commands (NOT `:gen_statem`)

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **`:gen_statem`** | Canonical OTP state machine, timeouts built-in, clear pattern for complex FSMs | State lives in process memory — must be re-derived from Postgres on restart; awkward for transactional transitions; two sources of truth (memory + DB) drift risk | **No** for the run-level FSM. Good for sub-state machines that are genuinely short-lived (e.g., agent streaming protocol states), but not for something that must survive a BEAM restart. |
| **Ecto state field + command module** | Single source of truth (the DB row); transitions are transactional; idempotent on replay; trivially queryable ("list all runs in `:verifying`"); matches Phoenix/Ecto idiom | Must hand-write guard logic; no automatic timeout handling (use Oban for that); less "ceremonial" OTP | **Yes.** Recommended. |
| **Third-party lib (Machinery, Fsmx, ExState)** | Declarative DSL, guard/callback hooks | Extra dep; most are thin veneers over an Ecto state field; API lock-in | **No.** Hand-rolled is clearer and has zero dep risk for a greenfield project. |

**Chosen pattern:** `Kiln.Runs.Transitions` is a command module. Every transition function:
1. Opens a Postgres transaction
2. Re-reads the run with `SELECT … FOR UPDATE` (row lock)
3. Asserts the `from` state matches (guard)
4. Updates the `state` field
5. Writes an `Audit.Event` row in the same transaction
6. Commits
7. Broadcasts on `Kiln.PubSub` ("run:#{id}")

Concretely:

```elixir
defmodule Kiln.Runs.Transitions do
  @moduledoc """
  All run state transitions go through this module. Each function is a
  command: transactional, idempotent-on-replay, and guarded.
  """

  @spec begin_planning(run_id :: binary()) :: {:ok, Run.t()} | {:error, term()}
  def begin_planning(run_id) do
    Kiln.Repo.transact(fn ->
      with {:ok, run} <- lock_run(run_id),
           :ok      <- assert_state(run, :queued),
           {:ok, run} <- update_state(run, :planning),
           {:ok, _}   <- Audit.append(%{
             event_type: "run.transition.planning",
             run_id: run.id,
             actor_id: run.operator_actor_id,
             correlation_id: run.correlation_id,
             payload: %{from: :queued, to: :planning}
           }) do
        Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})
        {:ok, run}
      end
    end)
  end
end
```

This pattern gives us: no drift between memory and DB, free replay safety (calling `begin_planning/1` twice is a no-op because the guard fails the second time), and trivial read-model construction for the UI.

---

## 7. Workflow Execution Model

### Loading a YAML DAG

1. On app boot, `Kiln.Workflows.Loader` reads `priv/workflows/*.yaml` and upserts each into `workflows` table (key: `{id, version}` via checksum of source).
2. On `Kiln.Workflows.compile/1`: parse YAML → validate against `Kiln.Workflows.Schema` (ExJsonSchema) → topological sort → detect cycles → materialize a `CompiledGraph` struct (stages, edges, retry policies, per-stage timeouts, per-stage agent role, per-stage model preference).
3. Cache in `Kiln.Workflows.RegistryCache` (ETS, bounded size, LRU eviction). Cache key: `{id, version}`. Cache miss = re-compile from DB row.

### Example YAML Shape

```yaml
id: default-ship-spec
version: 1
description: "Standard spec → plan → code → test → verify → commit → push loop"
caps:
  max_retries: 3
  max_tokens: 500000
  max_seconds: 3600
stages:
  - id: plan
    agent: planner
    model_preference: opus-class
    timeout_seconds: 300
    retry_policy: {max_retries: 2, backoff: exponential}

  - id: code
    agent: coder
    depends_on: [plan]
    model_preference: sonnet-class
    timeout_seconds: 600
    sandbox: required

  - id: test
    agent: tester
    depends_on: [code]
    timeout_seconds: 300
    sandbox: required

  - id: verify
    agent: qa_verifier
    depends_on: [test]
    timeout_seconds: 300
    sandbox: required
    on_fail: {action: route, to: plan, attach: diagnostic}

  - id: commit_push
    agent: coder
    depends_on: [verify]
    timeout_seconds: 120
```

### Stage Dispatch: Oban Job OR Supervised Process — And When

**Every stage is an Oban job.** Period. Stage execution must survive BEAM restart and is allowed to take minutes. Oban is the durability primitive.

But stages spawn **supervised helper processes** inside the job for the live-running concerns:
- `Kiln.Agents.Session` for streaming LLM responses, enforcing per-call budget
- `Kiln.Sandboxes.Controller` for Docker lifecycle

The Oban worker `Kiln.Stages.StageWorker`:
1. Loads `StageRun` from DB (or creates it)
2. Checks policy caps (retries, tokens, elapsed)
3. Starts a `Sandbox.Controller` under the run's SandboxSupervisor (if sandbox required)
4. Starts an `Agent.Session` under the run's SessionSupervisor
5. Monitors both; awaits completion
6. Records artifacts, writes checkpoint, emits events
7. Transitions run state via `Kiln.Runs.Transitions`
8. Enqueues the next stage's Oban job (or escalates)

### Fan-Out / Fan-In / Retries / Checkpoints

**Fan-out:** A stage with multiple dependents triggers N parallel Oban jobs. Each downstream stage's `depends_on` is checked via a "join barrier" pattern: the stage won't start until all `StageRun` rows for its dependencies are in state `:succeeded`. Use Oban's `Oban.Workflow` (2.21+) if you want the framework to manage DAG enforcement; otherwise hand-rolled check at job start is simple and explicit.

**Fan-in:** Same pattern — a stage that depends on N parents polls (via Oban workflow waiting primitive or an explicit check at job execution start) until all parents are complete. We recommend hand-rolled checks for v1 to keep the mental model simple; adopt Oban.Workflow if DAG complexity grows.

**Retries:** Oban's built-in retry is the substrate. Per-stage retry policy (from YAML) overrides Oban defaults. Stage-level retries are bounded by run-level policy (`check_cap(:retries)`).

**Checkpoints:** Written inside the transaction that transitions run state. Artifact blobs (diffs, plans, test output) go to `priv/artifacts/<run_id>/<stage_id>/<attempt>/` (local filesystem for v1) or object storage (deferred). DB row stores the artifact ref, not the blob.

---

## 8. Agent Orchestration (Gastown-Inspired)

### Hierarchy

```
                    Kiln.Agents.Mayor
                    (orchestrator of record;
                     holds high-level run intent;
                     decides routing between roles)
                           │
        ┌──────────┬───────┼───────┬──────────┬───────────┐
        │          │       │       │          │           │
     Planner    Coder   Tester  Reviewer   UI/UX    QA/Verifier
     (spec →    (plan → (code → (PR rev. → (design    (scenarios
      plan)      diff)   tests)  comments)  contract)   → pass/fail)
```

Each role is **a prompt template + a model preference + a tool permission set**, not a separate OTP tree. An "agent" at runtime is a `Kiln.Agents.Session` GenServer configured for a role.

### How They Communicate

**Not** via direct message passing. Direct agent-to-agent messages would make the system opaque to the ledger and brittle to crashes.

Instead:

| Communication Type | Mechanism |
|--------------------|-----------|
| Agent output → next stage input | Postgres artifacts (diff, plan, test output) + `Audit.Event` rows + `StageRun.artifact_ref` |
| Agent → UI live updates | `Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{id}", ...)` |
| Mayor-level routing decisions | Run.Server GenServer calls `Kiln.Workflows.next_stage/2` and enqueues next Oban job |
| "Shared memory" (beads equivalent) | A Postgres table `Kiln.Agents.SharedNote` (run_id, author_role, note_kind, content, correlation_id, created_at). Agents read+write through `Kiln.Agents` context, not via direct process messaging |

### The "Shared Memory" Design (Beads-Equivalent, Native Elixir)

```sql
CREATE TABLE shared_notes (
  id              UUID PRIMARY KEY,
  run_id          UUID NOT NULL REFERENCES runs(id),
  author_role     TEXT NOT NULL,    -- :planner, :coder, :qa_verifier, :mayor
  note_kind       TEXT NOT NULL,    -- :plan, :diagnostic, :design_note, :warning, :observation
  content         JSONB NOT NULL,
  correlation_id  UUID NOT NULL,
  causation_id    UUID,             -- what note/event led to this one
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON shared_notes (run_id, note_kind);
CREATE INDEX ON shared_notes (correlation_id);
```

Every agent invocation includes "read the shared notes table for this run, filtered by kinds relevant to your role" as part of its prompt-building step in `Kiln.Agents.PromptBuilder`. Every agent invocation ends with "write a structured note summarizing what you did/learned" to `shared_notes`. The UI renders shared_notes as "agent chatter" in the run detail view.

This is **append-only**, **queryable**, **replayable**, and **lives in the DB**. No ETS. No process-based shared state. A fresh BEAM boot sees the same "memory" the previous boot did.

---

## 9. Event Ledger & Idempotency

### Event Schema

```elixir
defmodule Kiln.Audit.Event do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: false}

  schema "audit_events" do
    field :event_kind,      Ecto.Enum, values: Kiln.Audit.EventKind.values()
    field :actor_id,        :string
    field :actor_role,      :string
    field :run_id,          :binary_id
    field :stage_id,        :binary_id
    field :correlation_id,  :binary_id, null: false
    field :causation_id,    :binary_id
    field :schema_version,  :integer, default: 1
    field :payload,         :map, default: %{}
    field :occurred_at,     :utc_datetime_usec
    timestamps(updated_at: false)
  end
end
```

```sql
CREATE TABLE audit_events (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  event_kind       TEXT NOT NULL,
  actor_id         TEXT,
  actor_role       TEXT,
  run_id           UUID,
  stage_id         UUID,
  correlation_id   UUID NOT NULL,
  causation_id     UUID,
  schema_version   INTEGER NOT NULL DEFAULT 1,
  payload          JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  inserted_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CHECK constraint enumerates the 22 event kinds per CONTEXT.md D-08.

-- Three-layer INSERT-only enforcement (CONTEXT.md D-12):
--   Layer 1 (role-based; SQLSTATE 42501 when mutated as kiln_app):
REVOKE UPDATE, DELETE, TRUNCATE ON audit_events FROM kiln_app;
GRANT INSERT, SELECT ON audit_events TO kiln_app;

--   Layer 2 (trigger; role-bypass-resistant):
CREATE TRIGGER audit_events_no_update
  BEFORE UPDATE ON audit_events
  FOR EACH ROW EXECUTE FUNCTION audit_events_immutable();
-- (equivalent triggers for DELETE, TRUNCATE)

--   Layer 3 (RULE; final no-op safety net):
CREATE RULE audit_events_no_update_rule AS ON UPDATE TO audit_events DO INSTEAD NOTHING;
CREATE RULE audit_events_no_delete_rule AS ON DELETE TO audit_events DO INSTEAD NOTHING;

-- Five b-tree composite indexes per CONTEXT.md D-10:
CREATE INDEX ON audit_events (run_id, occurred_at DESC) WHERE run_id IS NOT NULL;
CREATE INDEX ON audit_events (stage_id, occurred_at DESC) WHERE stage_id IS NOT NULL;
CREATE INDEX ON audit_events (event_kind, occurred_at DESC);
CREATE INDEX ON audit_events (actor_id, occurred_at DESC);
CREATE INDEX ON audit_events (correlation_id);
```

**Why three-layer enforcement (D-12):** the ledger must be append-only even against well-meaning (or malicious) future developers or accidental migrations. `CREATE RULE` alone has documented silent-bypass modes (its WHERE-clause AND-ing with the query's WHERE can produce `UPDATE 0` on a malformed mutation without raising). For a security-critical audit ledger, silent enforcement failure is the worst possible outcome. Three independent layers provide defense in depth: REVOKE is loud (SQLSTATE 42501), the trigger is role-bypass-resistant, and the RULE is the final no-op safety net. The operator-facing `Kiln.Audit.append/1` is the only sanctioned entry point. See `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` D-12.

### Pattern-Matching on Events for Read Models

```elixir
# Example: build a run timeline view
def run_timeline(run_id) do
  from(e in Event,
       where: e.run_id == ^run_id,
       order_by: [asc: e.occurred_at])
  |> Repo.all()
  |> Enum.map(&classify_event/1)
end

defp classify_event(%{event_kind: :run_state_transitioned, payload: %{"to" => new_state}} = e) do
  {:state_change, new_state, e}
end

defp classify_event(%{event_kind: :stage_started, payload: %{"stage_kind" => stage}} = e) do
  {:stage_start, stage, e}
end

defp classify_event(%{event_kind: :external_op_completed, payload: %{"op_kind" => op}} = e) do
  {:external_op_completed, op, e}
end
```

### Idempotency Enforcement at the Boundary

**Layered defense — Oban unique jobs + handler-level dedupe + idempotency table for external side effects.**

**Layer 1: Oban unique jobs.** Every Oban job has `unique: [period: 60, keys: [:run_id, :stage_id, :attempt], states: [:available, :scheduled, :executing]]`. Prevents accidental duplicate enqueues.

**Layer 2: Handler-level dedupe.** Every Oban worker's `perform/1` begins with: re-read the target row with `SELECT … FOR UPDATE`, assert the expected "from" state, abort if already in "to" state. Pattern: `with {:ok, stage_run} <- Stages.get_for_update(id), :ok <- assert_state(stage_run, :pending) do … else :already_completed -> {:ok, :noop} end`.

**Layer 3: External side effects (git push, API calls).** Every external call has an explicit idempotency key stored in `github_operations` (or similar context-owned table). Before the call, `INSERT … ON CONFLICT DO NOTHING RETURNING *`; if the row already exists with `state = :completed`, return the stored result. If `state = :in_flight`, either wait or fail with `{:error, :already_in_flight}`.

This gives us safety at enqueue time (Oban unique), at execution time (handler guards), and at side-effect time (external idempotency table).

---

## 10. Sandbox Interface: Docker Control

### Options Analyzed

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Shell out to `docker` CLI via `Port`** | Zero dep; easy to debug (just run the command yourself); proven approach in StrongDM-style systems; tolerates `docker` updates | Port lifecycle management (reap on exit); parsing CLI output is fragile; slow-ish (spawning `docker` per call has ms-scale overhead); handling stdout/stderr streams needs care | **Chosen for v1.** Simplest, most debuggable, fewest deps. Fits solo-engineer budget. |
| **HTTP client against Docker Engine API (`hackney`/`req` → `/var/run/docker.sock`)** | Faster; structured JSON responses; streaming logs over WebSocket; no shell parsing; full Docker API surface | Direct socket access = root on host (major security concern); must run app as member of `docker` group; HTTP upgrade dance for attach/logs is non-trivial; still need to handle binary stream demuxing | Deferred. Consider only if CLI latency becomes a bottleneck. |
| **`docker_engine_api_elixir`** (autogenerated OpenAPI client) | Structured schema; type-safe-ish | Autogenerated code, not well-maintained; we'd inherit OpenAPI quirks; still has the socket-exposure security tradeoff | **No.** Not worth the maintenance dependency for v1. |
| **`docker_api` / `hexedpackets/docker-elixir` / similar community libs** | Less autogenerated, more opinionated | Mostly unmaintained; last activity years ago | **No.** |

### The CLI + Port Approach

```elixir
defmodule Kiln.Sandboxes.DockerCLI do
  @moduledoc """
  Thin behaviour-defined wrapper over shell calls to `docker`. Uses `Port`
  with {:spawn_executable, docker_path} for clean process boundaries and
  stream capture.
  """
  @behaviour Kiln.Sandboxes.ContainerRuntime

  @impl true
  def create(opts) do
    args = ["create", "--network", "kiln-sandbox", "--rm=false" | build_args(opts)]
    port_exec("docker", args)
  end

  @impl true
  def exec(container_id, cmd, opts) do
    port_exec("docker", ["exec" | exec_args(container_id, cmd, opts)])
  end

  # ... etc
end
```

### Security: The Docker Socket Is Root Equivalent

**Non-negotiable v1 security measures:**

1. **Kiln runs on the developer's local machine under the developer's user.** No multi-user concerns yet.
2. **Sandbox containers run with `--network kiln-sandbox` (a user-defined bridge).** Egress rules applied via the bridge network's policy. Only the DTU mock server's IP is reachable.
3. **No `--privileged`.** Ever.
4. **No `--volume /var/run/docker.sock:/var/run/docker.sock`.** Containers must not be able to spawn siblings.
5. **`--read-only` root filesystem** for sandbox containers; writable tmpfs mounts for `/tmp` and the workspace dir only.
6. **Non-root user inside container** via `--user`.
7. **Resource caps**: `--memory`, `--cpus`, `--pids-limit`.
8. **Timeout wall**: every exec has an outer wall-clock timeout enforced by the Elixir side.

### Rootless / Firecracker / gVisor — Out of Scope for V1 (Noted)

- **Rootless Docker** would eliminate the "Docker daemon is root" risk. Operational complexity is moderate on macOS (via Docker Desktop's rootless mode); on Linux, requires newuidmap/newgidmap setup. **Add in v1.1** if multi-user becomes a goal.
- **Firecracker** gives hardware-level isolation but requires KVM/Linux and a significantly different control plane. Overkill for solo v1.
- **gVisor (`runsc`)** gives a syscall-level sandbox with less hardware dep; reasonable mid-step if hardened isolation is needed. Deferred.

---

## 11. LiveView Patterns

### Core Pages

| LiveView | Route | Purpose |
|----------|-------|---------|
| `KilnWeb.RunBoardLive` | `/runs` | Kanban-style board, columns by state |
| `KilnWeb.RunDetailLive` | `/runs/:id` | Stage graph, diffs, logs, agent chatter |
| `KilnWeb.WorkflowLive` | `/workflows` & `/workflows/:id` | Registry, read-only YAML viewer |
| `KilnWeb.SpecLive` | `/specs/:id` | Markdown + scenarios editor |
| `KilnWeb.AuditLive` | `/audit` | Filterable event stream |
| `KilnWeb.DashboardLive` | `/dashboard` | Token/cost by run/workflow/agent |

### Streams for the Run Board

The run board may have dozens of historical runs. Keep them out of server memory via `stream/4`:

```elixir
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(Kiln.PubSub, "runs:board")
  {:ok, stream(socket, :runs, Kiln.Runs.list_recent(limit: 50))}
end

def handle_info({:run_state, %Run{} = run}, socket) do
  {:noreply, stream_insert(socket, :runs, run)}
end
```

### Async Assigns for Slow Views

Workflow compilation of a large graph, audit ledger filtered over wide time ranges — use `assign_async/3`:

```elixir
def mount(%{"id" => id}, _session, socket) do
  socket =
    socket
    |> assign(:run_id, id)
    |> assign_async(:stages, fn -> {:ok, %{stages: Kiln.Stages.list_for_run(id)}} end)

  {:ok, socket}
end
```

Never capture the whole socket inside the async function — extract just the needed data first (from Elixir anti-pattern docs).

### PubSub Topics

| Topic | Publishers | Subscribers |
|-------|------------|-------------|
| `"runs:board"` | Every run state transition | RunBoardLive |
| `"run:#{id}"` | State changes, stage updates, agent events for that run | RunDetailLive for that run |
| `"run:#{id}:stage:#{stage_id}"` | Fine-grained per-stage events | RunDetailLive's stage card component |
| `"audit:firehose"` | Every `Audit.append/1` | AuditLive |

### Handling 10+ Concurrent Runs Without Crushing the Browser

- **Streams for the board** (unlimited rows, bounded client memory).
- **Collapsed stage cards by default** on RunDetailLive; expand on click.
- **Event stream throttling**: RunDetailLive batches incoming `handle_info` events on a 100ms tick (via `Process.send_after/3`) before pushing UI updates. No per-event DOM patch storm.
- **Live log viewer uses virtualized scroll** (the client side of streams handles this automatically).
- **Per-run LiveView processes are already isolated** — if one browser tab's RunDetailLive crashes, others are unaffected.
- **Limit PubSub fan-out**: for `"runs:board"`, only broadcast *state transitions*, not every event. The detail view subscribes to `"run:#{id}"` only when the user opens that run.

---

## 12. Telemetry & Observability

### Telemetry Events (Kiln-Specific)

```
[:kiln, :run, :started]          # meta: run_id, correlation_id, workflow_id
[:kiln, :run, :state_changed]    # meta: run_id, from, to, correlation_id
[:kiln, :stage, :started]        # meta: run_id, stage_id, attempt, correlation_id
[:kiln, :stage, :completed]      # meta + measurements: duration_ms
[:kiln, :agent, :invoked]        # meta: role, model, tokens_in, tokens_out, correlation_id
[:kiln, :agent, :cost]           # measurements: cost_cents
[:kiln, :sandbox, :created]      # meta: sandbox_id, run_id
[:kiln, :sandbox, :exec]         # measurements: exit_code, duration_ms
[:kiln, :github, :operation]     # meta: kind, idempotency_key, success
```

Every event carries `correlation_id` in metadata so downstream handlers can thread it.

### OpenTelemetry

- `opentelemetry_phoenix` for request spans (Bandit adapter)
- `opentelemetry_ecto` for query spans (preload chains linked back to initiator)
- `opentelemetry_oban` for job spans
- Custom spans wrapping stage execution, agent invocations, sandbox exec via `OpenTelemetry.Tracer.with_span/2` or Kiln's helper `Kiln.Telemetry.span/3`

Traces are stable in the Erlang SDK; metrics and logs are marked "development" — emit custom metrics via `:telemetry` + `telemetry_metrics_prometheus` instead, for now.

### Correlation ID Propagation Across Process Boundaries

**Chosen pattern: Logger metadata + explicit threading.**

| Mechanism | Pros | Cons | Use Where |
|-----------|------|------|-----------|
| Process dictionary (`Process.put/2`) | Implicit, no API change | Lost on process boundary; hides dependency; considered an anti-pattern for state transport | **Don't use.** |
| Logger metadata | Standard Elixir pattern; survives `Logger.metadata/1` propagation via `Task.async` when properly set; every log line tagged automatically | Must be explicitly copied when spawning processes | **Use** for log enrichment. |
| Explicit threading (passing `correlation_id` in function args, OTel context in ctx map) | Obvious, testable, no magic; dependency is visible | Verbose | **Use** for cross-process control flow. |

**Rule:** any function crossing a process boundary (spawning a Task, enqueuing an Oban job, calling a GenServer) MUST explicitly pass `correlation_id` and (when tracing) the OTel span context. `Kiln.Telemetry.pack_ctx/0` / `unpack_ctx/1` helpers standardize this.

### Propagating OTel Span Context Into an Oban Job

```elixir
# When enqueueing
span_ctx = :otel_tracer.current_span_ctx()
span_hex = :otel_propagator_text_map.encode(span_ctx)

%{run_id: run_id, stage_id: stage_id, otel_ctx: span_hex, correlation_id: cid}
|> Kiln.Stages.StageWorker.new()
|> Oban.insert()

# Inside the worker
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  span_ctx = :otel_propagator_text_map.decode(args["otel_ctx"])
  :otel_tracer.set_current_span(span_ctx)
  Logger.metadata(correlation_id: args["correlation_id"])
  # ... actual work
end
```

---

## 13. Elixir-Specific Anti-Patterns to Avoid

These are called out specifically because the dark-factory + multi-agent pattern tempts each one:

### 13.1 GenServer-as-Code-Organization

**Trap:** "This is a Kiln.Runs.StateKeeper that holds all current run states so we don't have to hit the DB." → Creates a serial bottleneck; all operator queries go through it; drift between in-memory cache and DB truth.

**Fix:** Postgres is truth. ETS cache (if any) is derived. One GenServer per *live process* (one `Run.Server` per active run) is fine because the process has genuine runtime ownership (its current DB transaction context, its Oban job coordination). A singleton GenServer as a cache across all runs is not.

### 13.2 Boolean Obsession in Run State

**Trap:** `run.planning? and run.failed? and run.escalated? and run.can_retry?`. Multiple overlapping booleans = impossible states become representable.

**Fix:** Single `state` enum field (queued/planning/coding/…/merged/failed/escalated). Use Ecto's `:string` with a changeset `validate_inclusion`. Use atoms in code, strings in DB; convert at boundaries.

### 13.3 Event Sourcing Everywhere

**Trap:** "Everything is events — current state is just the left-fold of events." → Explodes DB write volume; replay is slow; CQRS tooling overhead; hard to query "what's the current state of run X."

**Fix:** **Hybrid — current-state tables + append-only audit ledger.** `runs` table has current state; `events` table has the full history. Most queries hit `runs`. Time-travel/replay/debugging queries hit `events`. Full event sourcing only if we later need cross-consumer projections (we don't).

### 13.4 Process-per-Thought Proliferation

**Trap:** "Let's spawn a GenServer per agent invocation to track state" when a plain function + Postgres insert would do.

**Fix:** Only spawn a process when there is genuine runtime concern: owning a streaming socket, coordinating many sub-tasks, isolating a likely crash. A synchronous LLM call that completes in seconds and returns a tuple doesn't need a GenServer. An agent session that streams tokens and may crash mid-stream does.

### 13.5 Capturing Large Terms into Async Closures

**Trap:** `Task.async(fn -> do_work(socket) end)` or `Task.async(fn -> do_work(run_with_all_stages_preloaded) end)`.

**Fix:** Extract only the needed fields first. Always.

### 13.6 Exception-Driven Control Flow

**Trap:** `Repo.get!(Run, run_id)` inside a pipeline, rescued later. Or `raise WorkflowError` to signal stage failure.

**Fix:** `{:ok, run} | {:error, :not_found}` tuples. Use `with` for happy-path composition. Exceptions are for truly exceptional cases (DB down, invariant violation), not stage failures.

### 13.7 Umbrella Apps for Solo Projects

**Trap:** "Let's put `kiln_core`, `kiln_web`, `kiln_agents`, `kiln_sandboxes` into separate apps for 'clean architecture.'" → Cross-app refactor cost is real; `mix xref` + contexts solve the boundary problem at a fraction of the complexity.

**Fix:** Single app, strict contexts, `mix xref` in CI. See §3.

### 13.8 Scattered GenServer API Surface

**Trap:** `GenServer.call(pid, :get_state)` / `GenServer.cast(pid, {:update, …})` called from controllers, LiveViews, Oban workers.

**Fix:** Every GenServer has a module-level public API (`Kiln.Runs.Run.Server.get_state/1`, `update/2`). Callers never call `GenServer.call/cast` directly. Internal protocol is a module implementation detail.

### 13.9 Lazy Association Assumptions

**Trap:** `run.stages |> Enum.map(...)` when `stages` wasn't preloaded, triggering N+1 or a crash on `Ecto.Association.NotLoaded`.

**Fix:** Explicit preloads in context functions. Name returned shapes precisely — `Kiln.Runs.get_run_with_stages/1` vs `get_run/1`.

### 13.10 Live-Running State That Can't Survive a Restart

**Trap:** Tracking "which stages are currently mid-execution" in a GenServer's state map.

**Fix:** Postgres + Oban hold everything durable. The GenServer is a cache hydrated from them. `RunDirector.resume_on_boot/0` rebuilds live trees from the DB on boot.

### 13.11 Blocking the LiveView Process

**Trap:** `def mount/3` does a synchronous call that takes 4 seconds → first paint is 4 seconds delayed → UX is broken.

**Fix:** `assign_async/3` for any load > 50ms. Move to `handle_async/3` for fine control.

### 13.12 Central Registry as Bottleneck

**Trap:** A single `Registry` with no partitions serving every lookup → contention at scale.

**Fix:** `partitions: System.schedulers_online()` on all registries. Already baked into §5 tree.

---

## 14. Scaling Considerations

### Solo V1: 1 user, ≤10 concurrent runs, single box

| Concern | V1 Approach |
|---------|-------------|
| Concurrent runs | DynamicSupervisor handles hundreds trivially; Postgres pool size 10 is ample |
| LiveView load | 1 operator = 1 browser tab = 1 LiveView per page; zero scaling concern |
| Sandbox concurrency | Docker can run 10+ containers on a developer machine; default resource caps prevent crush |
| DB connections | `pool_size: 10` default; Oban's default queue workers (stages: 2, github: 1) keep contention low |

### What Breaks First If It Grows

1. **Single Docker host capacity.** At ~20 concurrent sandboxes, a developer laptop thrashes. **Fix:** move sandboxes to a dedicated remote host (still Docker), kept behind a behaviour so the code path doesn't change.

2. **Oban queue saturation.** Default queue workers = low concurrency by design. **Fix:** raise queue concurrency; add more queues per role (plan_queue, code_queue, test_queue) so one slow stage type doesn't block others.

3. **Postgres connection pool.** At ~50 concurrent runs all hammering the DB, default pool_size of 10 becomes `queue_time` dominant. **Fix:** monitor `queue_time` telemetry (Ecto emits it); raise pool_size only when data says to.

4. **LiveView per-tab state for the run board.** At 1000+ historical runs, the stream works fine on client but server mount time grows if preloading stage summaries. **Fix:** server-side pagination on the Runs query in `mount/3`; use `handle_params/3` for page navigation via URL.

5. **Single-node BEAM.** Never a problem for solo use. Adding a second node introduces Phoenix.PubSub topology, Oban global peer coordination (already supported in 2.21+), and the need for `dns_cluster`.

### Path to Multi-Tenant (Deferred, Documented)

When multi-tenant becomes a goal:
1. Add `tenant_id` column to every user-scoped table (runs, specs, workflows, agent_sessions, events).
2. Make `current_scope` a first-class arg to every context function: `Kiln.Runs.start_run(scope, intent)`.
3. Use Ecto's `prepare_query/3` repo hook to auto-filter by `tenant_id` when `scope` is attached to the process Logger metadata.
4. Add auth layer (`mix phx.gen.auth` as starting point, customized).
5. Introduce per-tenant resource caps in `Kiln.Policies`.

None of the data model above precludes this; it's additive.

---

## 15. Project Directory Structure

```
kiln/
├── .formatter.exs
├── .tool-versions              # asdf: Elixir 1.18, OTP 27
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml              # mix test, credo, xref, dialyzer-optional
│       └── release.yml         # (future)
├── docker/
│   ├── Dockerfile.kiln         # Release-based, Debian-slim base (not Alpine — DNS issues)
│   ├── Dockerfile.sandbox      # Base image for per-stage sandboxes
│   └── compose.yml             # kiln + postgres + dtu mocks
├── README.md
├── CHANGELOG.md
├── mix.exs
├── mix.lock
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   ├── prod.exs
│   └── runtime.exs             # All env-derived config
├── priv/
│   ├── static/                 # Compiled JS/CSS assets
│   ├── repo/
│   │   ├── migrations/
│   │   └── seeds.exs
│   ├── workflows/              # YAML/JSON workflow definitions
│   │   ├── default_ship_spec.yaml
│   │   ├── dogfood_kiln_self.yaml
│   │   └── schema.json         # JSON-schema for validation
│   ├── mocks/                  # DTU (Digital Twin Universe) fixtures
│   │   ├── github/
│   │   │   ├── openapi.json
│   │   │   └── fixtures/
│   │   └── npm_registry/
│   ├── artifacts/              # Per-run stage artifacts (gitignored)
│   │   └── .gitkeep
│   └── brand/                  # Brand book assets (Kiln coal palette, Inter, IBM Plex Mono)
├── lib/
│   ├── kiln.ex                 # App facade (rarely used; contexts preferred)
│   ├── kiln/
│   │   ├── application.ex      # Supervision tree root
│   │   ├── repo.ex
│   │   ├── release.ex          # Release tasks: migrate, rollback, seed
│   │   │
│   │   ├── specs/
│   │   │   ├── spec.ex         # Ecto schema
│   │   │   ├── scenario.ex     # Embedded schema
│   │   │   └── parser.ex
│   │   ├── specs.ex            # Kiln.Specs — public API
│   │   │
│   │   ├── intents/
│   │   │   └── intent.ex
│   │   ├── intents.ex
│   │   │
│   │   ├── workflows/
│   │   │   ├── workflow.ex
│   │   │   ├── stage.ex
│   │   │   ├── schema.ex       # JSON-schema loader
│   │   │   ├── loader.ex       # priv/workflows/*.yaml → DB
│   │   │   ├── compiler.ex     # DAG compilation + cycle detection
│   │   │   └── registry_cache.ex  # ETS cache
│   │   ├── workflows.ex
│   │   │
│   │   ├── runs/
│   │   │   ├── run.ex
│   │   │   ├── checkpoint.ex
│   │   │   ├── transitions.ex  # Command module for state machine
│   │   │   ├── run_director.ex # Top-level GenServer
│   │   │   ├── run_supervisor.ex  # DynamicSupervisor
│   │   │   └── run/
│   │   │       ├── supervisor.ex   # Per-run supervisor
│   │   │       └── server.ex       # Per-run coordinator GenServer
│   │   ├── runs.ex
│   │   │
│   │   ├── stages/
│   │   │   ├── stage_run.ex
│   │   │   └── stage_worker.ex   # Oban worker
│   │   ├── stages.ex
│   │   │
│   │   ├── agents/
│   │   │   ├── agent_session.ex
│   │   │   ├── shared_note.ex
│   │   │   ├── llm.ex           # Behaviour
│   │   │   ├── llm/
│   │   │   │   ├── anthropic.ex
│   │   │   │   ├── openai.ex
│   │   │   │   ├── google.ex
│   │   │   │   └── ollama.ex
│   │   │   ├── prompt_builder.ex
│   │   │   ├── session_supervisor.ex  # DynamicSupervisor
│   │   │   └── session.ex       # GenServer per invocation
│   │   ├── agents.ex
│   │   │
│   │   ├── sandboxes/
│   │   │   ├── sandbox.ex
│   │   │   ├── container_runtime.ex  # Behaviour
│   │   │   ├── docker_cli.ex    # Impl via Port
│   │   │   ├── supervisor.ex
│   │   │   ├── controller.ex
│   │   │   └── dtu/
│   │   │       ├── supervisor.ex
│   │   │       ├── github_mock.ex
│   │   │       └── network_policy.ex
│   │   ├── sandboxes.ex
│   │   │
│   │   ├── github/
│   │   │   ├── operation.ex
│   │   │   ├── worker.ex        # Oban worker
│   │   │   └── shell.ex         # git/gh port wrappers
│   │   ├── github.ex
│   │   │
│   │   ├── audit/
│   │   │   └── event.ex
│   │   ├── audit.ex
│   │   │
│   │   ├── telemetry/
│   │   │   ├── reporter.ex
│   │   │   └── correlation.ex
│   │   ├── telemetry.ex
│   │   │
│   │   ├── policies/
│   │   │   ├── cap.ex
│   │   │   └── stuck_detector.ex
│   │   └── policies.ex
│   │
│   └── kiln_web/
│       ├── endpoint.ex
│       ├── router.ex
│       ├── telemetry.ex
│       ├── components/
│       │   ├── core_components.ex   # Phoenix-generated
│       │   ├── run_card.ex
│       │   ├── stage_card.ex
│       │   ├── agent_chatter.ex
│       │   ├── diff_viewer.ex
│       │   └── brand.ex             # Kiln brand components
│       ├── layouts/
│       ├── live/
│       │   ├── run_board_live.ex
│       │   ├── run_detail_live.ex
│       │   ├── workflow_live.ex
│       │   ├── spec_live.ex
│       │   ├── audit_live.ex
│       │   └── dashboard_live.ex
│       └── plugs/
│           └── request_id.ex    # Already provided by Plug; wrapped for Kiln
├── test/
│   ├── test_helper.exs
│   ├── support/
│   │   ├── conn_case.ex
│   │   ├── data_case.ex
│   │   ├── fixtures/
│   │   │   ├── spec_fixtures.ex
│   │   │   └── workflow_fixtures.ex
│   │   └── mocks.ex             # Mox-based behaviour mocks
│   ├── kiln/
│   │   ├── specs_test.exs
│   │   ├── runs_test.exs
│   │   ├── runs/
│   │   │   └── transitions_test.exs
│   │   ├── stages_test.exs
│   │   ├── agents_test.exs
│   │   ├── sandboxes_test.exs
│   │   └── workflows_test.exs
│   └── kiln_web/
│       ├── live/
│       │   ├── run_board_live_test.exs
│       │   └── run_detail_live_test.exs
│       └── controllers/
└── assets/                     # Phoenix 1.8 asset layout
    ├── css/
    ├── js/
    └── vendor/
```

### Structure Rationale

- **`lib/kiln/` (contexts) vs `lib/kiln_web/` (UI):** standard Phoenix split. Business logic in contexts. LiveViews and components call contexts; contexts never know about Plug conns or sockets.
- **`lib/kiln/<context>.ex` is the public API; `lib/kiln/<context>/` holds implementation.** This is the pattern `mix phx.gen.context` produces and that Phoenix docs endorse.
- **`priv/workflows/` and `priv/mocks/`** live in `priv/` because they must ship with the release. Workflows are user-editable via git; mocks are Kiln-maintained fixtures.
- **`priv/artifacts/`** is gitignored; this is per-run output (diffs, logs). Production path would be object storage behind a behaviour; v1 is local filesystem.
- **`docker/compose.yml`** (not `docker-compose.yml`) per current Docker conventions. Separate Dockerfile for the app release vs the sandbox base image.
- **`test/support/` + `test/kiln/` + `test/kiln_web/`** mirrors `lib/` for discoverability. `support/mocks.ex` houses Mox-based behaviour mocks (no ad-hoc mocking).

---

## 16. Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Anthropic API | `Kiln.Agents.LLM.Anthropic` implementing `Kiln.Agents.LLM` behaviour; HTTP via `Req` | Streaming response parsing; per-call timeout; cost calc on stream close |
| OpenAI / Google / Ollama | Same behaviour, separate impls | Swap-in for model-preference routing |
| Docker daemon | `Kiln.Sandboxes.DockerCLI` via `Port` | See §10 |
| GitHub (via `gh` CLI) | `Kiln.GitHub.Shell` via `Port`; all ops idempotency-keyed | Avoids maintaining a REST client; dogfoods `gh` |
| OpenTelemetry collector | `opentelemetry_exporter` → local OTLP endpoint | Dev: Jaeger or Grafana Tempo; prod: TBD |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| LiveView ↔ Contexts | Direct function calls | Never call `Repo` from LiveView |
| Context ↔ Context | Public API of the called context | No context reaches into another's internals |
| Run.Server ↔ Stage.Worker | Oban enqueue (Run.Server writes job) + PubSub (Stage.Worker broadcasts progress) | Run.Server never `GenServer.call`s a worker; that would block |
| Stage.Worker ↔ Agent.Session | `start_child` under run's SessionSupervisor + `Process.monitor/1` + `GenServer.call` for synchronous parts | Monitor-not-link so stage controls retry policy |
| Agent.Session ↔ LLM provider | Behaviour-defined port (`Kiln.Agents.LLM`) | Tests use Mox-based mock impl |

---

## 17. Data Flow Summary

### Primary Happy-Path Flow

```
Operator clicks "Start Run"
    │
    ▼
KilnWeb.IntentLive.handle_event("start_run", …)
    │
    ▼  (context call)
Kiln.Intents.kick_off_run(intent)
    │
    ├─ Kiln.Repo.transaction:
    │    Kiln.Runs.create(intent) [state=queued]
    │    Kiln.Audit.append("run.created")
    │
    ├─ Kiln.Runs.RunDirector.start_run(run_id)
    │    │
    │    └─ DynamicSupervisor.start_child(RunSupervisor, {Run.Supervisor, run_id})
    │           │
    │           ├─ Run.Server.start_link
    │           │     └─ loads workflow, calls Transitions.begin_planning
    │           │         └─ enqueues Stage.Worker(stage=plan) via Oban
    │           ├─ Agents.SessionSupervisor.start_link
    │           └─ Sandboxes.Supervisor.start_link
    │
    └─ PubSub broadcast "runs:board" {:run_state, run}
           │
           ▼
    All RunBoardLive processes stream_insert the new run.

[Oban picks up Stage.Worker job]
    │
    ▼
Stage.Worker.perform(job)
    │
    ├─ Policies.check_cap(run_id, :retries, :tokens) → :ok
    ├─ Stages.create_stage_run([state=running])
    ├─ Audit.append("stage.started")
    ├─ (if sandbox required) Sandboxes.create_sandbox → Controller GenServer
    ├─ Agents.invoke(:planner, payload) → Session GenServer
    │    │ streams tokens, updates SharedNote table, emits telemetry
    │    ▼
    │  {:ok, plan_artifact}
    ├─ Stages.record_success(stage_run, plan_artifact)
    ├─ Runs.Transitions.plan_ready(run_id) [state=planning → coding]
    │    │ transactional: state change + event + Audit.append
    ├─ PubSub broadcast "run:#{id}" + "runs:board"
    └─ Oban.insert(Stage.Worker(stage=code))

[loop through code, test, verify…]

[on verify pass]
    │
    ▼
Runs.Transitions.merged(run_id)
    │
    ├─ Kiln.GitHub.commit + push (Oban jobs, idempotency-keyed)
    ├─ Audit.append("run.merged")
    └─ PubSub broadcast; RunBoardLive moves card to Merged column
```

### On-Restart Flow

```
BEAM boots
    │
    ▼
Kiln.Application starts supervision tree
    │
    ├─ Repo, PubSub, Registries all up
    ├─ RunDirector starts
    │    │
    │    ▼
    │  on_start → Kiln.Runs.list_active() [state NOT IN (merged, failed, escalated)]
    │    │
    │    ▼
    │  for each run: DynamicSupervisor.start_child(RunSupervisor, {…})
    │    │
    │    ▼
    │  Each Run.Server resumes from last checkpoint, finds which Oban job
    │  was in-flight (Oban persists job state across restart → already picks up)
    │
    └─ Oban picks up any scheduled/available jobs; normal operation resumes.
```

---

## 18. Confidence & Open Questions

**HIGH confidence:**
- Four-layer model mapping to contexts
- Single app vs umbrella (solo-scope, strong consensus in Elixir community)
- OTP supervision tree shape
- Ecto state field + command module for run FSM
- Append-only event ledger + hybrid event sourcing
- PubSub + streams for LiveView
- Behaviour-defined LLM adapter

**MEDIUM confidence:**
- Exact Oban queue names and concurrency — tune once we profile
- Whether to adopt `Oban.Workflow` for DAG enforcement or roll our own (lean: roll own for v1)
- DTU mock architecture specifics (how much to fake vs. replay real GitHub API)

**Open questions for phase-specific research:**
- Best Elixir YAML parser for the workflow loader (`YamlElixir` vs `yaml_elixir`) — spot-check in Phase 1.
- Which OTel backend for dev (Jaeger, Tempo, Honeycomb-free) — pick during observability phase.
- Rootless Docker setup on dev machines — revisit in v1.1 if multi-user appears on roadmap.

---

## Sources

### Primary (HIGH confidence — authoritative)

- `/Users/jon/projects/kiln/prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` — BEAM mental model, Phoenix app tree, state placement
- `/Users/jon/projects/kiln/prompts/phoenix-best-practices-deep-research.md` — contexts, umbrella guidance, LiveView patterns
- `/Users/jon/projects/kiln/prompts/phoenix-live-view-best-practices-deep-research.md` — streams, async, PubSub, JS usage
- `/Users/jon/projects/kiln/prompts/ecto-best-practices-deep-research.md` — schemas, changesets, transactions, constraints
- `/Users/jon/projects/kiln/prompts/elixir-best-practices-deep-research.md` — anti-patterns, behaviours, supervision strategies
- `/Users/jon/projects/kiln/prompts/dark_software_factory_context_window.md` — four-layer model, product constraints
- `/Users/jon/projects/kiln/.planning/PROJECT.md` — stack locks, scope, key decisions

### Secondary (MEDIUM — current web research)

- [LiveView 1.1 feature list (Colocated Hooks, stream_async)](https://hexdocs.pm/phoenix_live_view/)
- [Oban 2.21 workflow tracking and rate limiting](https://hexdocs.pm/oban/)
- [Elixir v1.19 supervision tree docs](https://hexdocs.pm/elixir/supervisor-and-application.html)
- [AppSignal: State machines in Elixir with Ecto](https://blog.appsignal.com/2020/07/14/building-state-machines-in-elixir-with-ecto.html)
- [docker-engine-api-elixir (autogen)](https://github.com/jarlah/docker-engine-api-elixir)
- [Docker Engine security docs](https://docs.docker.com/engine/security/)

---
*Architecture research for: Kiln — Elixir/Phoenix dark software factory*
*Researched: 2026-04-18*
