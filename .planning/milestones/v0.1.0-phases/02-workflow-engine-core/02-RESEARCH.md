# Phase 2: Workflow Engine Core - Research

**Researched:** 2026-04-19
**Domain:** Workflow YAML loader + JSV schema validation + topological graph compile + Ecto-driven run state machine + per-run DynamicSupervisor rehydration + content-addressed artifact storage + Oban queue taxonomy
**Confidence:** HIGH (every library API surface verified against local deps source; Phase 1 patterns confirmed against shipped code)

---

## Summary

Phase 2 lights up the first run through Kiln. CONTEXT.md D-54..D-100 already settled every architectural question — Temporal/Argo-inspired flat `stages: [...]` YAML dialect (D-54..D-62), six-queue Oban taxonomy (D-67..D-69), content-addressed artifact storage as a 13th bounded context (D-77..D-85), Ecto-field state machine with `Kiln.Runs.Transitions` command module (D-86..D-90), `RunDirector`-based boot rehydration (D-92..D-96), `StuckDetector` pre-transition hook (D-91). This research fills in the **implementation detail seam**: the exact yaml_elixir and JSV 0.18 calls, the `:digraph` stdlib pattern for topological sort, the in-tx audit + post-commit PubSub ordering, content-addressed writes using atomic `rename(2)`, and the test harness for BEAM-kill recovery.

Three API corrections to note up front (before they become ghost bugs):

1. **JSV 0.18 option is `formats: true`, not `assert_formats: true`** — CONTEXT.md D-63 and D-100 use the older / speculative name. Verified in `deps/jsv/lib/jsv.ex:116-151`. The Phase 1 `Kiln.Audit.SchemaRegistry` already shipped without `formats: true` (line 26 of that file); Phase 2 must decide whether to add it for the new workflow/stage schemas (see §Standard Stack).
2. **yaml_elixir 2.12 does NOT have an `atoms: false` flag.** The library defaults to string keys; `atoms: true` is the **opt-in** to atom keys for `:`-prefixed strings. CONTEXT.md D-63's "load with `atoms: false`" is really "don't pass `atoms: true`." Functionally identical, but any plan that writes the option explicitly will hit a surprising no-op. Verified in `deps/yaml_elixir/lib/yaml_elixir/mapper.ex:65-75`.
3. **Phase 1 migration hard-codes 22 kinds into the `audit_events_event_kind_check` CHECK constraint** (`priv/repo/migrations/20260418000003_create_audit_events.exs:49-58`). D-85 extends to 25 kinds. This needs a new migration (`ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check; ADD CONSTRAINT ... CHECK (... IN ...)`) OR reverse-then-recreate the original constraint; it is NOT a code-only change.

**Primary recommendation:** Mirror Phase 1's established patterns verbatim — `@external_resource` + compile-time `JSV.build!/2` for schemas, `Repo.transact/2` + `SELECT ... FOR UPDATE` + `Audit.append/1` + post-commit `Phoenix.PubSub.broadcast/3` for every transition, `use Kiln.Oban.BaseWorker` for every worker, `:digraph`/`:digraph_utils` from OTP stdlib for the topological sort. Do **not** invent a third way in any area where Phase 1 locked a pattern; doing so is how 13 contexts drift into 13 styles.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

All of D-54..D-100 are LOCKED. The subset this research consumes most heavily:

