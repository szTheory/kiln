# Phase 2: Workflow Engine Core - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

A YAML workflow file loaded from `priv/workflows/*.yaml` parses, passes JSV Draft 2020-12 schema validation at load time (cyclic or malformed input halts with zero partial state persisted), and compiles into a topologically-sorted `CompiledGraph` struct. Starting a run inserts a `runs` row in `:queued`, then transitions through the state machine `queued → planning → coding → testing → verifying → (merged | failed | escalated)` (plus `:blocked` wired for Phase 3) where every transition opens `Repo.transact`, takes `SELECT … FOR UPDATE` on the run row, asserts the allowed-edge guard, updates state + writes an `Audit.Event` in the same transaction, and broadcasts on `Kiln.PubSub`. Killing the BEAM mid-stage and rebooting: `Kiln.Runs.RunDirector` re-hydrates per-run supervisor subtrees from Postgres (active-state scan + `{:DOWN, ...}` reactive + 30-second defensive periodic scan) and the run continues from its last committed checkpoint. Every external-side-effect stub (LLM stub, git stub, Docker stub) writes a two-phase `external_operations` row (`intent_recorded → action_in_flight → completed|failed|abandoned`); killing between intent and action and retrying produces exactly one completion row (handler-level `SELECT ... FOR UPDATE` + state assertion, backed by insert-time Oban unique + `Kiln.Oban.BaseWorker` macro shipped in P1). Stage input-contracts (JSV Draft 2020-12 schemas at `priv/stage_contracts/v1/<kind>.json`, compile-time-built into `Kiln.Stages.ContractRegistry`) validate at the stage boundary before any agent is invoked; invalid inputs reject as `{:cancel, {:stage_input_rejected, err}}` with a new audit event kind — the agent never sees malformed input (P4 token-bloat defence). Artifacts (diffs, logs, plans, test output) land in a new 13th bounded context `Kiln.Artifacts` as **content-addressed storage** at `priv/artifacts/cas/<sha[0..1]>/<sha[2..3]>/<sha>` with an `artifacts` Ecto lookup table mapping `(stage_run_id, name) → sha256` — immutability, integrity-on-read, and dedup on deterministic retries are structural. Oban queue taxonomy locks at **six per-concern queues** (`:default 2, :stages 4, :github 2, :audit_async 4, :dtu 2, :maintenance 2`, aggregate 16); the Repo pool raises to 20 to accommodate. Provider-split queues defer to Phase 3 with a hard trigger. Workflow signing defers to v2 (WFE-02) with a reserved `signature: null` top-level key + `mix check_no_signature_block` CI guard. `Kiln.Policies.StuckDetector` ships as a no-op GenServer whose `check/1` hook fires inside `Kiln.Runs.Transitions.transition/3` after the row lock and before the state update — Phase 5 fills in the sliding-window body without touching any caller. Phase 2 ships one realistic workflow (`priv/workflows/elixir_phoenix_feature.yaml`) plus one minimal two-stage test fixture, two new Ecto schemas (`Run`, `StageRun`), the `Kiln.Artifacts` context (13th), the `RunDirector`/`RunSupervisor`/`StuckDetector` supervision-tree additions (supervision-tree child count moves from 7 to 10, re-locked), and a CLAUDE.md spec upgrade admitting the 13th context.

Workflow YAML syntax details, per-provider adapter code, Docker sandbox internals, real LLM/git/gh workers, the scenario runner, the LiveView UI, onboarding, and the full bounded-autonomy cap enforcement all belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Workflow YAML Dialect & Schema (Phase 2 canonical shape)