- **D-54** Temporal/Argo-inspired flat `stages: [...]` array, NOT `jobs.<id>:` map, NOT GitHub Actions `${{ }}` expression language (CVE-class), NOT Tekton 4-kind split.
- **D-55..D-59** canonical YAML shape: `apiVersion`, `id`, `version`, `metadata`, `signature: null` (reserved), `spec.{caps, model_profile, stages}`. Stages have `id`, `kind`, `agent_role`, `depends_on`, `timeout_seconds`, `retry_policy`, `sandbox`, optional `model_preference`, optional structured `on_failure` (NEVER a string expression language).
- **D-62** Elixir-side validators run AFTER JSV at `Kiln.Workflows.load!/1`: single-entry-node, topological-sort success, `depends_on` referential integrity, `on_failure.to` ancestor-only, kind→stage-contract existence, `signature` is `null`.
- **D-63** `yaml_elixir 2.12` with `atoms: false` (see correction #2 above), `JSV.build/2` with `assert_formats: true` (see correction #1 — actually `formats: true`), `JSV.normalize_errors/1` at the loader boundary.
- **D-65** Workflow signing DEFERRED to v2 WFE-02. P2 reserves `signature: null` top-level key + `mix check_no_signature_block` CI guard (mirror of D-26).
- **D-66** Schema layout: `priv/workflow_schemas/v1/workflow.json` + `priv/stage_contracts/v1/<kind>.json` (parallels Phase 1 `priv/audit_schemas/v1/` D-09 precedent).
- **D-67..D-69** Six per-concern queues: `default: 2, stages: 4, github: 2, audit_async: 4, dtu: 2, maintenance: 2`. Aggregate 16. `pool_size: 20`. Plugins: `Oban.Plugins.Pruner` (7 days) + `Oban.Plugins.Cron`.
- **D-70** Canonical `idempotency_key` shapes per worker kind (intent-level, not attempt-level).
- **D-73..D-76** Stage input-contracts at `priv/stage_contracts/v1/<kind>.json`, compiled once into `Kiln.Stages.ContractRegistry` via `@external_resource` + `JSV.build!/2` (exact mirror of `Kiln.Audit.SchemaRegistry`). Validated at `Kiln.Stages.StageWorker.perform/1` entry. Failure → `{:cancel, {:stage_input_rejected, err}}` + `:stage_input_rejected` audit kind + run → `:escalated`.
- **D-77..D-85** Content-addressed artifacts at `priv/artifacts/cas/<sha[0..1]>/<sha[2..3]>/<sha>`, `Kiln.Artifacts` 13th context, `Artifact` Ecto schema with `(stage_run_id, name)` unique, `Artifacts.put/3` streams through `:crypto.hash_init(:sha256)` + `File.stream!` into `priv/artifacts/tmp/` then `rename(2)`. Three new audit kinds: `:stage_input_rejected`, `:artifact_written`, `:integrity_violation` (22 → 25 total).
- **D-86..D-90** 8 states (`:queued, :planning, :coding, :testing, :verifying, :blocked, :merged, :failed, :escalated`). Matrix is module attribute data (not pattern-matched function heads). `transition/3` returns `{:ok, Run.t()} | {:error, ...}`; `transition!/3` raises; `IllegalTransitionError` message template locked. Every transition opens `Repo.transact` → `SELECT ... FOR UPDATE` → `assert_allowed` → `StuckDetector.check/1` → `Run.changeset |> Repo.update()` → `Audit.append(...)` → post-commit `Phoenix.PubSub.broadcast(...)`.
- **D-91** `StuckDetector.check/1` hook fires **inside** the transaction, **before** state update, signature `check(ctx :: map()) :: :ok | {:halt, reason :: atom(), payload :: map()}`. P2 ships a no-op body.
- **D-92..D-96** `RunDirector` `:permanent` under root supervisor, async `:boot_scan` on init, 30-second periodic defensive scan, `RunSupervisor` `DynamicSupervisor` with `max_children: 10`, workflow-checksum assertion on rehydration (`runs.workflow_checksum`), 3-attempt retry with 5/10/15s backoff then `transition(:escalated, reason: :rehydration_failed)`.
- **D-97..D-100** Spec upgrades: CLAUDE.md 12→13 contexts, ARCHITECTURE.md §7 example YAML replaced with D-58/D-59 shape, §15 directory additions, STACK.md note on `formats: true` (see correction #1).

### Claude's Discretion

Sub-module naming (`Kiln.Workflows.{Loader, Graph, Compiler, SchemaRegistry}`, `Kiln.Runs.{Transitions, RunDirector, RunSupervisor}`, `Kiln.Artifacts.{CAS, GcWorker, ScrubWorker}`), YAML field ordering in the example workflow, minimal-fixture contents, operator-facing error phrasing (must include `from`/`to`/`allowed` substrings for tests), concurrency number flex within ±1 if CI measurement justifies, Oban plugin order, `RunDirector` state struct shape (contract is stateless-rehydration-from-Postgres), and whether `Kiln.Artifacts.GcWorker` is Oban Cron vs GenServer `Process.send_after`.

### Deferred Ideas (OUT OF SCOPE)

Workflow signing (v2 WFE-02), provider-split Oban queues (Phase 3 with hard trigger per D-71), `:paused` state (v1.5 FEEDBACK-01), conditional fan-out / `oneOf` join policies (Phase 3+), workflow-level `env:` / variable interpolation (NEVER — GitHub Actions `${{ }}` cautionary tale), per-stage model pinning (conflicts with P10 + OPS-02), cold-artifact compression (measure first), multi-node artifact replication / S3 backend (v2), cross-run artifact sharing (v1 scoped behind `run_id` FK), concurrent-run scheduler beyond `max_children: 10` (v2 PARA-01), `RunDirector` introspection API (Phase 7 UI-01 via PubSub), StuckDetector sliding-window body (Phase 5 OBS-04), `:blocked` producers (Phase 3 BLOCK-01), scenario-runner → state transition integration (Phase 5 SPEC-02), transition rate-limiting (Phase 5), Oban Pro features (OSS-only), workflow-version migration framework (stub in P2, fill on first breaking `apiVersion`), `stages.*.hooks` pre/post stage hooks (Phase 5+).

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **ORCH-01** | Workflow definition is a YAML/JSON graph, versioned in git, schema-validated (JSON Schema Draft 2020-12) at load time | §Standard Stack (yaml_elixir + JSV), §Architecture Patterns (loader pipeline), §Code Examples (compile-time JSV build) |
| **ORCH-02** | Stage executor runs each stage in a supervised BEAM process with crash isolation | §Architecture Patterns (per-run `one_for_all` subtree under `RunSupervisor`), §Code Examples (DynamicSupervisor.start_child + Process.monitor) |
| **ORCH-03** | Run state machine persists to Postgres with explicit allowed transitions; every transition writes an Audit.Event in the same Postgres transaction | §Architecture Patterns (Transitions command module), §Code Examples (Repo.transact + SELECT FOR UPDATE + Audit.append + post-commit PubSub), §Common Pitfalls (PubSub-in-tx ordering) |
| **ORCH-04** | Every stage writes an artifact + event before emitting success; runs are resumable from last checkpoint after crash or redeploy | §Architecture Patterns (CAS writes + RunDirector rehydration), §Code Examples (streaming SHA256 + atomic rename), §Validation Architecture (crash-and-recover test) |
| **ORCH-07** | Idempotency — insert-time Oban unique + handler-level dedupe + `external_operations` two-phase intent → action → completion | §Standard Stack (BaseWorker shipped in P1), §Architecture Patterns (canonical idempotency-key shapes per D-70), §Common Pitfalls (Oban unique is insert-time only) |

---

## Project Constraints (from CLAUDE.md)

Extracted as directives the planner must verify:

- **Postgres is source of truth** — OTP processes are transient accelerators. `RunDirector.boot_scan` hydrates all active runs from `runs` table. No per-run in-memory cache may contradict Postgres.
- **Append-only audit ledger, three-layer enforcement** — D-90's in-tx `Audit.append/1` is already guarded by REVOKE + trigger + RULE (D-12). Phase 2 MUST NOT add any `UPDATE audit_events` or `DELETE FROM audit_events` path. Extending the CHECK constraint for new kinds (D-85) is a DDL migration, not a runtime mutation.
- **Idempotency everywhere** — Oban unique is **insert-time only**. Every external side-effect stub (LLM/git/Docker stubs in P2) MUST pair insert-time unique key with an `external_operations` row AND a handler-level `SELECT ... FOR UPDATE` + state assertion. No bypass.
- **No Docker socket mounts** — N/A to Phase 2 (sandboxes are Phase 3), but stage_contract `sandbox` enum values `{none, readonly, readwrite}` MUST be schema-validated now so Phase 3 can't silently introduce a `socket` value.
- **Bounded autonomy** — Caps are declared at workflow schema level in P2 (D-56). Enforcement body is Phase 5. Phase 2 MUST NOT silently accept a workflow missing `spec.caps`.
- **Scenario runner is sole acceptance oracle** — `kind: verifying` stage semantics are Phase 5. P2 ships the schema and wires the `verifying → merged` edge but does NOT implement the verifier body.
- **Typed block reasons** — `:blocked` state is wired in D-87 matrix; P2 ships the edge, P3 (BLOCK-01) ships producers.
- **Adaptive model routing** — `model_preference` is a tier string (e.g., `"sonnet-class"`), NEVER a pinned model ID (P10). Schema regex should exclude dated model IDs.
- **Run state is Ecto field + command module** — `:gen_statem` forbidden. `Kiln.Runs.Transitions` is the canonical example the other 12 contexts will learn from.
- **No umbrella app** — N/A.
- **No GenServer-per-work-unit** — `Kiln.Runs.RunDirector` is ONE GenServer, not one per run. `Run.Server` in ARCHITECTURE.md §5 is NOT shipped in P2 (ARCHITECTURE.md §5 predates CONTEXT.md D-92..D-96; per-run work is driven by the Oban `StageWorker` reading state from DB, not by a `Run.Server` GenServer). The per-run subtree under `RunSupervisor` is `Kiln.Agents.SessionSupervisor` + `Kiln.Sandboxes.Supervisor` (both shipped empty / stubbed in P2) — NOT a `Run.Server` coordinator. **This is a divergence from ARCHITECTURE.md §5 that Phase 2 should flag for a §5 edit along with D-98.**
- **Elixir anti-patterns** — No `Process.put/2` (Credo check from P1 already catches this); no boolean obsession (use the `state` enum); no `Mix.env` at runtime (Credo check catches); no secrets in compile-time config.

---

## Architectural Responsibility Map

Phase 2 is entirely **API / Backend** tier. No browser/client code, no frontend-server code, no CDN. Every capability in this phase lives in Elixir under `lib/kiln/` with Postgres + local filesystem as the storage layer.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| YAML workflow parsing | API / Backend | Database (workflows persisted post-compile) | Pure transformation; no UI |
| JSV schema validation | API / Backend | — | Pure validation; compile-time build |
| Topological graph compile | API / Backend | — | Pure data transformation |
| Run state machine transitions | API / Backend | Database (SSOT) | D-90 is DB-transactional |
| Boot rehydration (`RunDirector`) | API / Backend | Database (scan source) | Queries Postgres, spawns supervised children |
| Per-run supervisor subtree | API / Backend | — | OTP |
| StuckDetector hook (no-op in P2) | API / Backend | — | Called inside `Transitions` tx |
| Content-addressed artifact storage | API / Backend | Filesystem (`priv/artifacts/cas/`) + Database (`artifacts` lookup) | Hybrid: blobs on FS, metadata in DB |
| Oban queue dispatch | API / Backend | Database (Oban's own persistence) | Oban = durability floor |
| Idempotency (`external_operations` intent rows) | API / Backend | Database | Already shipped in P1; P2 writes first real rows |

Mis-assignment risk the planner should guard against: nothing in Phase 2 belongs in LiveView, in the browser, or in a frontend server. If a task proposes rendering YAML in LiveView or adding a run-board handler, it's misdrafted against Phase 7 and should be deferred.

---

## Standard Stack

### Core (all pinned in Phase 1 `mix.exs`; no new deps)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `yaml_elixir` | **2.12.1** | YAML 1.2 loader (wraps `yamerl`) | Only maintained pure-Erlang YAML parser in Hex; already pinned in P1. `read_from_file/2` + `read_all_from_file/2` are the two entry points [VERIFIED: deps/yaml_elixir/lib/yaml_elixir.ex:10-46]. |
| `JSV` | **0.18.1** | JSON Schema Draft 2020-12 validator | Full Draft 2020-12 compliance; compile-time `build!/2` pattern already shipped in `Kiln.Audit.SchemaRegistry` [VERIFIED: lib/kiln/audit/schema_registry.ex:22-44]. |
| `Oban` (OSS) | **2.21.1** | Durable jobs | Insert-time unique; 6-queue taxonomy per D-67; `Oban.Plugins.Pruner` + `Oban.Plugins.Cron` OSS [VERIFIED: deps/oban/lib/oban/plugins/{pruner,cron}.ex]. |
| `Ecto` + `Ecto.SQL` | **3.13.5** | Schema, changesets, `Repo.transact/2`, `Ecto.Multi` | `Repo.transact/2` is the current idiomatic API (0-arity fn returning `{:ok, x} \| {:error, reason}`); `Repo.transaction/2` is DEPRECATED [VERIFIED: deps/ecto/lib/ecto/repo.ex:2279-2503]. |
| `Postgrex` | **0.22.0** | PG wire driver | `SELECT ... FOR UPDATE` via `Ecto.Query` `lock: "FOR UPDATE"` [CITED: ecto docs]. |
| `Phoenix.PubSub` | **2.1** | In-node broadcast | `broadcast/3,4` for all-subscriber fanout; `broadcast_from/4,5` to exclude sender [VERIFIED: deps/phoenix_pubsub/lib/phoenix/pubsub.ex:229-260]. |
| `:digraph` / `:digraph_utils` | **OTP 28 stdlib** | Topological sort + cycle detection | `digraph_utils:topsort/1` returns sorted list or `false` on cycle; `is_acyclic/1` returns boolean. Zero external deps. [VERIFIED: `erl -noinput -eval 'io:format("~p~n", [digraph_utils:module_info(exports)]).'`] |
| `:crypto` | **OTP 28 stdlib** | SHA-256 streaming | `:crypto.hash_init(:sha256)` + `:crypto.hash_update/2` + `:crypto.hash_final/1` for streaming hashes [CITED: erlang.org crypto docs]. |

### Supporting (already installed, leveraged differently in P2)

| Library | Version | Purpose | When to Use in P2 |
|---------|---------|---------|-------------------|
| `Jason` | transitive | JSON encode/decode | Decode schema files + `$ref` targets; mimic `Kiln.Audit.SchemaRegistry` line 37 [VERIFIED: lib/kiln/audit/schema_registry.ex:37]. |
| `Mox` | **1.2.0** | Behaviour mocks | Phase 2 ships `Kiln.Agents.LLM` stub that ALL test patterns substitute via Mox (deferred real impl to Phase 3); `Kiln.Sandboxes.ContainerRuntime` stub same pattern. |
| `StreamData` | **1.3.0** | Property tests | Transition-matrix closure property (any legal path leads to a terminal); artifact dedup invariant (same bytes → same sha). |
| `LazyHTML` | transitive | LiveView test | Not used in P2 — phase ships zero LiveView. Listed for Phase 7 awareness only. |
| `ecto_uuidv7` via `pg_uuidv7` extension | **1.7.0** | Time-sortable PKs | `fragment("uuidv7()")` default on `runs`, `stage_runs`, `artifacts` — same pattern migration 20260418000003 uses for `audit_events` [VERIFIED: priv/repo/migrations/20260418000003_create_audit_events.exs]. |

### Alternatives Considered (and rejected per CONTEXT.md)

| Instead of | Could Use | Why Rejected in P2 |
|------------|-----------|--------------------|
| `yaml_elixir` | `fast_yaml` | C-NIF build footgun; negligible perf gain on workflow-scale files [CITED: STACK.md line 99]. |
| `JSV` | `ex_json_schema` | Draft 4 only; dormant [CITED: STACK.md line 101]. |
| `:digraph` | Hand-rolled Kahn's algorithm | `:digraph` is OTP stdlib, battle-tested, zero dep cost, documented cycle detection. Use it. |
| `:gen_statem` for run state | Ecto field + `Kiln.Runs.Transitions` | CLAUDE.md convention; splits truth between memory and DB. |
| `Oban.Pro DynamicPruner` | `Oban.Plugins.Pruner` (OSS) | We're OSS-only (D-69). |
| Path-based artifact storage (`<run_id>/<stage_id>/...`) | Content-addressed storage | D-77/D-78 — CAS gives immutability + integrity-on-read + dedup structurally. |
| `Machinery` / `Fsmx` / `ExState` for FSM | Hand-rolled transition matrix | Thin veneers over an Ecto state field; API lock-in; hand-rolled is clearer [CITED: ARCHITECTURE.md §6]. |

### Installation (no new `mix.exs` changes required)

All Phase 2 libraries are already in `mix.lock` from Phase 1. **Zero new dependencies.** The single `mix.exs` change Phase 2 may need is nothing; all additions are source files, config adjustments, and migrations.

**Version verification run:** Last verified 2026-04-19 against local `deps/` (frozen at `mix.lock` values). Registry drift since 2026-01 is unlikely to matter for pinned deps, but `mix hex.outdated` in Phase 8 is worth re-running.

---

## Architecture Patterns

### System Architecture Diagram

```
                  [Operator on laptop: git commit priv/workflows/foo.yaml]
                                        │
                                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  APP BOOT                                                                │
│  Kiln.Application.start/2                                                │
│    1. Start infra children (6: Telemetry, Repo, PubSub, Finch, Registry, │
│       Oban) in a Supervisor                                              │
│    2. Kiln.BootChecks.run!/0 (extended: new invariant `workflow_schema_  │
│       loads` — JSV build succeeds on priv/workflow_schemas/v1/workflow.  │
│       json)                                                              │
│    3. Attach Oban telemetry handler                                      │
│    4. Start `Kiln.Runs.RunSupervisor` (DynamicSupervisor)                │
│    5. Start `Kiln.Runs.RunDirector` (GenServer) — sends :boot_scan to    │
│       self asynchronously (init/1 returns immediately)                   │
│    6. Start `Kiln.Policies.StuckDetector` (GenServer, no-op check/1)     │
│    7. Start `KilnWeb.Endpoint` (10th supervisor child; D-42 moves 7→10)  │
└──────────────────────────────────────────────────────────────────────────┘
                                        │
          ┌─────────────────────────────┼───────────────────────────────┐
          │                             │                               │
          ▼                             ▼                               ▼
┌─────────────────┐          ┌──────────────────┐          ┌──────────────────────┐
│ RunDirector     │          │ StageWorker      │          │ Artifacts (13th ctx) │
│ :boot_scan      │          │ (Oban, :stages)  │          │ put / get / read!    │
│  → list_active  │          │  - validate      │          │  stream through      │
│    (Postgres)   │          │    stage input   │          │  :crypto.hash_init   │
│  - for each:    │          │    via JSV       │          │  then atomic rename  │
│    DynSup.      │          │  - dispatch to   │          │  into                │
│    start_child  │          │    agent (stub)  │          │  priv/artifacts/cas/ │
│    (one_for_all)│          │  - invoke        │          │  <aa>/<bb>/<sha>     │
│    per-run      │          │    Transitions   │          │  + Artifact row     │
│    subtree      │          │  - enqueue next  │          │  (stage_run_id,     │
│ :periodic_scan  │          │    stage         │          │   name, sha256,     │
│  every 30s      │          └──────────────────┘          │   size, type)       │
│                 │                   │                    └──────────────────────┘
│ on {:DOWN, ...} │                   ▼
│   rehydrate     │          ┌──────────────────┐
└─────────────────┘          │ Kiln.Runs.       │
                             │ Transitions      │
                             │                  │
                             │ Repo.transact:   │
                             │  1. SELECT ...   │
                             │     FOR UPDATE   │
                             │  2. assert       │
                             │     allowed      │
                             │     (matrix)     │
                             │  3. StuckDetector│
                             │     .check/1     │
                             │     (no-op P2)   │
                             │  4. Run.update   │
                             │  5. Audit.append │
                             │     (in-tx)      │
                             │                  │
                             │ AFTER commit:    │
                             │  PubSub.broadcast│
                             │  ("run:<id>",    │
                             │   {:run_state,   │
                             │    run})         │
                             └──────────────────┘
                                      │
                                      ▼
                             [subscribers: Phase 7 LiveView;
                              Phase 2 ships zero subscribers]
```

**Data-flow trace for the primary case (start run → first stage → state change):**

1. A future `Kiln.Intents.kick_off_run/1` (Phase 5) inserts `runs` row with `state: :queued`, enqueues first-stage Oban job with `idempotency_key: "run:#{id}:stage:#{first.id}"`.
2. Oban dispatches `Kiln.Stages.StageWorker.perform/1`. Worker calls `fetch_or_record_intent/2` from `Kiln.Oban.BaseWorker` (already shipped). Either first writer → `:inserted_new` or losing writer → `:found_existing, %{state: :completed}` → `{:ok, :noop}` via P1 pattern.
3. Worker reads the stage's `kind` from the compiled graph, fetches the compile-time-built JSV root from `Kiln.Stages.ContractRegistry.fetch(kind)`, validates the stage-input envelope. Failure returns `{:cancel, {:stage_input_rejected, err}}` (NOT `{:discard, ...}` — `{:cancel, ...}` is the modern API; `{:discard, ...}` is deprecated per [VERIFIED: deps/oban/lib/oban/worker.ex:371-386]). Concurrently the worker writes `Audit.append(%{event_kind: :stage_input_rejected, ...})` and `Transitions.transition(run_id, :escalated, %{reason: :invalid_stage_input})`.
4. On happy path: Worker invokes stub `Kiln.Agents.LLM` (returns canned artifact). Worker calls `Kiln.Artifacts.put(stage_run_id, "plan.md", bytes)` — which streams bytes through `:crypto.hash_init(:sha256)` + `File.stream!` into `priv/artifacts/tmp/<uuid>`, then `File.rename/2` to `priv/artifacts/cas/<sha[0..1]>/<sha[2..3]>/<sha>`, then inside a single `Repo.transact` inserts the `Artifact` row + appends `:artifact_written` audit event.
5. Worker calls `Kiln.Runs.Transitions.transition(run_id, :coding)`. This opens `Repo.transact`, takes `SELECT ... FOR UPDATE` on the run, asserts `from == :planning`, calls `StuckDetector.check/1` (P2 returns `:ok` — no-op), updates state, appends `:run_state_transitioned` audit event (all in same tx). Commits. THEN broadcasts on `Kiln.PubSub` topic `"run:#{run_id}"` — AFTER commit, NEVER before (see §Common Pitfalls P2-PITFALL-1).
6. Worker enqueues the next stage's Oban job under `:stages` queue.
7. BEAM is killed between step 6's enqueue and the next worker picking up the job. On restart: Oban's own durability recovers the scheduled job. `RunDirector.boot_scan` finds the `runs` row (state: `:coding`), computes the current `priv/workflows/<id>.yaml` compiled-graph checksum, compares to `runs.workflow_checksum`. If match → `DynamicSupervisor.start_child(RunSupervisor, {RunSubtree, run_id})`. If mismatch → `transition(run_id, :escalated, %{reason: :workflow_changed})` (D-94).

### Recommended Project Structure (additions to Phase 1 layout)

```
priv/
├── workflow_schemas/v1/
│   └── workflow.json               # Top-level dialect (D-66)
├── stage_contracts/v1/
│   ├── planning.json               # D-73 + D-74 kind-specific envelopes
│   ├── coding.json
│   ├── testing.json
│   ├── verifying.json
│   └── merge.json
├── workflows/
│   └── elixir_phoenix_feature.yaml # The one realistic workflow (D-64a)
├── artifacts/
│   ├── cas/                        # Content-addressed blob store (D-77)
│   │   └── .gitkeep                # Ignored otherwise via priv/artifacts/**
│   └── tmp/                        # Staging area for atomic renames
│       └── .gitkeep
└── repo/migrations/
    ├── 20260419000001_extend_audit_event_kinds.exs    # D-85 → 25 kinds
    ├── 20260419000002_create_runs.exs                 # Run schema
    ├── 20260419000003_create_stage_runs.exs
    ├── 20260419000004_create_artifacts.exs
    └── 20260419000005_create_audit_schemas_stage_input_rejected_etc.exs
                                                        # Actually the NEW
                                                        # JSON schema files
                                                        # live under priv/
                                                        # audit_schemas/v1/,
                                                        # so migration just
                                                        # extends CHECK.

lib/kiln/
├── workflows/
│   ├── loader.ex                   # Reads priv/workflows/*.yaml
│   ├── schema_registry.ex          # Compile-time JSV build for workflow.json
│   ├── graph.ex                    # Topological sort via :digraph
│   ├── compiled_graph.ex           # Struct returned by compile/1
│   └── compiler.ex                 # YAML → validated CompiledGraph
├── runs/
│   ├── run.ex                      # Ecto schema
│   ├── transitions.ex              # Command module (D-87..D-90)
│   ├── illegal_transition_error.ex # D-89
│   ├── run_supervisor.ex           # DynamicSupervisor (D-95)
│   ├── run_director.ex             # Top-level GenServer (D-92..D-96)
│   └── run_subtree.ex              # Per-run supervisor (one_for_all)
├── stages/
│   ├── stage_run.ex                # Ecto schema
│   ├── stage_worker.ex             # Oban worker (queue: :stages)
│   └── contract_registry.ex        # Compile-time JSV build for stage contracts
├── artifacts.ex                    # 13th context public API (D-80)
├── artifacts/
│   ├── artifact.ex                 # Ecto schema
│   ├── cas.ex                      # Content-addressed store (:crypto + rename)
│   ├── corruption_error.ex         # Raised by Artifacts.read!/1 on mismatch
│   ├── gc_worker.ex                # Scheduled-no-op in P2, filled in P5
│   └── scrub_worker.ex             # Scheduled-no-op in P2
├── policies/
│   └── stuck_detector.ex           # Real GenServer, no-op check/1 (D-91)
└── workflows.ex                    # Public API module (upgrade from stub)

test/
├── support/
│   ├── fixtures/workflows/
│   │   └── minimal_two_stage.yaml  # 2-stage pass-through (D-64b)
│   └── run_case.ex                 # Shared setup for run-tests (DB + Oban manual)
├── kiln/
│   ├── workflows/
│   │   ├── loader_test.exs
│   │   ├── graph_test.exs
│   │   ├── compiler_test.exs
│   │   └── schema_registry_test.exs
│   ├── runs/
│   │   ├── transitions_test.exs
│   │   ├── run_director_test.exs
│   │   └── illegal_transition_error_test.exs
│   ├── stages/
│   │   ├── contract_registry_test.exs
│   │   └── stage_worker_test.exs
│   ├── artifacts_test.exs
│   ├── artifacts/
│   │   ├── cas_test.exs
│   │   └── gc_worker_test.exs
│   └── policies/
│       └── stuck_detector_test.exs
├── integration/
│   └── rehydration_test.exs         # BEAM-kill + reboot + continue
└── kiln/application_test.exs        # Extend to 10-child invariant
```

### Pattern 1: Compile-time JSV build via `@external_resource` + `JSV.build!/2`

**What:** Load every JSON Schema at compile time, build JSV `Root` structs once per build, stash in a module attribute.
**When to use:** Every schema file shipped under `priv/**/*.json`.
**Example (verbatim mirror of Phase 1's `Kiln.Audit.SchemaRegistry`):**

```elixir
defmodule Kiln.Stages.ContractRegistry do
  @moduledoc "Compile-time JSV registry for per-kind stage input contracts."

  alias Kiln.Stages.ContractRegistry

  @contracts_dir Path.expand("../../../priv/stage_contracts/v1", __DIR__)

  # D-63 correction: use :formats (not :assert_formats).
  # :formats options per deps/jsv/lib/jsv.ex:116-151:
  #   nil    → inherit from meta-schema (2020-12 default is NO format assertion)
  #   true   → enable format validation with default validators
  #   false  → disable entirely
  #   [mods] → custom format validator modules
  @build_opts [
    default_meta: "https://json-schema.org/draft/2020-12/schema",
    formats: true   # Enable "format": "uri" / "format": "uuid" validation
  ]

  @kinds ~w(planning coding testing verifying merge)a

  @schemas (for kind <- @kinds, into: %{} do
             path = Path.join(@contracts_dir, "#{kind}.json")
             @external_resource path
             raw = path |> File.read!() |> Jason.decode!()
             root = JSV.build!(raw, @build_opts)
             {kind, root}
           end)

  @spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :unknown_kind}
  def fetch(kind) when is_atom(kind) do
    case Map.get(@schemas, kind) do
      nil -> {:error, :unknown_kind}
      root -> {:ok, root}
    end
  end

  @spec kinds() :: [atom(), ...]
  def kinds, do: @kinds
end
```

[VERIFIED: lib/kiln/audit/schema_registry.ex lines 22-44 — identical structure]

**Note on Phase 1's `Kiln.Audit.SchemaRegistry`:** it uses `@build_opts [default_meta: "...draft/2020-12/schema"]` WITHOUT `formats: true`. This means Phase 1's audit schemas do NOT enforce `"format": "uri"` etc. If that matters for Phase 1's audit schemas, a tiny P2 follow-up can add `formats: true` there too. For Phase 2, **use `formats: true`** on both `Kiln.Workflows.SchemaRegistry` and `Kiln.Stages.ContractRegistry` so workflow authors get real feedback on malformed `$id` URIs etc.

### Pattern 2: Workflow loader pipeline

**What:** YAML → `Map` (string keys) → JSV validate → D-62 Elixir-side validators → topological sort → `%CompiledGraph{}`.
**When to use:** `Kiln.Workflows.load!/1` entry point.
**Example:**

```elixir
defmodule Kiln.Workflows.Loader do
  alias Kiln.Workflows.{Compiler, SchemaRegistry}

  @spec load(Path.t()) ::
          {:ok, Kiln.Workflows.CompiledGraph.t()}
          | {:error,
             {:yaml_parse, term()} |
             {:schema_invalid, map()} |
             {:graph_invalid, atom(), term()}}
  def load(path) do
    with {:ok, raw} <- read_yaml(path),
         {:ok, _} <- validate_schema(raw),
         {:ok, compiled} <- Compiler.compile(raw) do
      {:ok, compiled}
    end
  end

  # D-63: atoms: true is the opt-in for atom keys; omit it to keep binary keys
  # only (the safe default — no atom-table exhaustion on malicious input).
  defp read_yaml(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, other} -> {:error, {:yaml_parse, {:not_a_map, other}}}
      {:error, err} -> {:error, {:yaml_parse, err}}
    end
  end

  defp validate_schema(raw) do
    {:ok, root} = SchemaRegistry.fetch(:workflow)

    case JSV.validate(raw, root) do
      {:ok, _cast} ->
        {:ok, raw}

      {:error, validation_error} ->
        # D-63: normalize errors at loader boundary — no raw JSV tuples
        # reach the UI or audit log.
        {:error, {:schema_invalid, JSV.normalize_error(validation_error)}}
    end
  end
end
```

**Error shape from yaml_elixir** (verified in `deps/yaml_elixir/lib/yaml_elixir.ex:48-59`):
- `{:error, %YamlElixir.FileNotFoundError{message: "..."}}` — file not found
- `{:error, %YamlElixir.ParsingError{...}}` — malformed YAML (line/column populated by `from_yamerl/1`)
- `{:error, %YamlElixir.ParsingError{message: "malformed yaml"}}` — any other catch

Normalize these into a single `{:yaml_parse, reason}` shape at the loader boundary so downstream audit logs don't need to know yaml_elixir internals.

### Pattern 3: Topological sort via `:digraph` stdlib

**What:** Build an OTP `:digraph`, run `:digraph_utils.topsort/1`, return either `{:ok, [stage_id]}` or `{:error, :cycle}`.
**When to use:** Inside `Kiln.Workflows.Graph.compile/1`.
**Example:**

```elixir
defmodule Kiln.Workflows.Graph do
  @spec topological_sort([%{id: String.t(), depends_on: [String.t()]}]) ::
          {:ok, [String.t()]} | {:error, :cycle} | {:error, {:missing_dep, String.t()}}
  def topological_sort(stages) do
    g = :digraph.new([:acyclic])  # :acyclic flag makes add_edge refuse cycles

    ids = MapSet.new(stages, & &1.id)

    # Add all vertices first so missing-dep detection works cleanly.
    Enum.each(stages, fn s -> :digraph.add_vertex(g, s.id) end)

    # Add edges; detect "depends_on an unknown id" up front.
    result =
      Enum.reduce_while(stages, :ok, fn s, :ok ->
        Enum.reduce_while(s.depends_on, :ok, fn dep, :ok ->
          cond do
            not MapSet.member?(ids, dep) ->
              {:halt, {:error, {:missing_dep, dep}}}

            # :digraph.add_edge/3 returns {:error, {:bad_edge, path}} on cycle
            # when graph is created with :acyclic flag
            match?({:error, _}, :digraph.add_edge(g, dep, s.id)) ->
              {:halt, {:error, :cycle}}

            true ->
              {:cont, :ok}
          end
        end)
        |> case do
          :ok -> {:cont, :ok}
          other -> {:halt, other}
        end
      end)

    try do
      case result do
        :ok ->
          case :digraph_utils.topsort(g) do
            false -> {:error, :cycle}
            sorted when is_list(sorted) -> {:ok, sorted}
          end

        error ->
          error
      end
    after
      # :digraph is ETS-backed; must delete to free the table
      :digraph.delete(g)
    end
  end
end
```

**Critical detail:** `:digraph.new([:acyclic])` makes `:digraph.add_edge/3` return `{:error, {:bad_edge, path}}` the moment a cycle would be introduced. Using `:acyclic` at creation gives you cycle rejection WITHOUT a separate `is_acyclic/1` call. Also: the graph is ETS-backed — **every caller MUST call `:digraph.delete/1`** or leak ETS tables (this is a common beginner bug; `try/after` is mandatory). [CITED: erlang.org digraph docs]

### Pattern 4: `Repo.transact/2` + `SELECT ... FOR UPDATE` + in-tx `Audit.append/1` + post-commit PubSub

**What:** The canonical state-transition transaction (D-90).
**When to use:** Every call in `Kiln.Runs.Transitions`.
**Example:**

```elixir
defmodule Kiln.Runs.Transitions do
  import Ecto.Query
  alias Kiln.{Audit, Repo}
  alias Kiln.Runs.Run
  alias Kiln.Policies.StuckDetector

  @terminal ~w(merged failed escalated)a
  @any_state ~w(queued planning coding testing verifying blocked)a
  @matrix %{
    queued:    [:planning],
    planning:  [:coding, :blocked],
    coding:    [:testing, :blocked, :planning],
    testing:   [:verifying, :blocked, :planning],
    verifying: [:merged, :planning, :blocked],
    blocked:   [:planning, :coding, :testing, :verifying]
  }
  @cross_cutting ~w(escalated failed)a

  @spec transition(Ecto.UUID.t(), atom(), map()) ::
          {:ok, Run.t()} | {:error, :illegal_transition | :not_found | term()}
  def transition(run_id, to, meta \\ %{}) when is_atom(to) do
    result =
      Repo.transact(fn ->
        with {:ok, run} <- lock_run(run_id),
             :ok <- assert_allowed(run.state, to),
             :ok <- StuckDetector.check(%{run: run, to: to, meta: meta}),
             {:ok, updated} <- update_state(run, to, meta),
             {:ok, _event} <- append_audit(updated, run.state, to, meta) do
          {:ok, updated}
        end
      end)

    # CRITICAL: PubSub broadcast AFTER the transaction commits.
    # If we broadcast INSIDE the transact closure, subscribers may
    # see a stale DB (the tx hasn't committed yet when they do
    # Repo.get); worse, if the tx later rolls back, subscribers
    # acted on a state change that didn't happen. See Common Pitfall #1.
    case result do
      {:ok, run} ->
        Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})
        Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})
        {:ok, run}

      other ->
        other
    end
  end

  defp lock_run(run_id) do
    case Repo.one(from(r in Run, where: r.id == ^run_id, lock: "FOR UPDATE")) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  defp assert_allowed(from, to) do
    allowed = Map.get(@matrix, from, []) ++ @cross_cutting

    cond do
      from in @terminal -> {:error, :illegal_transition}
      to in allowed -> :ok
      true -> {:error, :illegal_transition}
    end
  end

  defp update_state(run, to, meta) do
    run
    |> Run.transition_changeset(%{state: to}, meta)
    |> Repo.update()
  end

  defp append_audit(run, from, to, meta) do
    Audit.append(%{
      event_kind: :run_state_transitioned,
      run_id: run.id,
      correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
      payload:
        %{"from" => Atom.to_string(from), "to" => Atom.to_string(to)}
        |> maybe_add_reason(meta)
    })
  end

  defp maybe_add_reason(payload, %{reason: r}) when is_atom(r),
    do: Map.put(payload, "reason", Atom.to_string(r))
  defp maybe_add_reason(payload, _), do: payload
end
```

**Verified API details:**
- `Repo.transact/2` expects a 0-arity function returning `{:ok, value}` or `{:error, reason}`; on `{:error, _}` the tx rolls back automatically. Raising inside also rolls back. [VERIFIED: deps/ecto/lib/ecto/repo.ex:2430-2502]
- `Ecto.Query` `lock: "FOR UPDATE"` is the idiomatic row-lock opt. For UUID PK lookup in tx, `Repo.one(from r in Run, where: r.id == ^id, lock: "FOR UPDATE")` is safer than `Repo.get!` (which raises on missing and can't take a lock opt).
- `@any_state ++ @cross_cutting` — from any non-terminal state you can always go to `:escalated` or `:failed`. The match-cond above encodes D-87.

### Pattern 5: Content-addressed artifact write via streaming SHA-256 + atomic rename

**What:** `Kiln.Artifacts.put/3` streams bytes through `:crypto` SHA-256, writes to `priv/artifacts/tmp/<uuid>`, renames to `priv/artifacts/cas/<aa>/<bb>/<sha>`, inserts `Artifact` row in a single `Repo.transact`.
**When to use:** Every stage-produced artifact.
**Example:**

```elixir
defmodule Kiln.Artifacts.CAS do
  @moduledoc "Content-addressed blob store (D-77)."

  @cas_root Application.compile_env(:kiln, [:artifacts, :cas_root],
              "priv/artifacts/cas")
  @tmp_root Application.compile_env(:kiln, [:artifacts, :tmp_root],
              "priv/artifacts/tmp")

  @doc """
  Streams `body` through SHA-256 while writing to a temp file, then
  atomically renames to the final CAS path. Returns `{:ok, sha, size}`.

  `body` is an Enumerable that yields iodata chunks (e.g.,
  `File.stream!/3` for existing files, or `[iodata]` for in-memory).
  """
  @spec put_stream(Enumerable.t()) :: {:ok, String.t(), non_neg_integer()} | {:error, term()}
  def put_stream(body) do
    File.mkdir_p!(@tmp_root)
    tmp_path = Path.join(@tmp_root, Ecto.UUID.generate())

    File.open!(tmp_path, [:write, :binary, :raw], fn fd ->
      # :crypto.hash_init returns an opaque hash state; each update/2
      # folds iodata into it; final/1 returns the 32-byte binary digest.
      {hash_state, size} =
        Enum.reduce(body, {:crypto.hash_init(:sha256), 0}, fn chunk, {h, sz} ->
          :ok = :file.write(fd, chunk)
          {:crypto.hash_update(h, chunk), sz + IO.iodata_length(chunk)}
        end)

      digest = :crypto.hash_final(hash_state)
      sha_hex = Base.encode16(digest, case: :lower)

      # .../cas/<aa>/<bb>/<sha>
      final_path = cas_path(sha_hex)
      File.mkdir_p!(Path.dirname(final_path))

      # File.rename/2 delegates to :file.rename/2 which invokes rename(2).
      # On the same filesystem (priv/artifacts/tmp and priv/artifacts/cas
      # are siblings under priv/), rename(2) is atomic — no half-blob
      # left behind if the process crashes mid-call. Cross-FS rename is
      # NOT atomic (falls back to copy+unlink), so @tmp_root and
      # @cas_root MUST be on the same filesystem. Document loudly.
      case File.rename(tmp_path, final_path) do
        :ok ->
          # Make blob read-only (mode 0444) so even a future bug can't
          # mutate it. Safe to ignore if it fails (macOS APFS sometimes
          # quirks on chmod after rename; the content-addressing itself
          # catches corruption on read via read!/1 re-hash).
          _ = File.chmod(final_path, 0o444)
          {sha_hex, size}

        {:error, reason} ->
          # Best-effort cleanup of the tmp file before bubbling up
          _ = File.rm(tmp_path)
          throw({:rename_failed, reason})
      end
    end)
  catch
    {:rename_failed, reason} -> {:error, {:rename_failed, reason}}
  else
    {sha_hex, size} -> {:ok, sha_hex, size}
  end

  defp cas_path(<<aa::binary-size(2), bb::binary-size(2), _rest::binary>> = sha) do
    Path.join([@cas_root, aa, bb, sha])
  end
end
```

**Atomic-rename gotchas on macOS/Linux:**
- `rename(2)` is atomic when source and destination are on the same filesystem. `priv/artifacts/tmp/` and `priv/artifacts/cas/` MUST both live under `priv/artifacts/` for this to hold [CITED: POSIX `rename(2)`, macOS APFS + Linux ext4/XFS docs].
- If source path doesn't exist → `{:error, :enoent}`.
- If destination exists (same sha already written — dedup hit) → `rename(2)` overwrites atomically on POSIX. This is the **correct** behavior under CAS (same bytes = same file; dedup is free).
- ENOSPC mid-write → `File.write/2` raises; the tmp file is leaked; a separate `Kiln.Artifacts.ScrubWorker` (D-84 weekly) can clean orphans. The key invariant: **no half-blob ever appears at the final CAS path**.
- `File.chmod(..., 0o444)` after rename is best-effort; don't `raise` on failure.

**The Ecto row insertion** should happen OUTSIDE the `File.open!` callback (which may be slow) and inside a separate `Repo.transact` that also appends the `:artifact_written` audit event:

```elixir
defmodule Kiln.Artifacts do
  alias Kiln.{Audit, Repo}
  alias Kiln.Artifacts.{Artifact, CAS}

  @spec put(Ecto.UUID.t(), String.t(), Enumerable.t(), keyword()) ::
          {:ok, Artifact.t()} | {:error, term()}
  def put(stage_run_id, name, body, opts \\ []) do
    content_type = Keyword.fetch!(opts, :content_type)

    with {:ok, sha, size} <- CAS.put_stream(body) do
      Repo.transact(fn ->
        changeset = Artifact.changeset(%Artifact{}, %{
          stage_run_id: stage_run_id,
          name: name,
          sha256: sha,
          size_bytes: size,
          content_type: content_type,
          schema_version: 1
        })

        with {:ok, artifact} <- Repo.insert(changeset),
             {:ok, _ev} <-
               Audit.append(%{
                 event_kind: :artifact_written,
                 run_id: artifact.run_id,   # via Artifact changeset resolution
                 stage_id: artifact.stage_run_id,
                 correlation_id:
                   Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
                 payload: %{
                   "name" => name,
                   "sha256" => sha,
                   "size_bytes" => size,
                   "content_type" => content_type
                 }
               }) do
          {:ok, artifact}
        end
      end)
    end
  end
end
```

**Re-hashing on read** (`Kiln.Artifacts.read!/1`) is D-84's integrity-on-every-open guarantee:

```elixir
def read!(%Artifact{sha256: expected} = artifact) do
  path = CAS.cas_path(expected)
  bytes = File.read!(path)
  actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  if actual != expected do
    # Audit BEFORE raising so the integrity violation is in the ledger
    _ = Audit.append(%{
      event_kind: :integrity_violation,
      correlation_id:
        Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
      payload: %{
        "artifact_id" => artifact.id,
        "expected_sha" => expected,
        "actual_sha" => actual,
        "path" => path
      }
    })

    raise Kiln.Artifacts.CorruptionError,
      artifact_id: artifact.id, expected: expected, actual: actual
  end

  bytes
end
```

### Pattern 6: `RunDirector` boot scan + monitor rebuild + periodic defensive scan

**What:** A `:permanent` GenServer under the root supervisor that lists active runs from Postgres, spawns per-run subtrees under `RunSupervisor`, and `Process.monitor/1`s each subtree so it can react to `{:DOWN, ...}` messages. Also runs a 30-second defensive `Process.send_after(:periodic_scan, 30_000)` to catch races where a subtree died without a DOWN reaching the current `RunDirector` pid.

**When to use:** Root of Phase 2's supervised-run machinery (D-92).
**Example:**

```elixir
defmodule Kiln.Runs.RunDirector do
  use GenServer

  require Logger
  alias Kiln.Runs
  alias Kiln.Runs.RunSupervisor

  @periodic_scan_ms 30_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # init/1 returns IMMEDIATELY so supervisor boot doesn't block on the
    # scan. Boot scan is deferred to a self-cast. D-92.
    send(self(), :boot_scan)

    # monitors is a map of {supervised_run_pid => run_id}
    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_info(:boot_scan, state) do
    state = do_scan(state)
    Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
    {:noreply, state}
  end

  def handle_info(:periodic_scan, state) do
    state = do_scan(state)
    Process.send_after(self(), :periodic_scan, @periodic_scan_ms)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{monitors: mons} = state) do
    case Map.pop(mons, pid) do
      {nil, _} ->
        {:noreply, state}

      {run_id, remaining} ->
        Logger.warning(
          "run subtree died; rehydrating",
          run_id: run_id,
          reason: inspect(reason)
        )

        # Fire-and-forget rehydrate — the D-93 retry envelope
        # (3 attempts / 5/10/15s) lives inside rehydrate_run/1.
        _ = rehydrate_run(run_id)
        {:noreply, %{state | monitors: remaining}}
    end
  end

  # -- private ---------------------------------------------------------

  defp do_scan(state) do
    active = Runs.list_active()
    already_monitored = MapSet.new(Map.values(state.monitors))

    Enum.reduce(active, state, fn run, acc ->
      if MapSet.member?(already_monitored, run.id) do
        acc
      else
        case spawn_subtree(run) do
          {:ok, pid} ->
            ref = Process.monitor(pid)
            %{acc | monitors: Map.put(acc.monitors, pid, {ref, run.id})}

          {:error, reason} ->
            Logger.error(
              "failed to spawn run subtree",
              run_id: run.id,
              reason: inspect(reason)
            )

            # D-93: after 3 attempts, escalate. Simplified here.
            _ = Kiln.Runs.Transitions.transition(run.id, :escalated, %{
              reason: :rehydration_failed,
              detail: inspect(reason)
            })

            acc
        end
      end
    end)
  end

  defp spawn_subtree(run) do
    # D-94: workflow-checksum assertion — compare compiled-graph checksum
    # on disk against runs.workflow_checksum. Mismatch → escalate.
    case assert_workflow_unchanged(run) do
      :ok ->
        DynamicSupervisor.start_child(
          RunSupervisor,
          {Kiln.Runs.RunSubtree, run_id: run.id}
        )

      {:error, :workflow_changed} = err ->
        _ = Kiln.Runs.Transitions.transition(run.id, :escalated, %{
          reason: :workflow_changed
        })
        err
    end
  end

  defp assert_workflow_unchanged(_run), do: :ok  # stub; fill in loader
  defp rehydrate_run(_run_id), do: :ok           # stub
end
```

**Why the 30s periodic scan is NOT redundant with `{:DOWN, ...}`:** D-92 captures the race where the subtree's parent `RunSupervisor` itself restarts between a subtree's death and the DOWN message reaching a NEW `RunDirector` pid. In that window, the DOWN goes to the dead director; the new director never sees it. The periodic scan re-reads Postgres and finds any run that should be supervised but isn't. Cost is a single `SELECT` filtered on `state IN @any_state` — negligible for a solo-op box with 10 active runs max.

**Monitor not link:** D-92 says `monitored (not linked)`. This means `RunDirector` can observe a subtree's death without dying itself — essential, because `RunDirector` is the recovery mechanism. Links would make `RunDirector` crash every time a subtree crashed, losing the recovery capability.

### Pattern 7: Canonical `idempotency_key` shapes and handler-level dedupe

**What:** Insert-time uniqueness collapses duplicate Oban enqueues. Handler-level `SELECT ... FOR UPDATE` + state assertion handles retries-after-completion.
**When to use:** Every Phase 2 Oban worker.
**Key shapes (from D-70 — restated so the planner has one place to look):**

| Worker | Key shape | Rationale |
|--------|-----------|-----------|
| `Kiln.Stages.StageWorker` | `"run:#{run_id}:stage:#{stage_id}"` | Attempt-independent; dedupe is handler-level. |
| `Kiln.Runs.StateTransitionWorker` (if async transitions exist in P2) | `"run:#{run_id}:transition:#{from}->#{to}"` | Identifies the business intent, not the attempt. |
| `Kiln.Audit.AsyncAppendWorker` | `"audit:#{correlation_id}:#{event_kind}:#{sha256(payload)[0..15]}"` | Content-addressed; retries collapse. |
| `external_operations` completion callback | `"extop:#{external_operation_id}"` | The intent UUID IS the key. |
| `Kiln.ExternalOperations.PrunerWorker` (P1, already cron-driven) | `"pruner:external_operations:#{date_bucket}"` | One run per UTC day. |
| `Kiln.Policies.StuckDetectorWorker` (P5) | `"stuck_scan:#{minute_bucket_5min}"` | 5-minute tumbling window. |

**Handler-level dedupe recipe (identical to Phase 1's `ExternalOperations.fetch_or_record_intent/2`):**

```elixir
def perform(%Oban.Job{args: %{"idempotency_key" => key} = args}) do
  case fetch_or_record_intent(key, %{
         op_kind: "stage_dispatch",
         intent_payload: args,
         run_id: args["run_id"],
         stage_id: args["stage_id"]
       }) do
    {:found_existing, %{state: :completed}} ->
      # Already done on a prior attempt — no-op.
      :ok

    {:found_existing, %{state: :action_in_flight} = op} ->
      # A sibling worker is mid-execution; safest to :snooze rather
      # than race. 5-second snooze backs off to the next tick.
      {:snooze, 5}

    {_status, op} ->
      # First writer; proceed with the real work...
      do_stage(op, args)
  end
end
```

### Pattern 8: Oban queue + plugin config (replaces P1 scaffold)

**File:** `config/config.exs`

```elixir
# Phase 2 D-67..D-69: six-queue taxonomy; aggregate 16 workers; pool_size 20.
config :kiln, Oban,
  repo: Kiln.Repo,
  engine: Oban.Engines.Basic,
  queues: [
    default: 2,         # ad-hoc / one-offs
    stages: 4,          # stage dispatch (StageWorker) — 2 parallel runs × 2 stages
    github: 2,          # git / gh CLI shell-outs (activated Phase 6)
    audit_async: 4,     # non-transactional audit appends
    dtu: 2,             # DTU mock contract tests (activated Phase 3)
    maintenance: 2      # cron destinations (pruner, stuck-scan, etc.)
  ],
  plugins: [
    # Prune Oban's own completed job rows after 7 days.
    # Distinct from P1's Kiln.ExternalOperations.Pruner (30-day worker).
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Active: P1's external_operations pruner.
       {"0 3 * * *", Kiln.ExternalOperations.Pruner, queue: :maintenance},
       # Commented out until P5 activates the body.
       # {"*/5 * * * *", Kiln.Policies.StuckDetectorWorker, queue: :maintenance},
       # Commented out until P3 activates DTU weekly contract test.
       # {"0 4 * * 0", Kiln.Sandboxes.DTU.ContractTestWorker, queue: :maintenance}
     ]}
  ]
```

**File:** `config/runtime.exs` change (D-68 pool_size 10 → 20):

```elixir
config :kiln, Kiln.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),  # was "10"
  socket_options: maybe_ipv6
```

**File:** `config/dev.exs` change:

```elixir
pool_size: 20  # was 10
```

**Math verification (D-68):** 6 queues × their limits = 2+4+2+4+2+2 = 16 worker pool pressure. Plus ~2 plugin overhead + ~2 LiveView/`/ops/*` queries + ~1 RunDirector+StuckDetector + ~3 request-spike headroom = ~24 max simultaneous DB sessions on a laptop. Against `pool_size: 20` we're ~4 slots over peak worst case, but `:stages` workers spend almost all their time on LLM wall-clock (minutes), not holding DB checkouts — real steady-state pressure is maybe 8. Defensible; revisit when P3 provider-split lands (per D-71, bump to 28).

### Anti-Patterns to Avoid

- **Putting `Phoenix.PubSub.broadcast/3` INSIDE the `Repo.transact` closure.** Subscribers see a state the DB hasn't committed yet; worse, a subsequent error rolls back the tx but the message was already delivered. Always broadcast AFTER the `Repo.transact` returns `{:ok, _}`. [Common Pitfall #1 below.]
- **Using `yaml_elixir` with `atoms: true`.** Atom-table exhaustion on malicious YAML. Just omit the option (default is string keys). D-63 is correct in spirit, imprecise in API name.
- **Catching cycle detection via `rescue` rather than explicit return.** `:digraph.add_edge/3` returns `{:error, {:bad_edge, path}}` on cycle when `:acyclic` was passed at creation. Match the tuple, don't rescue.
- **Writing blob metadata (the `artifacts` row) BEFORE the `rename(2)` completes.** If rename fails and you already wrote the row, the next `read!/1` hits `:enoent`. Order: write tmp → rename → insert row (+ audit event) in `Repo.transact`. If the DB insert fails, you've got an orphan blob — cleanable by `ScrubWorker` (D-84), so this is the right direction of orphan.
- **Using `Oban.Plugins.Cron`'s `args:` field as a de-facto state channel.** Cron entries should invoke a worker; everything the worker needs should be derivable from scheduled time + DB, not from args shoved through cron.
- **Forgetting `:digraph.delete/1`.** ETS-backed; you WILL leak tables across test runs. Always `try/after`.
- **Leaking atom namespaces from workflow IDs.** `String.to_atom(raw_yaml_id)` anywhere is forbidden. Workflow IDs stay binary until matched against the schema's `^[a-z][a-z0-9_]{2,63}$` pattern and indexed by binary in ETS/DB.
- **Using `:gen_statem` anywhere on this phase.** CLAUDE.md convention. Ecto field + `Kiln.Runs.Transitions` is the canonical pattern.
- **Using `Process.put/2` to thread `correlation_id`.** P1's Credo check catches this. Thread explicitly via `Logger.metadata`.
- **Parallel-running `:digraph.topsort/1` on the same graph handle in multiple processes.** `:digraph` tables are owned by the creating process; concurrent access is undefined. Create → sort → delete in the same caller.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML parsing | Own YAML reader | `YamlElixir.read_from_file/2` | Wraps the C-free yamerl; anchors/merge keys handled. |
| JSON Schema Draft 2020-12 validation | Own validator (or `ex_json_schema`) | `JSV.build!/2` + `JSV.validate/2` | Full draft 2020-12 compliance; 100% test-suite pass; error normalization. |
| Topological sort / cycle detection | Own Kahn's algorithm | `:digraph.new([:acyclic])` + `:digraph_utils.topsort/1` | OTP stdlib; zero deps; battle-tested. |
| SHA-256 streaming over large inputs | Read whole file + `:crypto.hash/2` | `:crypto.hash_init/1` + `hash_update/2` + `hash_final/1` with `File.stream!` | 50 MB cap per D-75 is fine whole-file, but CAS reads happen every `read!/1` — streaming is cheaper on cold-cache rehash. |
| Atomic file-replace semantics | `File.write!` + `File.cp` | `File.open!` + `File.rename/2` (delegates to `rename(2)`) | `rename(2)` is atomic on same filesystem; `cp` is NOT. |
| Oban idempotency | Hand-written unique-constraint checks | `use Kiln.Oban.BaseWorker` (insert-time unique on `:idempotency_key`) + `fetch_or_record_intent/2` (handler-level) | P1 already built this; use it. |
| Run state machine | `:gen_statem` | Ecto field + `Kiln.Runs.Transitions` command module | CLAUDE.md convention; Postgres is truth. |
| Post-commit side effects inside `Repo.transact` | `after_transaction` callbacks | Run the side effect AFTER `Repo.transact` returns `{:ok, _}` | Simpler, explicit, no ghost state. |
| Oban cron scheduling | Own `Process.send_after` loop | `Oban.Plugins.Cron` | Survives restarts; visible in Oban Web. |
| Crontab expression parsing | Own regex | `Oban.Cron.Expression.parse/1` | Already present; `@daily`, `0 3 * * *` etc. |
| JSON encode/decode | Own parser | `Jason` | Already pinned; consistent with P1. |
| DateTime handling | Own offset math | `DateTime.utc_now/0`, `DateTime.add/3` | Standard. |
| UUID generation (where no DB default) | Own | `Ecto.UUID.generate/0` (v4) or `fragment("uuidv7()")` at DB default (v7) | Time-sortable PKs preferred for all P2 tables. |

**Key insight:** Phase 2's entire surface is composable from OTP + Elixir stdlib + P1's BaseWorker + JSV + yaml_elixir. No phase task should invent a new primitive. If a plan proposes one, it's probably wrong.

---

## Common Pitfalls

### Pitfall 1: `Phoenix.PubSub.broadcast/3` inside `Repo.transact` closure

**What goes wrong:** Subscribers see stale DB state (the transaction hasn't committed) or worse, receive a state-change message for a transition that rolled back.

**Why it happens:** The natural place to broadcast feels like "right after I updated the row", which lexically is inside the closure. Ecto doesn't (and can't) delay the message delivery until commit — the PubSub call fires immediately.

**How to avoid:** Always broadcast AFTER `Repo.transact` returns `{:ok, _}`. See Pattern 4 example. If multiple transitions need to broadcast, collect them (or the final run struct) in the `{:ok, value}` return and broadcast once outside.

**Warning signs:**
- Tests that subscribe to `Kiln.PubSub` see messages for state transitions that "didn't happen" (because the tx rolled back on audit-append failure, say).
- LiveView handlers refetching and seeing an earlier state than the broadcast promised.

**[CITED:** Phoenix docs — [Phoenix.PubSub guide](https://hexdocs.pm/phoenix_pubsub) doesn't itself document this trap, but [Ecto.Repo docs §Working with processes](https://hexdocs.pm/ecto/Ecto.Repo.html#module-working-with-processes) implies the issue: "A separate process started inside a transaction won't be part of the same transaction and will use a separate connection altogether."]

### Pitfall 2: Phase 1's 22-kind CHECK constraint blocks D-85's new audit kinds

**What goes wrong:** P2 adds three new audit event kinds (`:stage_input_rejected`, `:artifact_written`, `:integrity_violation`) to `Kiln.Audit.EventKind`. The Ecto.Enum validation accepts them. But INSERT hits Postgres's `audit_events_event_kind_check` CHECK constraint built in migration `20260418000003` from the original 22 kinds → `Postgrex.Error` with SQLSTATE `23514` (`check_violation`).

**Why it happens:** The CHECK constraint was generated at migration time from `EventKind.values_as_strings()`, not dynamically at INSERT time. Changing the Elixir list alone isn't enough.

**How to avoid:** Ship a new migration that:
1. `execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")`
2. Re-generate the constraint from the NEW `EventKind.values_as_strings()` (25 kinds)
3. Reverse: drop 25-kind constraint, re-create 22-kind constraint

This is an owner-role operation (migrations run as `kiln_owner` per P1 D-48). Template matches `priv/repo/migrations/20260418000003` lines 49-58.

**Warning signs:**
- `append/1` returns `{:error, %Postgrex.Error{postgres: %{code: :check_violation}}}` for one of the three new kinds.
- A test that INSERTs a `:stage_input_rejected` event fails at the DB layer, not the changeset.

**[VERIFIED:** priv/repo/migrations/20260418000003_create_audit_events.exs:49-58]

### Pitfall 3: Hidden content-addressing loss via cross-filesystem rename

**What goes wrong:** Operator configures `priv/artifacts/tmp/` to live on tmpfs (fast) and `priv/artifacts/cas/` on APFS/ext4. `File.rename/2` falls back to copy-then-unlink, which is NOT atomic. A crash mid-copy leaves a partial file at the final CAS path that appears fully written but has the wrong sha — and CAS's integrity-on-read catches this only at next `read!/1`.

**Why it happens:** `rename(2)`'s atomicity guarantee is filesystem-local. `:file.rename/2` silently falls back to copy+unlink across devices, losing the guarantee.

**How to avoid:** Document loudly in `config/runtime.exs` or `CLAUDE.md` that `@tmp_root` and `@cas_root` MUST be on the same filesystem. BootChecks could add a 6th invariant: both paths resolve to the same `stat.st_dev` — cheap to verify once at boot. Alternative: use `:file.rename` manually and raise if it returns `{:error, :exdev}` (cross-device error code).

**Warning signs:**
- `Kiln.Artifacts.read!/1` raises `CorruptionError` on a blob that was just written.
- `priv/artifacts/cas/**` file count grows faster than unique `(stage_run_id, name)` pairs would predict.

**[CITED:** POSIX `rename(2)`; Elixir's `File.rename/2` docs: "if the rename fails because source and destination are on different filesystems, a copy + remove fallback is performed, which is NOT atomic."]

### Pitfall 4: `:digraph` ETS table leaks in test suites

**What goes wrong:** `:digraph.new/0` allocates three ETS tables. Without `:digraph.delete/1`, each call leaks 3 tables. A test suite that exercises 500 topological sorts leaks 1500 tables; eventually ETS exhaustion crashes the node.

**Why it happens:** `:digraph` is ETS-backed (named tables with non-GC'd state). Closing it requires explicit `delete/1`.

**How to avoid:** Always wrap in `try/after` with `:digraph.delete(g)` in the `after`. Same as `:ets.delete/1` discipline. Pattern in Pattern 3 above is the minimum.

**Warning signs:**
- `:ets.info()` shows growing table count during test runs.
- Mysterious `:system_limit` crashes in long CI runs.

**[CITED:** [erlang.org digraph(3) docs](https://www.erlang.org/doc/apps/stdlib/digraph.html): "A digraph is a mutable data structure. It must be destroyed by calling `delete/1` to reclaim memory."]

### Pitfall 5: `{:discard, reason}` used instead of `{:cancel, reason}` in StageWorker

**What goes wrong:** A plan writes `{:discard, {:stage_input_rejected, err}}` following older tutorials. Oban 2.21 emits a deprecation warning but still honors the return; in 2.22+ it may break outright. Worse, D-76 explicitly specifies `{:cancel, ...}` for audit-visibility semantics.

**Why it happens:** `{:discard, ...}` was the older API; `{:cancel, ...}` replaced it with clearer semantics (job marked `cancelled`, audit-visible, no retry/backoff storm).

**How to avoid:** Always use `{:cancel, reason}` for "abort this job with auditable reason." Use `{:error, reason}` for "retry this job with backoff." [VERIFIED: deps/oban/lib/oban/worker.ex:371-386]

### Pitfall 6: `Logger.metadata` correlation_id lost on process boundary (Oban/Task)

**What goes wrong:** Stage dispatch code enqueues an Oban job with correlation_id in `Logger.metadata`. The Oban worker runs in a different process — its `Logger.metadata` is empty. Audit events written by that worker's `transition/3` call use a freshly-generated UUID for correlation_id, breaking the causal chain.

**Why it happens:** Logger metadata is per-process. Oban copies job args but not Logger metadata.

**How to avoid:** Every Oban `perform/1` MUST call `Kiln.Telemetry.unpack_ctx/1` on `args["ctx"]` to restore correlation_id/run_id/stage_id/causation_id into `Logger.metadata` at the start of the function. Every enqueue MUST include `ctx: Kiln.Telemetry.pack_ctx()`. Phase 1 already shipped these helpers [VERIFIED: P1 Plan 01-05 decisions in `.planning/STATE.md`]; Phase 2 workers follow the same pattern.

### Pitfall 7: P4 token bloat via naive "accumulate all prior stage outputs as context"

**What goes wrong:** Stage B receives A's output; stage C receives A+B; by stage G, the prompt is 40k tokens.

**Why it happens:** Handler code passes full artifact bodies into subsequent stages.

**How to avoid in Phase 2:** D-75's `artifact_ref` sub-schema means every cross-stage reference carries only `{sha256, size_bytes, content_type}` — never raw bytes. Stage-input contracts (D-74) enforce this at the JSV validation step. If a stage-input envelope contains a raw body instead of an `artifact_ref`, JSV rejects it before the agent sees it. **The schema IS the enforcement.**

**Warning signs:**
- Any stage-input envelope containing a `content` or `body` field outside the `artifact_ref` schema.
- Prompt token counts growing more than linearly per stage in integration tests.

[CITED: PITFALLS.md P4]

### Pitfall 8: Oban unique is insert-time ONLY; not execution-time serialization

**What goes wrong:** Two Oban jobs with the same `idempotency_key` are already in the queue (say, inserted just before P1's unique constraint was enabled). Both execute. The "unique" guard silently doesn't help.

**Why it happens:** Oban's unique check runs at `Oban.insert/2` time against existing job rows matching the key + states `[:available, :scheduled, :executing]`. Once a second job slipped through, it runs. [CITED: Oban docs on unique jobs]

**How to avoid:** Pair insert-time unique with handler-level dedupe (P1 pattern — `fetch_or_record_intent/2` + state assertion). Never rely on insert-time uniqueness alone for correctness; treat it as a hygiene layer. **This is exactly why ARCHITECTURE.md §9 calls out "three-layer defense in depth".**

### Pitfall 9: P1-shipped `StageWorker` signature drift via `use Kiln.Oban.BaseWorker, queue: :stages`

**What goes wrong:** A task writes the StageWorker as `use Oban.Worker, queue: :stages, max_attempts: 3` directly, skipping `BaseWorker`. The insert-time unique on `idempotency_key` doesn't kick in, and `fetch_or_record_intent/2` delegation is missing. Duplicate stage dispatches leak through.

**Why it happens:** `BaseWorker` is a macro; easy to forget when mimicking Oban docs.

**How to avoid:** Code review rule. `.credo.exs` could add a custom check: "No module with `@impl Oban.Worker` may `use Oban.Worker` directly; must `use Kiln.Oban.BaseWorker`." Phase 1 shipped two custom Credo checks already [VERIFIED: lib/kiln/credo/no_process_put.ex + no_mix_env_at_runtime.ex]; adding a third is cheap and enforces the invariant.

---

## Runtime State Inventory

**N/A — Phase 2 is a greenfield addition phase, not a rename/refactor phase.** Every piece of state Phase 2 introduces (`runs` table, `stage_runs`, `artifacts`, `priv/artifacts/cas/`, `priv/workflows/`, new audit kinds) is new. There is no prior state to migrate. The one migration concern (22 → 25 audit event kinds CHECK constraint, §Common Pitfall #2) is called out above.

---

## Code Examples

All examples below are pattern-verified against local `deps/` source; each cites its source line.

### Loading + validating a workflow YAML end-to-end

```elixir
# Usage:
{:ok, compiled} = Kiln.Workflows.load!("priv/workflows/elixir_phoenix_feature.yaml")
# compiled :: %Kiln.Workflows.CompiledGraph{
#   id: "elixir_phoenix_feature",
#   version: 1,
#   stages: [%Stage{id: "plan", kind: :planning, ...}, ...],
#   topological_order: ["plan", "code", "test", "verify", "merge"],
#   checksum: "a1b2c3..."   # sha256 of normalized YAML — stored on runs.workflow_checksum
# }
```

### Executing a guarded transition with full audit + PubSub

```elixir
# In Kiln.Stages.StageWorker.perform/1 after a stage completes:
case Kiln.Runs.Transitions.transition(run_id, :testing) do
  {:ok, run} ->
    # PubSub was already broadcast inside transition/3. Enqueue next stage.
    enqueue_next_stage(run, compiled_graph)
    :ok

  {:error, :illegal_transition} ->
    # Loud log; let Oban's backoff decide, but don't burn an attempt on
    # a legitimate "we're already past this state" retry of a duplicate.
    Logger.warning("illegal transition; likely duplicate", run_id: run_id)
    :ok

  {:error, :not_found} ->
    {:error, :not_found}
end
```

### Recovering a run after a BEAM kill (integration test recipe)

```elixir
# test/integration/rehydration_test.exs
test "run continues from last checkpoint after BEAM kill" do
  {:ok, run} = Kiln.Runs.start(workflow_id: "minimal_two_stage")

  # Run progresses to :planning
  perform_job(StageWorker, %{"run_id" => run.id, "stage_id" => "s1", ...})
  assert {:ok, %{state: :planning}} = Kiln.Runs.get(run.id)

  # Simulate crash: kill the subtree
  [{subtree_pid, _}] = DynamicSupervisor.which_children(Kiln.Runs.RunSupervisor)
  Process.exit(subtree_pid, :kill)

  # Simulate reboot: trigger RunDirector's periodic scan
  send(Kiln.Runs.RunDirector, :periodic_scan)

  # Eventually-consistent: wait briefly for respawn + continuation
  Process.sleep(100)

  # Assert the run progressed past the checkpoint — no duplicate audit
  # events, no duplicate stage_run rows, no duplicate external_operations.
  assert {:ok, %{state: state}} = Kiln.Runs.get(run.id)
  assert state in [:coding, :testing]  # should have moved past :planning

  audit_for_run = Kiln.Audit.replay(run_id: run.id)
  transitions =
    Enum.filter(audit_for_run, &(&1.event_kind == :run_state_transitioned))

  # Must have exactly one transition into :planning (not two — no dup work).
  assert Enum.count(transitions, &(&1.payload["to"] == "planning")) == 1
end
```

### Async scan pattern for `RunDirector.init/1`

Already shown in Pattern 6. Key invariant: `init/1` returns immediately (`{:ok, state}`); the scan runs in a self-cast (`send(self(), :boot_scan)`) so the supervisor boot sequence doesn't block on what could be a 10-second DB query when 50 active runs are in flight.

### Extending BootChecks with a 5th invariant

```elixir
# In lib/kiln/boot_checks.ex (addition in Phase 2):
defp check_workflow_schema_loads! do
  case Kiln.Workflows.SchemaRegistry.fetch(:workflow) do
    {:ok, %JSV.Root{}} ->
      :ok

    {:error, reason} ->
      raise Error,
        "priv/workflow_schemas/v1/workflow.json failed to load via JSV. " <>
        "Detail: #{inspect(reason)}. See D-63."
  end
end

# Add to run!/0 after check_audit_trigger_active!():
def run! do
  # ... existing checks ...
  check_workflow_schema_loads!()  # NEW: 5th invariant
  :ok
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` | `Repo.transact/2` | Ecto 3.12+ | `Repo.transaction/2` is deprecated; always prefer `transact` — the return semantics are cleaner (`{:ok, value}` on any return, automatic `{:error, reason}` rollback on error tuples, explicit `Repo.rollback/1` still works). [VERIFIED: deps/ecto/lib/ecto/repo.ex:2279] |
| `{:discard, reason}` / `:discard` in Oban workers | `{:cancel, reason}` | Oban 2.18+ | `{:discard, ...}` is deprecated; `{:cancel, ...}` is the modern non-retry exit path [VERIFIED: deps/oban/lib/oban/worker.ex:378-386]. |
| `assert_formats: true` in JSV | `formats: true` in JSV | JSV 0.17+ | CONTEXT.md D-63/D-100 use the old speculative name. Actual option is `formats: true` [VERIFIED: deps/jsv/lib/jsv.ex:116]. |
| `ex_json_schema` for Draft 4 | `JSV` for Draft 2020-12 | P1 locked | Already in use; mentioned here for posterity. |
| `Floki` for LiveView tests | `LazyHTML` | LiveView 1.1 | Phase 2 ships no LiveView; mention only for Phase 7 awareness. |
| `ex_docker_engine_api` via socket | `System.cmd("docker", ...)` | Phase 1 locked | Phase 2 has no sandbox; Phase 3 applies. |
| `:gen_statem` for run FSM | Ecto field + command module | Phase 1 locked | CLAUDE.md convention. |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `:digraph.new([:acyclic])` rejects cycle-inducing edges at `add_edge/3` time with `{:error, {:bad_edge, _}}`. | Pattern 3 | [CITED: erlang.org digraph docs] — behavior is documented but the precise error tuple shape is a minor cite risk; planner should verify in an iex spike before locking test assertions. |
| A2 | `File.rename/2` on macOS APFS between two subdirectories of `priv/artifacts/` is atomic (same filesystem). | Pattern 5 | [CITED] Planner should add a BootChecks probe: `stat(@tmp_root).st_dev == stat(@cas_root).st_dev`. Mitigates the cross-FS pitfall cleanly. |
| A3 | Oban 2.21 `perform_job/2` test helper fires the `[:oban, :job, :start]` telemetry event synchronously in the test process. | Validation Architecture | [VERIFIED: Phase 1 Plan 01-05 decisions — P1 already proved this in `deps/oban/lib/oban/queue/executor.ex:97`.] |
| A4 | Handler-level dedupe via `fetch_or_record_intent/2` is sufficient for ORCH-07's "exactly one completion" guarantee. | §Phase Requirements, §Pattern 7 | [VERIFIED: P1 shipped this pattern; ARCHITECTURE.md §9 layer 2 is the canonical reference.] |
| A5 | `JSV.normalize_error/1` produces a JSON-serializable map suitable for audit-event payloads. | Pattern 2 | [VERIFIED: deps/jsv/lib/jsv.ex:317-339] — returns a map; planner should confirm shape matches the `stage_input_rejected.json` schema that P2 ships. |
| A6 | Writing a 50 MB artifact chunked through `File.stream!` with default chunk size is sub-second on commodity laptops. | Pattern 5, §Don't Hand-Roll | [ASSUMED] — benchmark in an integration test; if measurably slow, increase `File.stream!` chunk to 64KB. |
| A7 | A single `:digraph` created + deleted per `compile/1` call is cheap at workflow scale (5-20 stages). | Pattern 3 | [ASSUMED] — `:digraph` is ETS-backed; creation is ~3 ETS inserts. Workflow-scale cost is microseconds. Safe assumption. |
| A8 | `Oban.Plugins.Cron` supports passing `queue: :maintenance` as a third-element option in the crontab tuple. | Pattern 8, config | [VERIFIED: deps/oban/lib/oban/plugins/cron.ex:17-22 — `{cron, worker, [Job.option()]}` is the canonical tuple form; `queue:` is a `Job.option`.] |
| A9 | `Phoenix.PubSub.broadcast/3` on a topic with zero subscribers is a no-op (returns `:ok`, costs ~0). | Pattern 4, Pattern 6 | [CITED: phoenix_pubsub source — broadcast dispatches to registry; empty registry = no work. Safe.] |
| A10 | Postgres 16 `FOR UPDATE` on a row that doesn't exist returns zero rows (not an error); Ecto `Repo.one` returns `nil`. | Pattern 4 | [CITED: Postgres SELECT docs; Ecto behavior.] |

**If this table is empty:** N/A — it's populated. Items A1, A6, A7 are the softest and warrant iex spikes before locked plan decisions.

---

## Open Questions

1. **Should `Kiln.Artifacts.GcWorker` use Oban Cron or GenServer `Process.send_after`?**
   - What we know: D-83 says "scheduled-but-no-op in P2, filled in P5"; CONTEXT.md "Claude's Discretion" explicitly leaves this open.
   - What's unclear: Oban Cron gives durability, Web visibility, and retries for free. `Process.send_after` is simpler but doesn't survive a BEAM restart cleanly.
   - Recommendation: **Use Oban Cron.** Matches the pattern for `Kiln.ExternalOperations.Pruner` (P1 already uses Cron). Lower surface area; one pattern, not two.

2. **Should Phase 1's `Kiln.Audit.SchemaRegistry` be retroactively updated to pass `formats: true`?**
   - What we know: P1 shipped without it; P2 plans to use `formats: true` for workflow + stage-contract registries.
   - What's unclear: Is the inconsistency worth a one-line fix in P2?
   - Recommendation: **Yes — fix in P2 as part of D-100's STACK.md update.** Trivial change; aligns P1 and P2 schema registries; no compile error (JSV 0.18 accepts `formats: nil` which is the current implicit default).

3. **Does `RunDirector` need a supervisor-level `max_restarts: 0` like ARCHITECTURE.md §5 states for `RunSupervisor`?**
   - What we know: D-96 says `RunDirector` is stateless — any crash rebuilds from Postgres on init. Standard `:permanent + one_for_one` under root.
   - What's unclear: Whether `RunSupervisor`'s `max_restarts: 0` (ARCHITECTURE.md line 218) applies in P2 or is a §5 artifact to update.
   - Recommendation: `max_restarts: 0` on `RunSupervisor` makes sense — we never want the DynamicSupervisor itself restarting a dead per-run subtree; `RunDirector`'s `{:DOWN, ...}` path decides whether to respawn. Keep §5's guidance; encode in D-95 child spec.

4. **How should the minimal two-stage fixture look?**
   - What we know: D-64b says "2 stages, both pass-through, one edge."
   - What's unclear: Do both stages need to exercise the artifact-write path, or is one minimal enough?
   - Recommendation: One stage writes an artifact, the downstream stage references it via `artifact_ref`. This tests the P19 content-addressing path in the simplest possible way. Avoids building an integration test that needs the realistic 5-stage workflow just to test artifact handoff.

5. **Is there a way to assert the D-62 Elixir-side validators without running them through the full loader?**
   - What we know: D-62 lists 6 validators that run after JSV.
   - What's unclear: Whether each validator is a separate public function (testable in isolation) or embedded in the compiler pipeline.
   - Recommendation: **Separate public functions** in `Kiln.Workflows.Compiler` — `assert_single_entry/1`, `assert_dag/1`, `assert_deps_resolve/1`, `assert_on_failure_ancestors/1`, `assert_stage_contracts_exist/1`, `assert_signature_null/1`. Unit-testable; composable via `with`. Keeps the loader pipeline readable.

---

## Environment Availability

Phase 2 has **no new external dependencies** beyond what Phase 1 already probed. Every tool needed is already verified as available:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Postgres 16 (via Docker Compose or local) | Runs/StageRuns/Artifacts migrations | ✓ (P1 verified) | 16.x | Use `pg_uuidv7` fallback via kjmph pure-SQL (already shipped P1 D-06) |
| Elixir 1.19.5 / OTP 28.1+ | All BEAM code | ✓ | 1.19.5-otp-28 | None — pinned |
| Docker (for compose-up dev workflow) | Integration tests against real Postgres | ✓ (P1 verified) | 24+ | None |
| `priv/artifacts/cas/` and `priv/artifacts/tmp/` on same filesystem | Atomic rename | Assumed same FS on laptop | — | BootChecks probe (recommended; see A2) |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

Phase 2 honors `workflow.nyquist_validation` (implicit `true` in `.planning/config.json` — not explicitly false).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19 stdlib) + Oban.Testing + Ecto.Adapters.SQL.Sandbox + Mox + StreamData |
| Config file | `test/test_helper.exs` (already exists); `test/support/{data_case,audit_ledger_case}.ex` shipped P1 |
| Quick run command | `mix test --exclude integration` |
| Full suite command | `mix test` (includes `test/integration/*`) |
| Test DB setup | `KILN_DB_ROLE=kiln_app MIX_TEST_PARTITION=1 mix ecto.migrate` (already wired in `config/runtime.exs` + `.github/workflows/ci.yml`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-01 | Valid YAML passes JSV + DAG validators | unit | `mix test test/kiln/workflows/loader_test.exs -x` | ❌ Wave 0 |
| ORCH-01 | Malformed YAML rejects at load with clear error; zero DB writes | unit | `mix test test/kiln/workflows/loader_test.exs --only malformed -x` | ❌ Wave 0 |
| ORCH-01 | Cyclic workflow rejects with `:cycle` error; zero DB writes | unit | `mix test test/kiln/workflows/graph_test.exs --only cycle -x` | ❌ Wave 0 |
| ORCH-01 | JSON Schema 2020-12 conformance: `format: "uri"` enforced | unit | `mix test test/kiln/workflows/schema_registry_test.exs -x` | ❌ Wave 0 |
| ORCH-02 | Per-run subtree under RunSupervisor; child crash isolates | integration | `mix test test/integration/run_subtree_crash_test.exs -x` | ❌ Wave 0 |
| ORCH-02 | DynamicSupervisor respects `max_children: 10` | integration | `mix test test/kiln/runs/run_supervisor_test.exs --only max_children -x` | ❌ Wave 0 |
| ORCH-03 | Transition matrix closure: every path from :queued reaches a terminal | property | `mix test test/kiln/runs/transitions_test.exs --only property -x` | ❌ Wave 0 |
| ORCH-03 | Every transition writes audit event in same tx; rollback on audit failure | unit | `mix test test/kiln/runs/transitions_test.exs --only transactional -x` | ❌ Wave 0 |
| ORCH-03 | Illegal transition returns `{:error, :illegal_transition}` (not raise) | unit | `mix test test/kiln/runs/transitions_test.exs --only illegal -x` | ❌ Wave 0 |
| ORCH-03 | `transition!/3` raises `IllegalTransitionError` with locked message template | unit | `mix test test/kiln/runs/illegal_transition_error_test.exs -x` | ❌ Wave 0 |
| ORCH-03 | PubSub broadcast fires AFTER commit; never on rollback | unit | `mix test test/kiln/runs/transitions_test.exs --only pubsub -x` | ❌ Wave 0 |
| ORCH-03 | StuckDetector.check/1 is invoked inside the transaction before state update | unit | `mix test test/kiln/policies/stuck_detector_test.exs -x` | ❌ Wave 0 |
| ORCH-04 | BEAM kill mid-stage + reboot → one completion row; run continues | integration | `mix test test/integration/rehydration_test.exs -x` | ❌ Wave 0 |
| ORCH-04 | Workflow checksum mismatch on rehydration → escalate with typed reason | integration | `mix test test/integration/rehydration_test.exs --only checksum_drift -x` | ❌ Wave 0 |
| ORCH-04 | `Artifacts.put/3` streams SHA-256, atomic rename, inserts row + audit | unit | `mix test test/kiln/artifacts_test.exs -x` | ❌ Wave 0 |
| ORCH-04 | `Artifacts.read!/1` raises `CorruptionError` on sha mismatch | unit | `mix test test/kiln/artifacts/cas_test.exs --only corruption -x` | ❌ Wave 0 |
| ORCH-04 | CAS dedup: writing same bytes twice produces one blob, two rows | unit | `mix test test/kiln/artifacts/cas_test.exs --only dedup -x` | ❌ Wave 0 |
| ORCH-07 | StageWorker: kill between intent and completion → exactly one completion | integration | `mix test test/integration/idempotency_test.exs -x` | ❌ Wave 0 |
| ORCH-07 | Every Phase 2 worker `use Kiln.Oban.BaseWorker` (Credo check) | static | `mix credo --strict` | ❌ Wave 0 (new Credo check) |
| ORCH-07 | `idempotency_key` conforms to D-70 canonical shapes per worker kind | unit | `mix test test/kiln/stages/stage_worker_test.exs --only idempotency_key_shape -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test --exclude integration --exclude property` (fast lane — ~5 seconds).
- **Per wave merge:** `mix check` (the P1-locked 12-tool gate: format, compile-warnings-as-errors, credo, dialyzer, xref, mix_audit, sobelow, ex_slop, `mix check_no_compile_time_secrets`, `mix check_no_signature_block` NEW in P2, `mix kiln.boot_checks`, full `mix test`).
- **Phase gate:** Full suite green + `mix test --include integration --include property`.

### Wave 0 Gaps

Tests and fixtures that must land before any stage-3+ work:

- [ ] `test/support/fixtures/workflows/minimal_two_stage.yaml` — D-64b fixture
- [ ] `priv/workflows/elixir_phoenix_feature.yaml` — D-64a canonical
- [ ] `priv/workflow_schemas/v1/workflow.json` — D-66 top-level dialect
- [ ] `priv/stage_contracts/v1/{planning,coding,testing,verifying,merge}.json` — D-73/D-74
- [ ] `priv/audit_schemas/v1/{stage_input_rejected,artifact_written,integrity_violation}.json` — D-85
- [ ] `test/support/run_case.ex` — shared setup: `Ecto.Adapters.SQL.Sandbox` + `Oban.Testing` with `testing: :manual`
- [ ] Migration `20260419000001_extend_audit_event_kinds.exs` — 22 → 25 kinds
- [ ] Migration `20260419000002_create_runs.exs`
- [ ] Migration `20260419000003_create_stage_runs.exs`
- [ ] Migration `20260419000004_create_artifacts.exs`
- [ ] New Credo check `Kiln.Credo.UseOfObanBaseWorker` (gates §Common Pitfall #9)
- [ ] Framework install: none needed (all deps pinned in P1 `mix.exs`)

### Property-Based Invariants to Test

Worth StreamData coverage:

1. **Transition closure:** `forall state ∈ @any_state, forall to ∈ legal(state): transition(run, to) succeeds iff to ∈ allowed(state)` — generates run rows with random valid state, asserts `transition/3` only succeeds on D-87 matrix edges.
2. **Artifact dedup:** `forall (bytes1, bytes2): if sha256(bytes1) == sha256(bytes2), put(..., bytes1) and put(..., bytes2) produce the same CAS path` — trivially true by construction but tests the filesystem layer.
3. **Idempotency:** `forall (run_id, stage_id): perform_job(StageWorker, args) twice produces one stage_run and one stage_completed audit event` — generates dup args, asserts single completion.
4. **Graph ordering:** `forall valid DAG G: topological_sort(G) produces a list where every stage appears after all its depends_on entries` — generates random DAGs with StreamData, asserts the ordering invariant.

---

## Security Domain

Phase 2 is explicit per CLAUDE.md: `security_enforcement` is enabled (absent from `.planning/config.json` = enabled). ASVS 5.0 applicability for this phase:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 2 has no auth surface (solo-op; no login until v2 TEAM-*) |
| V3 Session Management | no | Same |
| V4 Access Control | no | Same |
| V5 Input Validation | **yes** | **JSV 0.18 at every data boundary** — workflow YAML load, stage-input envelope, audit-event payload. Every external input passes through a pinned Draft 2020-12 schema before reaching business logic. `additionalProperties: false` is the default posture. |
| V6 Cryptography | **yes** | **SHA-256 via `:crypto` stdlib** for CAS integrity. Never hand-roll. Never use `:md5` or `:sha1` — Phase 1 already establishes SHA-256 as the Kiln canonical hash. |
| V7 Error Handling | yes | Errors normalized via `JSV.normalize_error/1` at boundary; no raw JSV tuples reach audit log or UI. |
| V8 Data Protection | partial | `priv/artifacts/cas/` is gitignored (D-83); no secrets in artifacts (a Phase 3 concern; P2 contracts forbid secret fields at the stage-input schema level). |
| V9 Communications | no | No network surface in Phase 2 (LLM adapter is Phase 3). |
| V12 API & Web Services | no | No HTTP endpoints in Phase 2. |
| V14 Config | yes | `config/runtime.exs` reads env vars; `pool_size` raised; no compile-time secrets (P1's `mix check_no_compile_time_secrets` covers). |

### Known Threat Patterns for Phase 2 Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious YAML with atom keys → atom-table exhaustion | Denial of Service | `yaml_elixir` default string keys; never pass `atoms: true` on external input. [D-63] |
| Malicious YAML with infinite recursion via anchors | DoS | yamerl handles anchor depth; JSV Draft 2020-12 has `maxDepth` implicitly via `$defs` cycle detection. Audit schemas are fixed at compile time. |
| SQL injection via workflow `id` field | Tampering | `id` pattern `^[a-z][a-z0-9_]{2,63}$` enforced at schema level; Ecto parameterized queries everywhere else. |
| Path traversal via artifact `name` field | Tampering | `name` field in `stage_contracts/v1/*.json` should constrain to `^[a-zA-Z0-9._-]+$`. CAS paths are derived from sha256 (no user input in path). |
| Hash collision causing CAS corruption | Tampering | SHA-256 is collision-resistant at cryptographic scale; integrity-on-read catches bit-flips. |
| Workflow file modified between run-start and rehydration | Tampering | D-94's workflow_checksum assertion escalates with `:workflow_changed`. |
| Unbounded artifact size → disk exhaustion | DoS | `size_bytes: 0..52428800` (50MB cap) in `artifact_ref` sub-schema (D-75); hard cap 50GB via `config :kiln, :artifacts, max_bytes` (D-83). |
| CAS tmp-dir fills disk via crashed writes | DoS | `Kiln.Artifacts.ScrubWorker` weekly (D-84) + rely on tmpfs eviction; add ENOSPC error path. |
| JSV schema injection via workflow `apiVersion` | Tampering | `apiVersion` is `const: "kiln.dev/v1"` — exact-value check; no resolver indirection. |

---

## Sources

### Primary (HIGH confidence)

- **Local dep sources** (frozen at `mix.lock`):
  - `deps/yaml_elixir/lib/yaml_elixir.ex:10-46` — `read_from_file/2`, `read_all_from_file/2`, option semantics
  - `deps/yaml_elixir/lib/yaml_elixir/mapper.ex:65-95` — `atoms`, `maps_as_keywords`, `merge_anchors` option handling
  - `deps/jsv/lib/jsv.ex:91-182` — `@build_opts_schema` NimbleOptions: `resolver`, `default_meta`, `formats`, `vocabularies`
  - `deps/jsv/lib/jsv.ex:240-339` — `build/2`, `build!/2`, `validate/3`, `validate!/3`, `normalize_error/2`
  - `deps/oban/lib/oban/worker.ex:371-386` — `{:cancel, ...}` / `{:discard, ...}` deprecation
  - `deps/oban/lib/oban/plugins/cron.ex` — crontab tuple shape `{expr, worker}` or `{expr, worker, opts}`
  - `deps/oban/lib/oban/plugins/pruner.ex` — `:max_age`, `:interval`, `:limit` options
  - `deps/oban/lib/oban.ex:830-914` — `drain_queue/2` semantics, `with_scheduled`, `with_recursion`, `with_safety`
  - `deps/oban/lib/oban/testing.ex:131-291` — `perform_job/2,3`, `:manual` vs `:inline` test mode
  - `deps/ecto/lib/ecto/repo.ex:2279-2503` — `Repo.transaction/2` deprecation; `Repo.transact/2` semantics
  - `deps/phoenix_pubsub/lib/phoenix/pubsub.ex:229-260` — `broadcast/3,4`, `broadcast_from/4,5`
- **Phase 1 shipped source** (Kiln own code):
  - `lib/kiln/audit/schema_registry.ex` — compile-time JSV build template
  - `lib/kiln/oban/base_worker.ex` — macro + insert-time unique config
  - `lib/kiln/external_operations.ex` — two-phase intent-action-completion pattern
  - `lib/kiln/boot_checks.ex` — staged boot invariants; SAVEPOINT probe pattern
  - `lib/kiln/application.ex` — staged start (infra → BootChecks → Endpoint)
  - `priv/repo/migrations/20260418000003_create_audit_events.exs` — CHECK constraint generation pattern
- **Phase 1 CONTEXT.md** decisions D-01..D-53 (esp. D-06, D-09, D-12, D-18, D-42, D-44, D-48)
- **Phase 2 CONTEXT.md** decisions D-54..D-100 (all consumed above)
- **erlang.org**: [digraph(3)](https://www.erlang.org/doc/apps/stdlib/digraph.html), [digraph_utils(3)](https://www.erlang.org/doc/apps/stdlib/digraph_utils.html), [crypto(3)](https://www.erlang.org/doc/apps/crypto/crypto.html), [file(3)](https://www.erlang.org/doc/apps/kernel/file.html) — topological sort, SHA-256 streaming, `rename/2` semantics

### Secondary (MEDIUM confidence)

- [Oban 2.21 hexdocs — Unique Jobs](https://hexdocs.pm/oban/unique-jobs.html) — "insert-time only" semantics
- [Brandur: Idempotency Keys](https://brandur.org/idempotency-keys) — the INSERT ... ON CONFLICT DO NOTHING + SELECT FOR UPDATE pattern
- [Phoenix 1.8 hexdocs — Phoenix.PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) — broadcast semantics
- [Ecto 3.13 hexdocs — Ecto.Multi, Ecto.Repo.transact](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transact/2)
- [JSV 0.18 hexdocs](https://hexdocs.pm/jsv) — Draft 2020-12, format validators, resolver chain

### Tertiary (LOW confidence — not actually used, listed for planner awareness)

None — every claim above is either verified in local source or cited to a canonical doc.

---

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — every library API verified against local `deps/` source or Phase 1 shipped code.
- Architecture patterns: **HIGH** — every pattern mirrors Phase 1's shipped precedent.
- Pitfalls: **HIGH** — 3 pitfalls verified against local deps; others cite canonical OTP/Postgres docs.
- API API correction risk: **MEDIUM** — `formats: true` vs `assert_formats: true` is a real CONTEXT.md error that could propagate into plan text if the planner doesn't catch it. Flagged up front in §Summary.
- Migration correction risk: **HIGH** — Phase 1's 22-kind CHECK constraint MUST be extended via a new migration. If the planner treats this as "just update the Ecto.Enum list", the system will ship broken. Flagged loudly in §Common Pitfall #2 and §Wave 0 Gaps.

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (30 days — stack is stable; pinned deps unchanged since P1)

---

## RESEARCH COMPLETE

Summary of sections:

1. **User Constraints** — D-54..D-100 locked; Claude's Discretion enumerated; deferred items out of scope
2. **Phase Requirements** — ORCH-01..ORCH-04 + ORCH-07 mapped to research support
3. **Project Constraints (CLAUDE.md)** — all actionable directives extracted, including the `ARCHITECTURE.md §5 Run.Server drift` flag
4. **Architectural Responsibility Map** — Phase 2 is entirely API/Backend tier
5. **Standard Stack** — yaml_elixir, JSV, Oban, Ecto, `:digraph`, `:crypto`, Phoenix.PubSub — all verified
6. **Architecture Patterns** — 8 concrete patterns with verified code examples: compile-time JSV, loader pipeline, `:digraph` topsort, `Repo.transact` + `FOR UPDATE` + Audit + post-commit PubSub, CAS streaming+rename, RunDirector monitor+periodic scan, canonical idempotency keys, Oban config
7. **Don't Hand-Roll** — 12 items mapped to existing libs
8. **Common Pitfalls** — 9 pitfalls specific to Phase 2 implementation (PubSub-in-tx, 22-kind CHECK, cross-FS rename, `:digraph` leaks, `{:discard}` deprecation, Logger.metadata on Oban boundary, P4 token bloat, insert-time-only unique, BaseWorker bypass)
9. **Code Examples** — verified snippets for loader, transition, rehydration test, BootChecks extension
10. **State of the Art** — Ecto `transact` vs `transaction`, Oban `{:cancel}` vs `{:discard}`, JSV `formats` vs `assert_formats`
11. **Assumptions Log** — 10 assumptions, 3 marked as iex-spike-worthy
12. **Open Questions** — 5 questions with recommendations
13. **Environment Availability** — no new deps
14. **Validation Architecture** — full test map, sampling rates, Wave 0 gaps, property-based invariants
15. **Security Domain** — ASVS applicability (V5 + V6 primary), threat patterns + mitigations

**Key corrections surfaced (before they become bugs):**
- JSV option is `formats: true`, not `assert_formats: true` (CONTEXT.md D-63/D-100 are imprecise)
- yaml_elixir has no `atoms: false` — it's `atoms: true` as the opt-in
- Phase 1's 22-kind audit CHECK constraint requires a new migration to accept D-85's 3 new kinds
- `Kiln.Audit.SchemaRegistry` currently ships without `formats: true`; P2 should retroactively add it
- ARCHITECTURE.md §5 `Run.Server` GenServer is superseded by CONTEXT.md D-92..D-96 `RunDirector` pattern — D-98 should update §5

**Ready for planning:** Planner can now turn this into concrete plans (expected ~8-10 plans: schemas+migrations, workflow loader, transitions, supervision tree, artifacts, Oban config, boot-checks extension, fixtures+realistic workflow, plus Phase-2 spec-upgrade plan for D-97..D-100).