- **D-54:** Dialect = **Temporal/Argo-inspired flat `stages: [...]` array with `depends_on: [id]` edges**. Not a `jobs.<id>:` map (GitHub Actions' `${{ }}` expression language is a parser nightmare and every `if:` is a CVE-class injection waiting to happen); not a `Pipeline`/`PipelineRun`/`Task`/`TaskRun` 4-kind split (Tekton/Argo overengineering for solo-op; Ecto already owns the execution half). Elixir ecosystem tell: Oban.Workflow, Ash.Flow, and Commanded all model DAGs as data structures; Broadway's DSL is for streaming, not durable jobs — wrong primitive. Operator reads top-to-bottom like a recipe.
- **D-55:** Top-level workflow keys: `apiVersion: kiln.dev/v1` (migration lever — const-checked), `id` (`^[a-z][a-z0-9_]{2,63}$`, Postgres-identifier-safe), `version` (monotonic integer; composite key `{id, version}`), `metadata` (description/author/tags — free-form), `signature: null` (reserved for v2 WFE-02 per D-65; CI guard blocks population), `spec` (envelope containing `caps`, `model_profile`, `stages`).
- **D-56:** `spec.caps` (required, `additionalProperties: false`): `max_retries` (integer), `max_tokens_usd` (number — USD; operators speak dollars), `max_elapsed_seconds` (wall-clock from queued → terminal), `max_stage_duration_seconds` (single-stage timeout backstop). These are hard caps enforced in Phase 5 but declared at schema level in P2 so the contract locks early.
- **D-57:** `spec.model_profile` (required): enum `{elixir_lib, phoenix_saas_feature, typescript_web_feature, python_cli, bugfix_critical, docs_update}` — matches `Kiln.ModelRegistry.profiles/0` (schema is source of truth; Phase 3 codegens Elixir enum from JSON Schema on boot to prevent drift).
- **D-58:** `stages[]` required fields: `id` (unique within workflow, `^[a-z][a-z0-9_]{1,31}$`), `kind` (enum `{planning, coding, testing, verifying, merge}` — determines stage-contract ref via `priv/stage_contracts/v1/<kind>.json`), `agent_role` (enum `{planner, coder, tester, reviewer, uiux, qa_verifier, mayor}` — determines which `Kiln.Agents.SessionSupervisor` child handles the invocation; P10: ROLES, not model IDs), `depends_on` (`[string]`, empty ⇒ entry node; exactly one entry node required), `timeout_seconds` (integer 10..3600), `retry_policy` (object with `max_attempts` 1..5, `backoff` enum `{fixed, exponential}`, `base_delay_seconds` 0..300), `sandbox` (enum `{none, readonly, readwrite}`).
- **D-59:** `stages[]` optional fields: `model_preference` (string — overrides `model_profile`'s role binding for this stage only; ModelRegistry resolves at invocation time), `on_failure` (either `const: escalate` or structured `{action: route, to: <ancestor-id>, attach: <artifact-key>}` — **no string expression language**, EVER; forward edges and non-ancestor targets are rejected at load time).
- **D-60:** `kind` is the stage-contract reference. No separate `input_contract:` field — the `kind` resolves to `priv/stage_contracts/v1/<kind>.json` automatically. Dropped because it was strictly redundant (one kind → one contract) and eliminated a correctness-by-consistency risk.
- **D-61:** `kind` and `agent_role` are **separate axes**. Most of the time they align 1:1 (coding → coder), but the `merge` stage uses `agent_role: coder` while `kind: merge`, and Phase 8 may introduce `uiux`-role stages with `coding`-kind contracts. Keep both.
- **D-62:** Elixir-side validators (JSV cannot express) run after JSV at `Kiln.Workflows.load!/1` boundary: (1) exactly one stage has `depends_on: []`; (2) `Kiln.Workflows.Graph.topological_sort/1` succeeds (DAG is acyclic); (3) every `depends_on` id resolves to a stage `id` in the same workflow; (4) every `on_failure.to` is a topological ancestor (prevents forward-edge infinite loops); (5) every `kind` has a matching file under `priv/stage_contracts/v1/`; (6) `signature` is `null` (v1 invariant).
- **D-63:** `yaml_elixir 2.12` loaded with `atoms: false` (hard rule — avoids atom-table exhaustion on malicious workflows). `JSV.build/2` with `assert_formats: true` so `"format": "uri"` and `"format": "uuid"` are actually enforced. Schema errors normalize through `JSV.normalize_errors/1` at the loader boundary — no raw JSV tuples reach the UI or audit log.
- **D-64:** Phase 2 ships **two** YAML files: (a) `priv/workflows/elixir_phoenix_feature.yaml` — the realistic 5-stage workflow (plan → code → test → verify → merge) that exercises every engine path the phase success criteria demand; (b) `test/support/fixtures/workflows/minimal_two_stage.yaml` — 2-stage pass-through fixture for unit tests. Shipping only one kind of fixture is a false economy: the realistic workflow proves the engine does its job; the minimal fixture keeps unit tests fast.
- **D-65:** **Workflow signing — defer to v2 (WFE-02).** Reasoning ranked: (1) Solo-op local-first means `priv/workflows/` IS the distribution channel — workflows live in the operator's own git repo; `git commit -S` + branch protection + `mix check` CI is a stronger chain-of-custody than in-YAML `signature:` would be. (2) sigstore/gitsign already solves "sign git commits with keyless sigstore" — duplicating it inside YAML is anti-DRY. (3) sigstore cosign targets OCI artifacts; shoehorning cosign for YAML is disproportionate. (4) GPG detached sigs force every contributor to have a GPG key configured; v1.1 multi-user work would then rip it out for sigstore anyway. (5) Requirements doc lists WFE-02 in v2. Phase 2 reserves a `signature: null` top-level key (schema field `"type": ["null", "object"], "x-kiln-reserved": true`) and ships `mix check_no_signature_block` (mirrors D-26 pattern) to fail CI if any v1 workflow populates it. Migration when WFE-02 lands is a value upgrade, not a schema migration.
- **D-66:** Schema files live at `priv/workflow_schemas/v1/workflow.json` (top-level dialect) and `priv/stage_contracts/v1/<kind>.json` (per-stage input contracts). Parallels Phase 1's `priv/audit_schemas/v1/<kind>.json` layout (D-09 precedent); consistent, discoverable, diffable.

### Oban Queue Taxonomy

- **D-67:** **Six per-concern queues, no per-provider split.** GitLab's published writeup on Sidekiq is the definitive counter-evidence that queue-per-worker-class is a trap (95% Redis CPU burn; Oban Web at `/ops/oban` becomes unreadable). OPS-02 adaptive fallback is Kiln's first-line defence against provider rate limits — queue segregation is second-line and solo-op never hits the trigger in Phase 2 (zero adapters live). Exact queues + concurrency:
  - `:default 2` — ad-hoc / one-offs / anything without an explicit queue. Deliberately small so a mis-routed `:stages` job shows up immediately as a `:default` backlog, not a silent slot-steal.
  - `:stages 4` — stage dispatch (`Kiln.Stages.StageWorker`). 4 = 2 parallel runs × 2 parallel stages, the solo-op ceiling.
  - `:github 2` — git / gh CLI shell-outs. Activated in Phase 6; scaffolded in P2.
  - `:audit_async 4` — non-transactional audit appends. Never queue; losing timeliness erodes the source-of-truth guarantee.
  - `:dtu 2` — DTU mock contract tests + health polls. Scaffolded in P2; activated in P3.
  - `:maintenance 2` — cron destinations: 30-day `external_operations` pruner (already shipped in P1 under this name), Phase 5 StuckDetector worker, Phase 3 DTU weekly contract test. One queue for every housekeeping concern so they never contend with `:stages`.
- **D-68:** **`pool_size: 20`** in `config/runtime.exs` (was 10 in P1 default). Budget: Oban aggregate 16 + plugin overhead 2 + LiveView/`/ops/*` queries ~2 + RunDirector+StuckDetector ~1 + request-spike headroom ~3 = ~24 total pressure, against 20 checkout slots. Defensible because `:stages` concurrency (4) is dominated by LLM-call wall-clock (minutes), not DB checkouts. Revisit to 28 when provider-split triggers in P3.
- **D-69:** Plugins: `{Oban.Plugins.Pruner, max_age: 60*60*24*7}` (OSS; prunes completed `oban_jobs` rows after 7 days — distinct from the P1 `external_operations` 30-day TTL pruner which is a worker) + `{Oban.Plugins.Cron, crontab: [...]}` (OSS). Cron entries for P1's `Kiln.ExternalOperations.PrunerWorker` (daily), Phase 5's StuckDetector worker (commented out until P5), Phase 3's DTU contract test (commented out until P3) — all route to `:maintenance`.
- **D-70:** **Idempotency-key canonical shape**: `idempotency_key` names the **business intent**, not the attempt number. Per-worker shapes:
  - Stage dispatch: `"run:#{run_id}:stage:#{stage_id}"` (attempt-independent; handler-level `SELECT ... FOR UPDATE` + `assert_state(:pending)` does the real dedup per ARCHITECTURE.md §9 Layer 2)
  - Run state transition (async): `"run:#{run_id}:transition:#{from}->#{to}"`
  - Audit append-async: `"audit:#{correlation_id}:#{event_kind}:#{sha256(payload)[0..15]}"` (content-addressed; retries collapse)
  - `external_operations` completion: `"extop:#{external_operation_id}"` (the intent row UUID IS the key)
  - Pruner (cron): `"pruner:external_operations:#{date_bucket}"`
  - Stuck-detector scan (P5): `"stuck_scan:#{minute_bucket}"` (5-minute tumbling window)
  - Git push / PR open (P6): `"run:#{run_id}:stage:#{stage_id}:git_push"` / `"run:#{run_id}:gh_pr:#{branch}"`
- **D-71:** **Provider-split defer trigger** (goes into Phase 3 CONTEXT.md): split `:stages` into `:stages_anthropic`/`:stages_openai`/`:stages_google`/`:stages_ollama` **if and only if** (a) two or more adapters are live, AND (b) a scenario test or dev-loop observation shows a 429 on one provider delaying a ready-to-dispatch stage on a different provider by > per-stage p95. At that point: 2 per provider queue, aggregate 8 replaces aggregate 4; bump `pool_size` to 28.
- **D-72:** No `:retries_backoff` queue (Oban's per-job `schedule_in` handles backoff). No `:priority` use in P2 (Oban's 0..3 per-job priorities are intra-queue; maps to nothing in solo-op).

### Stage Input-Contracts

- **D-73:** Stage input contracts ship as **external JSON Schema 2020-12 files at `priv/stage_contracts/v1/<kind>.json`**, compiled once into `Kiln.Stages.ContractRegistry` via `@external_resource` + compile-time `JSV.build!/2` (exact mirror of `Kiln.Audit.SchemaRegistry` shipped in P1). Boot stays fast; per-request validation is a microsecond cost. Not inline-in-YAML (makes workflow YAML unreadable, `$ref` across YAML sub-schemas doesn't work cleanly at speed). Not Elixir modules (the audit_schemas precedent is already JSON-on-disk; `gh repo view` + `diff` UX of reviewing a schema change stays clean).
- **D-74:** Input contracts validate a **tightly-bounded envelope**, not the raw artifact bodies. Required fields in every contract: `run_id` (uuid), `stage_run_id` (uuid), `attempt` (1..10), `spec_ref` (artifact ref), `budget_remaining` (usd/tokens/steps), `model_profile_snapshot` (role + requested_model + fallback_chain), `holdout_excluded: const true` (for non-Verifier stages — structural SPEC-04 provenance assertion). Kind-specific additions: `planning` adds `last_diagnostic_ref`; `coding` adds `plan_ref`; `testing` adds `code_ref`; `verifying` adds `test_output_ref`; `merge` adds `verifier_verdict_ref`.
- **D-75:** `artifact_ref` sub-schema (shared via `$defs`): `{sha256: ^[0-9a-f]{64}$, size_bytes: 0..52428800, content_type: enum {text/markdown, text/plain, application/x-diff, application/json, text/x-elixir}}` — every cross-stage reference carries sha + size + content-type (never raw bytes). Size cap (50 MB) is a hard rejection at the boundary; token-count pre-flight using the provider tokenizer is Phase 4.
- **D-76:** Validation fires inside `Kiln.Stages.StageWorker.perform/1` at stage-start, **before** any agent invocation or LLM call. Failure returns `{:cancel, {:stage_input_rejected, err}}` from the Oban worker (cancel, NOT discard — audit-visible, does not trigger Oban's retry/backoff storm per P9). A new audit event kind `:stage_input_rejected` (add to `Kiln.Audit.EventKind` + ship `priv/audit_schemas/v1/stage_input_rejected.json` in P2) is written. Run transitions to `:escalated` with `escalation_reason: :invalid_stage_input` — a boundary violation indicates a workflow or upstream-producer bug, not an operator remediation.

### Artifact Storage — `Kiln.Artifacts` Context (NEW 13th context)

- **D-77:** **Pure content-addressed storage** from day one. Path: `priv/artifacts/cas/<sha[0..1]>/<sha[2..3]>/<sha>` (two-level fan-out = 65,536 dirs; handles millions of blobs without ext4/APFS directory-size pathology). Blobs are mode 0444. Writes stage through `priv/artifacts/tmp/` then `rename(2)` into place — atomic on same fs, so a crashed write never leaves a half-blob at its final path. This is Bazel / Nix / Git / IPFS / Temporal BlobStore convergent design; P19 ROADMAP line "content-addressing groundwork" is the explicit mandate.
- **D-78:** **Rejected: path-based storage** (`priv/artifacts/<run_id>/<stage_id>/<attempt>/`). Reasoning: (1) SAND-04 mandates immutable diffs — CAS gives immutability structurally. (2) Durability-floor ethos requires integrity-on-read; path-based needs a separate `sha256` column to detect corruption → you pay the sha cost without getting dedup/immutability benefit. (3) Retried stages producing identical bytes become free dedup hits under CAS. (4) Future v2 object-storage migration is one `rsync` command for CAS; a hard rewrite for path-based. (5) P19 "groundwork" that isn't content-addressing isn't groundwork — it's a rewrite Phase 3 would have to do.
- **D-79:** New 13th bounded context `Kiln.Artifacts` under the Execution layer — NOT nested under `Kiln.Stages`. Storage is orthogonal to stage execution; the 12-context rule admits a 13th the moment CAS exists as a distinct concern. Requires CLAUDE.md spec upgrade (D-92 below).
- **D-80:** `Kiln.Artifacts` public API: `put/3` (streams body through `:crypto.hash_init(:sha256)` + `File.stream!` into `tmp/`, renames on success, inserts `Artifact` row in a single `Ecto.Multi` alongside the stage-completion audit event), `get/2` (`stage_run_id, name → {:ok, Artifact.t()} | {:error, :not_found}`), `read!/1` (re-hashes on every open, raises `Kiln.Artifacts.CorruptionError` on mismatch — durability-floor loud-on-violation), `stream!/1`, `ref_for/1` (returns `%{sha256, size_bytes, content_type}` — exact shape a stage-contract `artifact_ref` expects), `by_sha/1` (refcount / debug).
- **D-81:** `artifacts` Ecto schema: `id` (uuidv7 PK), `stage_run_id` (FK, `on_delete: :restrict`), `run_id` (FK, `on_delete: :restrict`), `name` (text — e.g., `"plan.md"`, `"diff.patch"`), `sha256` (text, 64 lowercase hex — CHECK constraint), `size_bytes` (bigint, CHECK ≥ 0), `content_type` (text — controlled vocab matching stage-contract enum), `schema_version` (integer), `producer_kind` (text — the stage kind that wrote it), `inserted_at` only. Indexes: `unique(stage_run_id, name)` (one name per attempt), `(run_id, inserted_at)`, `(sha256)` (refcount). Append-only semantically but NOT REVOKE-enforced; audit_events already owns that invariant.
- **D-82:** **Decision table — data shape → storage target**:
  - State-machine facts (`from`, `to`, `reason`), small structured summaries ≤ 4 KB, numeric metrics → `audit_events.payload` JSONB
  - Diff (any size), log output, test output, coverage reports, screenshots, plan markdown (uniformly, not size-conditional — keeps downstream refs homogeneous), any binary → `artifacts` CAS
  - Hot-path indexable metrics (`tokens_used`, `cost_usd`, `actual_model_used`) → dedicated columns on `stage_runs` / `runs` (NOT audit payload, NOT artifacts — too hot)
  - Spec body (markdown) → `specs` table column (intent layer, versioned, not execution output)
  - **Threshold rule**: `payload > 4 KB` OR binary OR content-type ∈ `{diff, log, test_output, coverage, markdown}` → artifact. Keeps `audit_events.payload` a thin fact record forever. This is the Airflow-XCom-in-metadata-DB footgun dodged structurally.
- **D-83:** **Retention policy** (activates in Phase 5; Phase 2 ships the worker stub):
  - `run.state = :merged`: keep plan, final diff, PR body, verifier verdict; GC intermediate attempt logs/test-outputs older than 7 days (GitHub owns the permanent record).
  - `run.state ∈ {:failed, :escalated}`: retain all artifacts forever (forensics; mirrors D-19 `external_operations` policy).
  - `Kiln.Artifacts.GcWorker` (P2 ships scheduled-but-no-op; P5 fills body): daily run via `:maintenance` queue, refcounts sha per `artifacts`, deletes blobs whose refcount drops to zero only after a 24-hour grace window (race protection).
  - **Hard cap** 50 GB via `config :kiln, :artifacts, max_bytes`; on breach, `Kiln.BootChecks`-style loud alarm + refuse new runs. Solo-op never silently loses data.
  - `priv/artifacts/**` is gitignored (P1 already ships `.gitkeep`).
- **D-84:** **Integrity** — `Kiln.Artifacts.read!/1` re-hashes on every open; ~400 MB/s on commodity laptops, negligible vs LLM cost. Periodic `Kiln.Artifacts.ScrubWorker` (weekly, `:maintenance` queue — P2 scaffolds, P5 activates) walks the table and re-verifies all blobs; mismatches raise an `audit_events :integrity_violation` (add event kind in P2).
- **D-85:** **New audit event kinds to add in P2** (extend `Kiln.Audit.EventKind` from 22 to 25): `:stage_input_rejected`, `:artifact_written`, `:integrity_violation`. Ship `priv/audit_schemas/v1/{stage_input_rejected,artifact_written,integrity_violation}.json`. `external_operations` does NOT cover artifact writes by design (artifacts are in-process fs ops, not external side-effects) — document in the D-17 taxonomy comment.

### Run State Machine

- **D-86:** **Phase 2 states (8 total)**: `:queued, :planning, :coding, :testing, :verifying, :blocked, :merged, :failed, :escalated`. `:blocked` is wired into the matrix now; Phase 3 adds the producers (typed-reason enum, remediation playbooks) against an already-wired matrix — no schema migration, no matrix churn, no second-pass rewrite. `:paused` (soft steering per FEEDBACK-01) is deferred to v1.5 — out of v1 scope per PROJECT.md.
- **D-87:** **Transition matrix** lives as a module attribute inside `Kiln.Runs.Transitions`:
  ```
  @terminal ~w(merged failed escalated)a
  @any_state ~w(queued planning coding testing verifying blocked)a
  @cross_cutting ~w(escalated failed)a
  @matrix %{
    queued:    [:planning],
    planning:  [:coding, :blocked],
    coding:    [:testing, :blocked, :planning],       # coder-fail routes back to planner
    testing:   [:verifying, :blocked, :planning],     # tester-fail routes back to planner
    verifying: [:merged, :planning, :blocked],        # verifier-fail re-plans
    blocked:   [:planning, :coding, :testing, :verifying]  # resume from checkpoint
  }
  # Cross-cutting: every @any_state can reach @cross_cutting (stuck-detector / cap-exceeded / unrecoverable).
  ```
  Encoded as data (not as pattern-matched function heads) so the matrix is inspectable from iex and can be rendered in operator UI when Phase 7 builds a state-graph widget.
- **D-88:** **API shape**: default is `transition(run_id, to, meta \\ %{}) :: {:ok, Run.t()} | {:error, :illegal_transition | :not_found | term()}`. Bang variant `transition!/3` exists for tests and imperative tools (`mix kiln.admin.force_state`). Rationale: tuple default because the Oban `StageWorker` that drives stage completion must decide between retry / escalate / drop on illegal transition; raising inside an Oban job burns an attempt and dumps a backtrace to the audit log. Loud-via-log `{:error, :illegal_transition}` is sufficient; the `!` variant is for deliberate invariants.
- **D-89:** `Kiln.Runs.IllegalTransitionError` message template: `illegal run state transition for run_id=<id>: from <from> to <to>; allowed from <from>: [<list>]`. Precise, tells the operator exactly what was legal. Raised only by `transition!/3`.
- **D-90:** Every transition opens `Repo.transact` → `SELECT ... FOR UPDATE` on the run row → `assert_allowed(from, to)` → `StuckDetector.check/1` (D-91) → `Run.changeset |> Repo.update()` → `Audit.append(%{event_kind: "run_state_transitioned", ...})` → `Phoenix.PubSub.broadcast(Kiln.PubSub, "run:<id>", {:run_state, run})` — all in a single transaction. The audit append is inside the tx (D-12 three-layer enforcement guarantees INSERT succeeds or the whole tx rolls back).

### RunDirector Rehydration

- **D-91:** **`Kiln.Policies.StuckDetector`** — ships as a real `GenServer` in the Phase 2 supervision tree with a no-op `check/1` body returning `:ok`. NOT a D-42 violation: ROADMAP Phase 2 explicitly lists "P1 stuck-run detector hook point wired" as the phase's behavior-to-exercise. The hook path IS the behavior. `check/1` is called inside `Transitions.transition/3` **after** the row lock and **before** the state update — a pre-condition. Phase 5 replaces only the `handle_call({:check, ctx}, ...)` body with sliding-window logic over `(stage, failure-class)` tuples; no caller refactor, no schema migration, no supervisor reshuffle. Hook signature (stable through P5): `check(ctx :: map()) :: :ok | {:halt, reason :: atom(), payload :: map()}`. A `{:halt, :stuck, payload}` return translates (in `Transitions`) into an in-same-tx `transition(run_id, :escalated, payload)`. Firing post-commit would let a stuck run ship one more invalid transition before being caught — unacceptable for audit clarity.
- **D-92:** **`Kiln.Runs.RunDirector`** — `:permanent` GenServer under the root `Kiln.Supervisor` (`:one_for_one` parent strategy). `init/1` returns immediately, sends `:boot_scan` to self asynchronously so supervisor boot never blocks on the scan. Boot scan queries `Kiln.Runs.list_active/1` (states in `@any_state`) and spawns per-run subtrees under `Kiln.Runs.RunSupervisor`. After the boot scan, `Process.send_after(:periodic_scan, 30_000)` schedules a 30-second defensive scan — belt-and-suspenders to the `{:DOWN, ref, :process, _, _}` reactive path, because a node-restart race can deliver a subtree collapse without a DOWN message reaching the replacement `RunDirector`. Periodic scan is 1 Postgres query filtering out already-monitored runs; cost is negligible and it closes the race cleanly.
- **D-93:** **Re-hydration failure policy**: 3 retry attempts with 5s/10s/15s backoff (same envelope as `BaseWorker.max_attempts: 3` so the operator model is consistent); after third failure, `transition(run.id, :escalated, %{reason: :rehydration_failed, detail: ...})` + audit event `escalation_triggered`. Failure causes covered: workflow YAML deleted, checksum mismatch (D-94 forbids silent spawn), Ecto pool exhausted during hydration, subtree `start_child/2` returning `{:error, ...}`.
- **D-94:** **Workflow checksum assertion on rehydration** — before `RunDirector` spawns a per-run subtree for a resumed run, assert the current `priv/workflows/<id>.yaml` compiled graph checksum matches the `runs.workflow_checksum` field recorded at run start. Mismatch → escalate with `reason: :workflow_changed`. Operator gets a typed, audit-visible signal that their in-flight run was mutated underfoot; the run doesn't silently run against a different graph than it started with. (Workflow signing deferral per D-65 makes this the v1 integrity mechanism.)
- **D-95:** **`Kiln.Runs.RunSupervisor`** — `DynamicSupervisor`, `max_children: 10` (matches `pool_size: 20` budget leaving 10 checkouts for everything else). Solo-op concurrent-run ceiling is 10; a box needing 20 concurrent runs is a v2 PARA-01 concern. On limit: `RunDirector` logs + leaves the remaining active runs in DB; the periodic scan rehydrates them as slots free. D-42 pattern: loud-on-limit > silent-overflow.
- **D-96:** **`RunDirector` crash recovery** — stateless rehydration: `init/1 → :boot_scan` rebuilds the monitor table from Postgres. Peer infra children (`Repo`, `Oban`, `RunSupervisor`) are untouched under `:one_for_one`. In-flight per-run subtrees under `RunSupervisor` continue running across a `RunDirector` restart.

### Spec Upgrades to Apply Inside Phase 2's Implementation

These are not new decisions — they are corrections/extensions to existing planning docs that Phase 2 must apply before downstream phases inherit broken assumptions. Mirror of D-50..D-53 pattern from Phase 1.

- **D-97:** Update **CLAUDE.md** Architecture section: change `"Single Phoenix app with 12 strict bounded contexts"` → `"Single Phoenix app with 13 strict bounded contexts"` and add `Kiln.Artifacts` to the Execution-layer list. Update the `mix xref graph --format cycles` check to admit the 13th context. Rationale: D-79 (CAS storage is a distinct bounded concern, not a sub-module of `Kiln.Stages`).
- **D-98:** Update **ARCHITECTURE.md** §4 (context list) and §7 (Workflow Execution Model — the existing "Example YAML Shape" block around line 445 predates this decision and uses a different dialect). Replace the example with the D-58/D-59 canonical shape. Mirrors D-13 (table-name drift fix) and D-51 (audit_events rename).
- **D-99:** Add to **ARCHITECTURE.md** §15 (Project Directory Structure): `lib/kiln/artifacts.ex` + `lib/kiln/artifacts/`, `priv/workflow_schemas/v1/workflow.json`, `priv/stage_contracts/v1/{planning,coding,testing,verifying,merge}.json`, `priv/artifacts/cas/` (gitignored beyond `.gitkeep`).
- **D-100:** Update **STACK.md** — no new deps (yaml_elixir 2.12 + JSV 0.18 already pinned); note the compile-time JSV build pattern + recommend `assert_formats: true` as the Kiln default (matches D-63).

### Claude's Discretion

The planner and executor have flexibility on:

- Exact module file names within each context's directory (follow ARCHITECTURE.md §15 layout).
- Specific YAML field ordering in the example workflow (as long as the canonical shape keys are all present).
- Internal helper module names (`Kiln.Workflows.Graph`, `Kiln.Workflows.Loader`, `Kiln.Runs.Transitions` — names are locked; sub-modules are discretion).
- Content of the minimal test fixture beyond "2 stages, both pass-through, one edge".
- Exact operator-facing error messages (must include the `from`/`to`/`allowed` substrings for test assertions).
- Concurrency numbers within ±1 if CI or test environment measurement shows a better default (the ratios and the total pressure calc are locked; individual queue sizes can flex).
- Oban plugin order in `config/config.exs`.
- Internal `RunDirector` state representation (the contract is: stateless rehydration from Postgres; the struct shape is not locked).
- Test fixture location under `test/support/fixtures/` (the two workflow files are locked; supporting fixtures like specs / audit events / external_operations rows are discretion).
- Whether to implement `Kiln.Artifacts.GcWorker` as a GenServer + `Process.send_after` or as an Oban `Cron` entry (functionally equivalent; P2 ships the worker; P5 activates the policy).

### Folded Todos

None — `gsd-sdk query todo.match-phase 2` returned zero matches at discussion time. Pending todos remain in the backlog (SEED-001..005 are v1.5+/v2 scope, not Phase 2).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project spec & vision
- `CLAUDE.md` — project conventions, brand contract, tech stack, anti-patterns. **NOTE: Phase 2 implementation must apply spec-upgrade D-97 before downstream phases inherit the 12-context line.**
- `.planning/PROJECT.md` — vision, constraints, key decisions, out-of-scope list.
- `.planning/REQUIREMENTS.md` — Phase 2 maps to requirements **ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07**. Adjacent: BLOCK-01 (Phase 3 adds `:blocked` producers against P2's wired matrix edge), OBS-04 (Phase 5 fills the StuckDetector body wired by D-91), SPEC-04 (holdout scenarios — `holdout_excluded: const true` structural assertion lives in stage-contract envelope per D-74).
- `.planning/ROADMAP.md` Phase 2 entry — goal, success criteria, artifacts, pitfalls addressed (P1/P3/P4/P9/P19).
- `.planning/STATE.md` — session continuity.

### Prior phase context
- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — Phase 1 locked decisions. Especially relevant:
  - **D-06** (UUID v7 via `pg_uuidv7` — Phase 2's `runs`, `stage_runs`, `artifacts` PKs follow this)
  - **D-08** (audit event_kind taxonomy — Phase 2 extends with 3 new kinds per D-85)
  - **D-09** (JSV per-kind at app boundary under `priv/audit_schemas/v1/` — D-73 mirrors this layout for `priv/stage_contracts/v1/` and `priv/workflow_schemas/v1/`)
  - **D-12** (three-layer audit INSERT-only enforcement — D-90 writes audit events inside the same tx)
  - **D-14..D-21** (`external_operations` two-phase intent table — Phase 2 creates the first real intent rows against the P1 schema)
  - **D-22..D-26** (mix check gate — D-65's `mix check_no_signature_block` follows this pattern)
  - **D-42** (no stub children without behavior — D-91 is the deliberate, sanctioned exception for StuckDetector)
  - **D-44** (`Kiln.Oban.BaseWorker` with insert-time unique on `idempotency_key` — D-70 defines the canonical key shape)
  - **D-48** (Postgres roles `kiln_owner` + `kiln_app` — unchanged)
  - **D-50..D-53** (spec-upgrade pattern — D-97..D-100 mirror it)

### Stack & architecture research
- `.planning/research/STACK.md` — locked versions; yaml_elixir 2.12 + JSV 0.18 confirmed as Phase 2's loader + validator.
- `.planning/research/ARCHITECTURE.md` §4 (12 contexts — Phase 2 bumps to 13 per D-97), **§6 (Run State Machine — rationale for command-module-not-`:gen_statem`, example shape)**, **§7 (Workflow Execution Model — includes "Example YAML Shape" at lines 435-476; D-98 REPLACES this with the D-58/D-59 canonical shape in the same commit chain)**, §9 (Idempotency layers — confirms Oban unique + handler-level dedupe + `external_operations` two-phase), §10 (Sandbox Interface — P3 context, not P2), §11 (LiveView Patterns — Phase 7 context), §15 (Project Directory Structure — D-99 extends).
- `.planning/research/PITFALLS.md` — **P1** (stuck-run detector hook wired — D-91), **P3** (idempotency — D-70 canonical keys), **P4** (token bloat — D-73..D-76 stage input-contract IS the mitigation), **P9** (Oban `max_attempts` — already locked to 3 in P1), **P19** (artifact content-addressing — D-77..D-84 IS the groundwork).
- `.planning/research/SUMMARY.md` — high-level architectural narrative.
- `.planning/research/FEATURES.md` — feature inventory.
- `.planning/research/BEADS.md` — work-unit-store rationale (informs Phase 4, not Phase 2).

### Best-practices reference (consumed during research, retain for executor cross-checks)
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/phoenix-live-view-best-practices-deep-research.md`
- `prompts/ecto-best-practices-deep-research.md`
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`

### External canonical references discovered during discussion
- Oban 2.21 OSS docs: [Defining Queues](https://hexdocs.pm/oban/defining_queues.html), [`Oban.Plugins.Cron`](https://hexdocs.pm/oban/Oban.Plugins.Cron.html), [`Oban.Plugins.Pruner`](https://hexdocs.pm/oban/Oban.Plugins.Pruner.html) — informs D-67..D-69.
- [Oban.Pro Release Notes](https://oban.pro/releases/pro) — Pro-vs-OSS feature delta confirms `DynamicPruner` is Pro-only (D-69 uses OSS `Pruner`).
- [GitLab: "What We Learned About Configuring Sidekiq"](https://about.gitlab.com/blog/2021/09/02/specialized-sidekiq-configuration-lessons-from-gitlab-dot-com/) — canonical counter-evidence for queue-per-worker-class (D-67 rejection of provider-split in P2).
- [Judoscale: Opinionated Guide to Planning Sidekiq Queues](https://judoscale.com/blog/planning-sidekiq-queues) — queue-per-concern pattern (D-67).
- [Temporal: Task Routing and Worker Sessions](https://docs.temporal.io/task-routing), [Task Queues overview](https://docs.temporal.io/task-queue) — per-downstream-service queue pattern informs D-71 provider-split trigger.
- GitHub Actions workflow syntax docs — cautionary reference (D-54 rejection of `jobs.<id>.needs:` / `${{ }}` expression language).
- [Tekton Pipelines](https://tekton.dev/docs/pipelines/), [Argo Workflows](https://argo-workflows.readthedocs.io/) — 4-kind `Pipeline`/`PipelineRun`/`Task`/`TaskRun` split (rejected per D-54).
- [JSV 0.18 hexdocs](https://hexdocs.pm/jsv) — `JSV.build!/2`, `assert_formats`, `normalize_errors/1` patterns (D-63).
- [yaml_elixir 2.12 hexdocs](https://hexdocs.pm/yaml_elixir) — `atoms: false` loader flag (D-63).
- [Bazel Remote Cache](https://bazel.build/remote/caching), [Nix Store model](https://nixos.org/guides/nix-pills/nix-store-paths.html), [Git internals: object storage](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects), [IPFS](https://docs.ipfs.tech/concepts/content-addressing/) — CAS convergent design (D-77).
- Cautionary: [Airflow XCom limits](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html) — "don't store artifacts in the metadata DB" (D-82 threshold rule dodges this).
- [sigstore cosign](https://docs.sigstore.dev/cosign/), [gitsign](https://docs.sigstore.dev/cosign/signing/gitsign/) — informs D-65 (git signing is the v1 substrate; cosign targets OCI, wrong primitive).

</canonical_refs>

<code_context>
## Existing Code Insights

Phase 1 shipped the durability floor. Phase 2's integration points are all live and tested.

### Reusable Assets (live, ready to plug into Phase 2)
- **`Kiln.Oban.BaseWorker`** (`lib/kiln/oban/base_worker.ex`) — `max_attempts: 3` default, insert-time `unique` on `idempotency_key`, delegates to `Kiln.ExternalOperations.{fetch_or_record_intent,complete_op,fail_op}/2`. Every Phase 2 Oban worker (`StageWorker`, `StateTransitionWorker`, `AuditAsyncWorker`, pruner) `use Kiln.Oban.BaseWorker, queue: :<queue>`.
- **`Kiln.ExternalOperations`** (`lib/kiln/external_operations/operation.ex`) — two-phase intent table with `:abandoned` state for P5 StuckDetector use; 30-day TTL pruner already scheduled. Phase 2's first real `op_kind` users arrive with stage dispatch (`llm_complete`/`llm_stream` stubs in P2, real in P3).
- **`Kiln.Audit`** (`lib/kiln/audit.ex`) + `Kiln.Audit.EventKind` + `Kiln.Audit.SchemaRegistry` + `priv/audit_schemas/v1/` — JSV-validated at `Kiln.Audit.append/1` boundary. Phase 2 extends with 3 new kinds per D-85. `Kiln.Audit.SchemaRegistry` is the pattern `Kiln.Stages.ContractRegistry` (D-73) copies verbatim.
- **`Kiln.BootChecks`** (`lib/kiln/boot_checks.ex`) — staged supervisor boot with invariant assertions. Phase 2 adds a 5th invariant: "`priv/workflow_schemas/v1/workflow.json` compiles via JSV" (fail-fast on bundled-schema corruption).
- **`Kiln.Logger.Metadata`** + **`Kiln.Telemetry.{pack_ctx,unpack_ctx}`** — correlation_id/run_id/stage_id propagation across Oban boundaries. Phase 2's `StageWorker` MUST `Kiln.Telemetry.pack_ctx/0` at enqueue and `unpack_ctx/1` at perform-start.
- **UUID v7** via `pg_uuidv7` — already installed. Use `fragment("uuidv7()")` as PK default for `runs`, `stage_runs`, `artifacts`.
- **`kiln_owner` / `kiln_app` roles** — migrations run as owner, app runs as `kiln_app`. Phase 2's new tables follow the Phase 1 pattern: owner owns, app gets `INSERT/SELECT/UPDATE` on mutable tables.
- **`Kiln.Scope`** (`lib/kiln/scope.ex`) — `%Kiln.Scope{operator, correlation_id, started_at}` threaded via `on_mount` + Plug. Phase 2's `RunDirector.start_run/2` accepts a scope and propagates correlation_id onto the run row.

### Established Patterns
- **Command module for state transitions** (not `:gen_statem`) — CLAUDE.md convention; Phase 2 implements `Kiln.Runs.Transitions` as the canonical example the 12 contexts learn from.
- **Staged supervisor boot** (`Kiln.Application.start/2`) — infra children → `BootChecks.run!/0` → Endpoint. Phase 2 inserts `RunSupervisor`, `RunDirector`, `StuckDetector` as the new 8th/9th/10th infra children (count moves from 7 to 10; D-42 invariant re-locks at 10).
- **JSV per-kind + compile-time build + SchemaRegistry** — `Kiln.Audit.SchemaRegistry` is the template `Kiln.Stages.ContractRegistry` and (new) `Kiln.Workflows.SchemaRegistry` follow.
- **`mix check_*` grep-based invariant tasks** (D-26 pattern) — Phase 2 adds `mix check_no_signature_block` per D-65.
- **Three-layer audit immutability** — Phase 2's `Audit.append/1` calls write from inside run-state-transition transactions; the three-layer enforcement (REVOKE + trigger + RULE) is opaque to callers.

### Integration Points
- `lib/kiln/runs/`, `lib/kiln/stages/`, `lib/kiln/workflows/` — empty directories with `.ex` placeholder context modules already committed (`lib/kiln/runs.ex`, `stages.ex`, `workflows.ex`). Phase 2 fills these.
- `priv/artifacts/` — exists with `.gitkeep` from P1 D-41. Phase 2 adds `priv/artifacts/cas/` + `priv/artifacts/tmp/`.
- `priv/workflows/` — Phase 2 creates the directory and ships `elixir_phoenix_feature.yaml`.
- `priv/audit_schemas/v1/` — Phase 2 adds `stage_input_rejected.json`, `artifact_written.json`, `integrity_violation.json`.
- NEW: `priv/workflow_schemas/v1/workflow.json`, `priv/stage_contracts/v1/{planning,coding,testing,verifying,merge}.json`, `priv/workflows/elixir_phoenix_feature.yaml`, `test/support/fixtures/workflows/minimal_two_stage.yaml`.
- `config/config.exs` Oban config — Phase 2 replaces the P1 scaffold with the D-67 six-queue taxonomy.
- `config/runtime.exs` Repo config — Phase 2 raises `pool_size: 10 → 20` per D-68.
- `Kiln.Application.start/2` child list — Phase 2 adds `Kiln.Runs.RunSupervisor`, `Kiln.Runs.RunDirector`, `Kiln.Policies.StuckDetector` to the infra child list (between `Oban` and the `BootChecks.run!/0` call). Test at `test/kiln/application_test.exs` that asserts the 7-child count moves to asserting 10.
- `lib/kiln/policies.ex` — currently empty placeholder; Phase 2 creates `lib/kiln/policies/stuck_detector.ex` as the first real Policies module.
- `lib/kiln/artifacts.ex` (new) + `lib/kiln/artifacts/{artifact.ex, cas.ex, gc_worker.ex}` — new 13th context.
- `.credo.exs` — no changes (the two custom checks from P1 still apply).
- `.dialyzer_ignore.exs` — no expected changes.
- `.github/workflows/ci.yml` — no structural changes (Postgres 16 service already running; new migrations run under `mix ecto.migrate` as already wired).

</code_context>

<specifics>
## Specific Ideas

- **"The engine MUST survive a BEAM kill mid-stage with no human intervention"** — this is the core ORCH-03/ORCH-04 test and the reason Postgres-truth + RunDirector-rehydration + `external_operations` two-phase all exist. Phase 2's integration test is a contrived kill-mid-stage-then-reboot scenario that asserts one and only one completion row, no duplicate audit events, and the run continues from the last checkpoint.
- **"Do NOT let workflow YAML become a programming language"** — the structured `on_failure: {action: route, to: <ancestor-id>, attach: <artifact-key>}` shape (D-59) is the decisive anti-feature. GitHub Actions' `${{ }}` expression language is the cautionary tale; Airflow's rebellion to Python is the lesson. Kiln's DAG is fixed per workflow version; Turing-completeness is an anti-requirement.
- **"Roles, not model IDs"** (PITFALLS P10) — `agent_role` field is an enum locked at schema-validation time; `model_preference` is a tier (`sonnet-class`), not a pin (`claude-sonnet-4-20260501`). OPS-02 adaptive fallback and OPS-03 presets do their jobs.
- **"Every artifact reference carries sha + size + content-type"** — the `artifact_ref` sub-schema (D-75) is the cross-stage handoff primitive. No bytes cross stage boundaries in a workflow; only refs do. This is the structural mitigation for P4 token bloat AND the foundation for P19 content-addressing AND the reason future v2 object-storage migration is `rsync`-simple.
- **"StuckDetector hook IS the behavior to exercise in Phase 2"** — D-91 is a deliberate, sanctioned exception to D-42. ROADMAP Phase 2 Pitfalls-Addressed line "P1 (stuck-run detector hook point wired)" is explicit. The hook call path (Transitions → StuckDetector.check/1 → audit trail) IS shipping real behavior; the sliding-window body is Phase 5's job.
- **"Workflow signing defer makes sense BECAUSE workflows live in git"** — gitsign already solves "sign git commits with keyless sigstore." Duplicating it inside YAML is anti-DRY. v1's trust boundary is `git clone`, not workflow distribution. WFE-02 is future-defended by the reserved `signature:` key + `mix check_no_signature_block` guard.
- **"Kiln.Artifacts is a 13th context because storage is genuinely orthogonal to execution"** — folding CAS under `Kiln.Stages` would force the 13th concern's internal surface into a bounded context that doesn't share its invariants (immutability, integrity-on-read, refcounting). The 12-context line was an upper bound, not a target; 13 is honest.
- **"Aggregate Oban worker count must respect Repo pool"** — D-68's math (16 workers + overhead ≤ 20 pool) is the invariant. Phase 3's provider-split raises pool to 28; any later phase adding a queue must re-run the math or shrink an existing queue. This is a permanent cross-phase constraint.

</specifics>

<deferred>
## Deferred Ideas

### From this discussion (out-of-scope for Phase 2)
- **Workflow YAML signing (WFE-02)** — v2. Reserved `signature: null` + CI guard in P2 per D-65. Future-defended shape: `signature: {alg: "sigstore-bundle", bundle: "<base64>", signed_digest: "sha256:..."}`.
- **Provider-split Oban queues (`:stages_anthropic`, `:stages_openai`, etc.)** — Phase 3 with hard trigger per D-71. Two conditions must hold simultaneously before splitting.
- **`:paused` run state / mid-run soft steering** — v1.5 (FEEDBACK-01 per `.planning/seeds/SEED-001-operator-feedback-loop.md`). Not Phase 2 scope.
- **Conditional fan-out / foreach / matrix strategy in workflow YAML** — Phase 3+, triggered by first spec that can't express parallelism as explicit stages. When added, `depends_on` becomes `oneOf: [array-of-string, object-with-join-policy]`.
- **Workflow-level `env` / variable interpolation** — deliberately never. GitHub Actions' `${{ env.FOO }}` is the cautionary tale; Kiln workflows stay fully declarative. If stages need shared config, they pass artifact refs.
- **Per-stage model pinning (as opposed to tier preference)** — conflicts with P10 and OPS-02. Revisit only if a provider ships a non-fallback-compatible model.
- **Compression of cold artifacts (zstd after 30 days)** — measure first; premature for v1.
- **Multi-node artifact replication / S3 backend** — v2 via `Kiln.Artifacts` behaviour.
- **Cross-run artifact sharing** ("same spec-sha, reuse plan across runs") — CAS enables it; scoped behind `run_id` FK for v1 to prevent reproducibility ambiguity. Revisit in SELF-* milestone.
- **Concurrent-run scheduler beyond `max_children: 10`** — v2 (PARA-01).
- **`RunDirector` introspection API for operator "list hydrated runs"** — Phase 7 (UI-01 consumes via PubSub, not via `RunDirector` call).
- **Stuck-detector full sliding-window implementation** — Phase 5 (OBS-04). Hook wired now.
- **`:blocked` producers (typed reasons + remediation playbooks)** — Phase 3 (BLOCK-01). Matrix edge wired now.
- **Scenario-runner verdict → state transition integration** — Phase 5 (SPEC-02). Transition edges wired now.
- **Transition rate-limiting (e.g., capping `verifying → planning` bounce frequency)** — Phase 5 (bounded autonomy caps).
- **Oban Pro features** (`DynamicPruner`, `Oban.Workflow` for DAG enforcement) — we're OSS-only; hand-rolled join-barrier check at job start per ARCHITECTURE.md §7.
- **Workflow-version migration framework** (`Kiln.Workflows.Migrator`) — stub in P2 (empty module), fill when first breaking `apiVersion` change ships.
- **`stages.*.hooks` (pre/post stage hooks)** — revisit if operators need stage-boundary custom logic (P5+); Oban's `perform/1` wrapping already covers most cases.

### Reviewed Todos (not folded)
None — `todo.match-phase 2` returned 0 matches. Pending SEEDs (`SEED-001..005`) are v1.5+/v2 scope and correctly excluded.

</deferred>

---

*Phase: 02-workflow-engine-core*
*Context gathered: 2026-04-19*
