# Phase 2: Workflow Engine Core - Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 42 new/modified files
**Analogs found:** 38 / 42

Phase 2 is a Phase-1-mirroring phase. Almost every new file has a direct analog shipped in Phase 1. The remaining four files (yaml loader, :digraph graph compile, per-run DynamicSupervisor, GenServer director) lack a Phase 1 analog and MUST follow the canonical patterns in RESEARCH.md §Standard Stack / §Architecture Patterns.

---

## File Classification

### NEW: `priv/` assets (schemas, fixtures)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `priv/workflow_schemas/v1/workflow.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/run_state_transitioned.json` | exact (D-09 precedent) |
| `priv/stage_contracts/v1/planning.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_started.json` | exact |
| `priv/stage_contracts/v1/coding.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_started.json` | exact |
| `priv/stage_contracts/v1/testing.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_started.json` | exact |
| `priv/stage_contracts/v1/verifying.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_started.json` | exact |
| `priv/stage_contracts/v1/merge.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_started.json` | exact |
| `priv/audit_schemas/v1/stage_input_rejected.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/stage_failed.json` | exact |
| `priv/audit_schemas/v1/artifact_written.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/external_op_completed.json` | exact |
| `priv/audit_schemas/v1/integrity_violation.json` | json-schema | read-only (compile-time) | `priv/audit_schemas/v1/external_op_failed.json` | exact |
| `priv/workflows/elixir_phoenix_feature.yaml` | workflow-fixture | read-only (compile/boot time) | none (net-new YAML) | no-analog (follow D-58/D-59 shape) |
| `test/support/fixtures/workflows/minimal_two_stage.yaml` | workflow-fixture (test) | read-only | none (net-new YAML) | no-analog |

### NEW: `priv/repo/migrations/` (DDL)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs` | migration (CHECK extend) | DDL side-effect | `priv/repo/migrations/20260418000003_create_audit_events.exs` (lines 49-58 CHECK build) | partial — drop+re-add pattern |
| `priv/repo/migrations/20260419000002_create_runs.exs` | migration (table + FK + enum + indexes + role grants) | DDL side-effect | `priv/repo/migrations/20260418000006_create_external_operations.exs` | exact (enum CHECK + grants + owner transfer + indexes) |
| `priv/repo/migrations/20260419000003_create_stage_runs.exs` | migration (table + FK + indexes + role grants) | DDL side-effect | `priv/repo/migrations/20260418000006_create_external_operations.exs` | exact |
| `priv/repo/migrations/20260419000004_create_artifacts.exs` | migration (table + unique + CHECK constraints + role grants) | DDL side-effect | `priv/repo/migrations/20260418000006_create_external_operations.exs` | exact |

### NEW: `lib/kiln/workflows/`

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `lib/kiln/workflows/schema_registry.ex` | registry (compile-time JSV build) | read-only | `lib/kiln/audit/schema_registry.ex` | **exact** (copy verbatim, swap schema dir) |
| `lib/kiln/stages/contract_registry.ex` | registry (compile-time JSV build) | read-only | `lib/kiln/audit/schema_registry.ex` | **exact** (copy verbatim, swap schema dir + kinds source) |
| `lib/kiln/workflows/loader.ex` | loader (YAML → map → JSV → Compiler) | read-only transform | none (net-new) | no-analog (follow Pattern 2 in RESEARCH.md) |
| `lib/kiln/workflows/graph.ex` | transform (:digraph topological sort) | read-only | none (net-new) | no-analog (follow Pattern 3 in RESEARCH.md + `:digraph` stdlib) |
| `lib/kiln/workflows/compiled_graph.ex` | struct | pure data | `lib/kiln/scope.ex` | role-match (defstruct + @type t) |
| `lib/kiln/workflows/compiler.ex` | transform (map → CompiledGraph + D-62 validators) | read-only | none (net-new) | no-analog |
| `lib/kiln/workflows.ex` | context facade | pass-through | `lib/kiln/audit.ex` | role-match (public API + specs) |

### NEW: `lib/kiln/runs/`

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `lib/kiln/runs/run.ex` | ecto-schema (state enum, workflow_checksum, model_profile snapshot) | read-write through changeset | `lib/kiln/external_operations/operation.ex` | **exact** (Ecto schema + enum states + read_after_writes + changeset + states/0 API) |
| `lib/kiln/runs/transitions.ex` | command-module (Repo.transact + FOR UPDATE + Audit.append + post-commit PubSub) | write-through-transition | `lib/kiln/external_operations.ex` (complete_op/2 / fail_op/2) | **exact** (tx + changeset + in-tx audit append) |
| `lib/kiln/runs/illegal_transition_error.ex` | exception | raise-path | `lib/kiln/boot_checks/error.ex` (implied by `Kiln.BootChecks.Error` usage) | role-match |
| `lib/kiln/runs/run_supervisor.ex` | supervisor (DynamicSupervisor, max_children: 10) | process tree | none (no DynamicSupervisor in P1) | no-analog (follow RESEARCH.md §Architecture Pattern + stdlib docs) |
| `lib/kiln/runs/run_director.ex` | genserver (:permanent, async :boot_scan, periodic 30s scan, {:DOWN, ...}) | side-effect (process spawn) | none (no GenServer in P1; closest is `Kiln.Telemetry.ObanHandler` which is telemetry-not-GenServer) | no-analog (follow RESEARCH.md §Architecture Pattern 6) |
| `lib/kiln/runs/run_subtree.ex` | supervisor (per-run one_for_all, transient) | process tree | none (net-new) | no-analog |
| `lib/kiln/runs.ex` | context facade (list_active/0, public API) | read-only query | `lib/kiln/audit.ex` (replay/1) | role-match (public read API + Ecto.Query) |

### NEW: `lib/kiln/stages/`

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `lib/kiln/stages/stage_run.ex` | ecto-schema (stage lifecycle row, tokens_used, cost_usd, actual_model_used columns) | read-write through changeset | `lib/kiln/external_operations/operation.ex` | **exact** |
| `lib/kiln/stages/stage_worker.ex` | oban-worker (queue :stages; validate input → dispatch → transition → enqueue next) | side-effect intent | `lib/kiln/external_operations/pruner.ex` (Oban.Worker + perform/1 + Repo.transaction) + `lib/kiln/oban/base_worker.ex` (use pattern + fetch_or_record_intent/complete_op flow) | **exact** (use Kiln.Oban.BaseWorker + fetch_or_record_intent + complete_op) |
| `lib/kiln/stages.ex` | context facade | pass-through | `lib/kiln/audit.ex` | role-match |

### NEW: `lib/kiln/artifacts/` (13th context)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `lib/kiln/artifacts.ex` | context facade (put/3 + get/2 + read!/1 + stream!/1 + ref_for/1 + by_sha/1) | file-I/O + DB write | `lib/kiln/audit.ex` (public API shape + Repo.transact) + `lib/kiln/external_operations.ex` (in-tx audit append) | role-match + partial |
| `lib/kiln/artifacts/artifact.ex` | ecto-schema | read-write through changeset | `lib/kiln/external_operations/operation.ex` | **exact** |
| `lib/kiln/artifacts/cas.ex` | file-I/O (streaming SHA-256 + atomic rename) | file-I/O | none (net-new) | no-analog (follow RESEARCH.md §Architecture Pattern 5 + POSIX rename(2)) |
| `lib/kiln/artifacts/corruption_error.ex` | exception | raise-path | `lib/kiln/runs/illegal_transition_error.ex` (this phase) | exact (sibling) |
| `lib/kiln/artifacts/gc_worker.ex` | oban-worker (queue :maintenance; stub body in P2, active in P5) | side-effect | `lib/kiln/external_operations/pruner.ex` | **exact** (use Oban.Worker + max_attempts: 1 + unique: [period: ...] + SET LOCAL ROLE kiln_owner pattern if deleting) |
| `lib/kiln/artifacts/scrub_worker.ex` | oban-worker (queue :maintenance; scaffolded in P2, active in P5) | side-effect | `lib/kiln/external_operations/pruner.ex` | **exact** |

### NEW: `lib/kiln/policies/`

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `lib/kiln/policies/stuck_detector.ex` | genserver (:permanent, no-op check/1 body; real hook path) | request-response (check/1) | none (no GenServer in P1) | no-analog (sanctioned exception to D-42 per D-91; standard GenServer module structure) |

### MODIFIED

| File | Role | Data Flow | Modification | Analog |
|------|------|-----------|--------------|--------|
| `lib/kiln/audit/event_kind.ex` | enum SSOT | read-only | extend @kinds 22 → 25 | itself (add three atoms) |
| `lib/kiln/application.ex` | application | supervisor-boot | add `Kiln.Runs.RunSupervisor`, `Kiln.Runs.RunDirector`, `Kiln.Policies.StuckDetector` to infra children; re-lock child-count invariant 7→10 | `lib/kiln/application.ex` (self — extend staged-boot pattern) |
| `lib/kiln/boot_checks.ex` | invariants | read-only assertion | add 5th invariant `:workflow_schema_loads`; update `@context_modules` 12→13 (add `Kiln.Artifacts`); update `context_count/0` expectation | `lib/kiln/boot_checks.ex` (self — add `check_*!/0` fn matching existing) |
| `config/config.exs` | Oban config | read-only | replace 2-queue P1 scaffold with 6-queue D-67 taxonomy; reserve commented-out cron entries for P3/P5 | `config/config.exs` (self) |
| `config/runtime.exs` | Repo config | read-only | `pool_size: 10 → 20` per D-68 | `config/runtime.exs` (self) |
| `lib/kiln/workflows.ex` | context facade | pass-through | replace P1 placeholder with `load!/1` + `load/1` + `compile/1` public API | `lib/kiln/audit.ex` |
| `lib/kiln/runs.ex` | context facade | read-only query | replace P1 placeholder with `list_active/0`, `get!/1`, `workflow_checksum/1` | `lib/kiln/audit.ex` |
| `lib/kiln/stages.ex` | context facade | pass-through | replace P1 placeholder | `lib/kiln/audit.ex` |
| `lib/kiln/policies.ex` | context facade | pass-through | add `StuckDetector.check/1` re-export or keep thin | `lib/kiln/audit.ex` |
| `CLAUDE.md` | project spec | docs | update "12 bounded contexts" → "13" (D-97) | self |
| `.planning/research/ARCHITECTURE.md` | architecture doc | docs | §4 (12→13) + §7 replace example YAML (D-98) + §15 directory additions (D-99) | self |
| `.planning/research/STACK.md` | stack doc | docs | note JSV `formats: true` (D-100) | self |

### NEW tests (`test/kiln/...` and `test/integration/`)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `test/kiln/workflows/schema_registry_test.exs` | test | read-only | `test/kiln/audit/event_kind_test.exs` | role-match |
| `test/kiln/workflows/loader_test.exs` | test | read-only | `test/kiln/audit/append_test.exs` | role-match |
| `test/kiln/workflows/graph_test.exs` | test (property + unit) | read-only | `test/kiln/audit/append_test.exs` | role-match |
| `test/kiln/workflows/compiler_test.exs` | test | read-only | `test/kiln/audit/append_test.exs` | role-match |
| `test/kiln/runs/transitions_test.exs` | test (DataCase + Audit.replay cross-check) | read-write-through-transition | `test/kiln/external_operations_test.exs` | **exact** (setup with correlation_id, in-tx tx + audit pairing assertions) |
| `test/kiln/runs/run_director_test.exs` | test (ExUnit.Case, async: false; supervision) | process-lifecycle | `test/kiln/application_test.exs` (supervision_tree assertions) | role-match |
| `test/kiln/stages/contract_registry_test.exs` | test | read-only | `test/kiln/audit/event_kind_test.exs` | role-match |
| `test/kiln/stages/stage_worker_test.exs` | test (DataCase + Oban.Testing) | side-effect intent | `test/kiln/oban/base_worker_test.exs` | **exact** |
| `test/kiln/artifacts_test.exs` | test | file-I/O + DB | `test/kiln/external_operations_test.exs` (DataCase + Audit.replay) | role-match |
| `test/kiln/artifacts/cas_test.exs` | test | file-I/O | none | no-analog |
| `test/kiln/policies/stuck_detector_test.exs` | test | request-response | `test/kiln/application_test.exs` | role-match |
| `test/integration/rehydration_test.exs` | integration (BEAM-kill + reboot) | process lifecycle + DB | none (net-new; scenario is P2's signature ORCH-04 test) | no-analog |
| `test/kiln/application_test.exs` | test | supervision-tree | **modified**: 7 → 10 child count | self |

---

## Pattern Assignments

### `lib/kiln/workflows/schema_registry.ex` (registry, compile-time)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/audit/schema_registry.ex`

**Copy verbatim, changing 3 lines:** schemas directory, kinds source, and add `formats: true` to `@build_opts` (per RESEARCH.md correction #1).

**Imports + module doc pattern** (lines 1-22):
```elixir
defmodule Kiln.Audit.SchemaRegistry do
  @moduledoc """
  Loads and caches JSV-compiled schemas for each `event_kind` at **module
  compile time**.
  ...
  """

  alias Kiln.Audit.EventKind
```

**Core pattern — `@external_resource` + compile-time loop into module attribute** (lines 24-44):
```elixir
  @schemas_dir Path.expand("../../../priv/audit_schemas/v1", __DIR__)

  @build_opts [default_meta: "https://json-schema.org/draft/2020-12/schema"]

  @schemas (for kind <- EventKind.values(), into: %{} do
              path = Path.join(@schemas_dir, "#{kind}.json")
              @external_resource path

              case File.read(path) do
                {:ok, json} ->
                  raw = Jason.decode!(json)
                  root = JSV.build!(raw, @build_opts)
                  {kind, root}

                {:error, :enoent} ->
                  {kind, :missing}
              end
            end)
```

**Fetch API pattern** (lines 46-67):
```elixir
  @spec fetch(atom()) :: {:ok, JSV.Root.t()} | {:error, :schema_missing}
  def fetch(kind) when is_atom(kind) do
    case Map.get(@schemas, kind, :missing) do
      :missing -> {:error, :schema_missing}
      root -> {:ok, root}
    end
  end
```

**P2 adaptations:**
- `@schemas_dir` → `Path.expand("../../../priv/workflow_schemas/v1", __DIR__)`
- iteration source → `[:workflow]` (single schema) OR enumerate files in the directory
- `@build_opts` → `[default_meta: "...", formats: true]` (enable format validation per RESEARCH.md correction #1)

---

### `lib/kiln/stages/contract_registry.ex` (registry, compile-time)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/audit/schema_registry.ex` (same as above — two distinct copies)

**P2 adaptations:**
- `@schemas_dir` → `Path.expand("../../../priv/stage_contracts/v1", __DIR__)`
- iteration source → `@kinds ~w(planning coding testing verifying merge)a` (module-local list; NOT `Kiln.Audit.EventKind`)
- Same `formats: true` build opt
- Expose `kinds/0` per RESEARCH.md Pattern 1 line 365-366

---

### `lib/kiln/runs/run.ex` (ecto-schema)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/external_operations/operation.ex`

**Module attribute + PK + Jason derive pattern** (lines 26-53):
```elixir
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
  @foreign_key_type :binary_id

  @states [:intent_recorded, :action_in_flight, :completed, :failed, :abandoned]

  @derive {Jason.Encoder,
           only: [
             :id,
             :op_kind,
             ...
           ]}

  schema "external_operations" do
    field(:op_kind, :string)
    field(:idempotency_key, :string)
    field(:state, Ecto.Enum, values: @states, default: :intent_recorded)
    ...
    timestamps(type: :utc_datetime_usec)
  end
```

**Changeset pattern** (lines 93-100):
```elixir
  @required [:op_kind, :idempotency_key]
  @optional [:state, :schema_version, ...]

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(op, attrs) do
    op
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:state, @states)
    |> unique_constraint(:idempotency_key, name: :external_operations_idempotency_key_idx)
  end
```

**States accessor pattern** (lines 102-105):
```elixir
  @spec states() :: [:intent_recorded | ... | :abandoned, ...]
  def states, do: @states
```

**P2 adaptations for `Kiln.Runs.Run`:**
- `@states ~w(queued planning coding testing verifying blocked merged failed escalated)a` (9 states per D-86; the 9th is `:blocked` added over the 8 CONTEXT listed)
- schema fields per D-88/D-94: `workflow_id`, `workflow_version`, `workflow_checksum`, `model_profile_snapshot` (jsonb), `caps_snapshot` (jsonb), `correlation_id`, `state`, plus budget accounting (`tokens_used_usd`, `elapsed_seconds`) and timestamps
- `transition_changeset/3` as a separate changeset for state-only transitions (see RESEARCH.md Pattern 4 line 565-569)

---

### `lib/kiln/stages/stage_run.ex` (ecto-schema)

**Analog:** Same as `lib/kiln/runs/run.ex` — copy `lib/kiln/external_operations/operation.ex` structure.

**P2 adaptations:**
- schema fields: `run_id` FK, `workflow_stage_id` (string — matches YAML `id`), `kind` (Ecto.Enum), `agent_role` (Ecto.Enum), `attempt`, `state`, `timeout_seconds`, `tokens_used`, `cost_usd`, `requested_model`, `actual_model_used` (D-82 hot-path columns), timestamps
- `unique_constraint(:run_id_workflow_stage_id_attempt)` — one row per `(run, stage, attempt)`

---

### `lib/kiln/artifacts/artifact.ex` (ecto-schema)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/external_operations/operation.ex`

**P2 adaptations** (per D-81):
- fields: `stage_run_id` (FK, `on_delete: :restrict`), `run_id` (FK, `on_delete: :restrict`), `name` (text), `sha256` (text 64 hex), `size_bytes` (bigint ≥ 0), `content_type` (text; Ecto.Enum over controlled vocab), `schema_version`, `producer_kind`
- **Only `inserted_at` — NOT `timestamps()`** (artifacts are append-only semantically; D-81)
- `unique_constraint(:stage_run_id_name_idx)` — one name per stage attempt
- `check_constraint(:sha256, name: :artifacts_sha256_format)` — 64 lowercase hex

---

### `lib/kiln/runs/transitions.ex` (command-module)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/external_operations.ex` (specifically `complete_op/2` / `fail_op/2`)

**In-tx state update + Audit.append pattern** (lines 138-170, `complete_op/2`):
```elixir
  @spec complete_op(Operation.t(), map()) ::
          {:ok, Operation.t()} | {:error, Ecto.Changeset.t() | term()}
  def complete_op(%Operation{} = op, result_payload) when is_map(result_payload) do
    cid = Logger.metadata()[:correlation_id] || Ecto.UUID.generate()

    Repo.transaction(fn ->
      changeset =
        Operation.changeset(op, %{
          state: :completed,
          result_payload: result_payload,
          completed_at: DateTime.utc_now()
        })

      case Repo.update(changeset) do
        {:ok, updated} ->
          {:ok, _ev} =
            Audit.append(%{
              event_kind: :external_op_completed,
              run_id: updated.run_id,
              stage_id: updated.stage_id,
              correlation_id: cid,
              payload: %{...}
            })

          updated

        {:error, cs} ->
          Repo.rollback(cs)
      end
    end)
  end
```

**P2-specific additions beyond the analog** (per D-90 + RESEARCH.md Pattern 4):

1. **`SELECT ... FOR UPDATE` row lock** (not in P1 — P1 uses `on_conflict: :nothing` because inserts; transitions use existing rows, so the lock is the correctness mechanism):
   ```elixir
   Repo.one(from(r in Run, where: r.id == ^run_id, lock: "FOR UPDATE"))
   ```

2. **`@matrix` as module attribute data** (D-87 — not pattern-matched function heads):
   ```elixir
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
   ```

3. **`StuckDetector.check/1` hook BEFORE state update, INSIDE the tx** (D-91):
   ```elixir
   with {:ok, run} <- lock_run(run_id),
        :ok <- assert_allowed(run.state, to),
        :ok <- StuckDetector.check(%{run: run, to: to, meta: meta}),
        {:ok, updated} <- update_state(run, to, meta),
        {:ok, _event} <- append_audit(updated, run.state, to, meta) do
     {:ok, updated}
   end
   ```

4. **Post-commit PubSub broadcast** (RESEARCH.md Pitfall #1 — MUST be after `Repo.transact` returns):
   ```elixir
   case result do
     {:ok, run} ->
       Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})
       Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})
       {:ok, run}

     other ->
       other
   end
   ```

5. **Use `Repo.transact/2` (NOT `Repo.transaction/2`)** — RESEARCH.md §Standard Stack verifies this is the current idiomatic API; `Repo.transaction/2` is deprecated. P1 uses `Repo.transaction/2` because it predates the choice; new P2 code uses `Repo.transact/2`.

---

### `lib/kiln/stages/stage_worker.ex` (oban-worker, queue: :stages)

**Analog A (use-pattern + BaseWorker integration):** `/Users/jon/projects/kiln/lib/kiln/oban/base_worker.ex` docs (lines 9-26 usage example)

**Analog B (bare Oban.Worker + perform/1 + Repo.transaction):** `/Users/jon/projects/kiln/lib/kiln/external_operations/pruner.ex`

**Use pattern from BaseWorker doc** (lines 9-26):
```elixir
defmodule MyApp.DoThingWorker do
  use Kiln.Oban.BaseWorker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"idempotency_key" => key} = args}) do
    case fetch_or_record_intent(key, %{
           op_kind: "do_thing",
           intent_payload: args
         }) do
      {:found_existing, %{state: :completed} = op} ->
        {:ok, op}

      {_status, op} ->
        # ... do the external side-effect idempotently ...
        complete_op(op, %{"result" => "ok"})
    end
  end
end
```

**Pruner bare-Oban pattern** (lines 23-27) for reference — StageWorker does NOT use this (it uses BaseWorker), but the worker-level `queue:` + `max_attempts:` options are the same shape:
```elixir
use Oban.Worker,
  queue: :maintenance,
  max_attempts: 1,
  unique: [period: 60 * 60 * 6]
```

**P2 StageWorker specifics** (per RESEARCH.md §Architecture Pattern 1 data-flow trace step 3):
```elixir
defmodule Kiln.Stages.StageWorker do
  use Kiln.Oban.BaseWorker, queue: :stages

  @impl Oban.Worker
  def perform(%Oban.Job{args: args, meta: meta}) do
    # Restore correlation_id from meta (P1 pattern; see Pitfall #6)
    Kiln.Telemetry.unpack_ctx(meta["kiln_ctx"] || %{})

    key = args["idempotency_key"]
    stage_kind = String.to_existing_atom(args["stage_kind"])

    with {:ok, root} <- Kiln.Stages.ContractRegistry.fetch(stage_kind),
         :ok <- validate_input(args["stage_input"], root),
         {_status, op} <- fetch_or_record_intent(key, %{op_kind: "stage_dispatch", intent_payload: args, run_id: args["run_id"], stage_id: args["stage_run_id"]}),
         :ok <- guard_already_completed(op) do
      # ... agent dispatch (stub in P2) ...
      # ... Artifacts.put/3 ...
      # ... Transitions.transition(...) ...
      complete_op(op, %{"result" => "stub"})
    else
      {:error, {:stage_input_rejected, err}} ->
        # D-76: {:cancel, reason} — NOT {:discard, ...} (Pitfall #5)
        _ = Kiln.Audit.append(%{event_kind: :stage_input_rejected, ...})
        _ = Kiln.Runs.Transitions.transition(args["run_id"], :escalated, %{reason: :invalid_stage_input})
        {:cancel, {:stage_input_rejected, err}}

      other -> other
    end
  end
end
```

---

### `lib/kiln/artifacts/gc_worker.ex` + `lib/kiln/artifacts/scrub_worker.ex` (oban-workers, queue: :maintenance)

**Analog:** `/Users/jon/projects/kiln/lib/kiln/external_operations/pruner.ex`

**Complete pattern — bare Oban.Worker + SET LOCAL ROLE + Repo.transaction + Logger.info** (lines 23-64):
```elixir
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 1,
    unique: [period: 60 * 60 * 6]

  import Ecto.Query
  alias Kiln.ExternalOperations.Operation
  alias Kiln.Repo
  require Logger

  @retention_days 30

  @impl Oban.Worker
  def perform(_job) do
    Repo.transaction(fn ->
      # Elevate to kiln_owner — only kiln_owner has DELETE on
      # external_operations (D-48, T-03). `SET LOCAL` scopes the change
      # to this txn, so the role resets automatically on commit/rollback.
      Repo.query!("SET LOCAL ROLE kiln_owner")

      cutoff =
        DateTime.utc_now()
        |> DateTime.add(-@retention_days * 24 * 60 * 60, :second)

      {count, _} =
        from(o in Operation,
          where: o.state == :completed,
          where: o.completed_at < ^cutoff
        )
        |> Repo.delete_all()

      Logger.info("external_operations.pruner: deleted #{count} ...")
      count
    end)
    :ok
  end
```

**P2 adaptations:** Phase 2 ships these workers with **no-op bodies** (scheduled but inactive per D-83/D-84; P5 fills the logic). Just the `use Oban.Worker, queue: :maintenance, ...` declaration + `def perform(_job), do: :ok`. Cron entries are commented out in `config/config.exs` until P5.

---

### `lib/kiln/runs/run_supervisor.ex` (DynamicSupervisor, max_children: 10)

**Analog:** None in Phase 1.

**Canonical pattern from RESEARCH.md §Architecture Pattern 6 + Elixir stdlib docs:**
```elixir
defmodule Kiln.Runs.RunSupervisor do
  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: 10  # D-95: solo-op ceiling per D-68 pool math
    )
  end
end
```

Follow D-95: on limit reached, `DynamicSupervisor.start_child/2` returns `{:error, :max_children}` — `RunDirector` logs loudly and leaves remaining runs in DB (picked up by next periodic scan).

---

### `lib/kiln/runs/run_director.ex` (GenServer, :permanent)

**Analog:** None in Phase 1. Closest structural reference is `lib/kiln/telemetry/oban_handler.ex`, but that's a telemetry handler (ETS-backed), not a GenServer. No GenServer analog exists.

**Canonical pattern from RESEARCH.md §Architecture Pattern 6 (verbatim, lines 758-870):**
- `use GenServer` + `start_link/1` with `name: __MODULE__`
- `init/1` returns immediately; sends `:boot_scan` to self (D-92 — supervisor boot never blocks)
- `handle_info(:boot_scan, ...)` scans active runs, calls `DynamicSupervisor.start_child` per run, `Process.monitor/1` each child pid
- `handle_info(:periodic_scan, ...)` — 30s defensive scan via `Process.send_after`
- `handle_info({:DOWN, ref, :process, pid, reason}, state)` — rehydrate the crashed subtree (D-92: monitor, not link)
- D-94: `assert_workflow_unchanged/1` before every spawn; on mismatch call `Transitions.transition(run.id, :escalated, %{reason: :workflow_changed})`

Follow the RESEARCH.md example; it is complete.

---

### `lib/kiln/workflows/loader.ex` + `lib/kiln/workflows/graph.ex` + `lib/kiln/workflows/compiler.ex`

**Analog:** None in Phase 1 (no YAML/graph code exists yet).

**Canonical patterns from RESEARCH.md:**
- Pattern 2 (loader pipeline, lines 381-422) — `YamlElixir.read_from_file/2` → string-keyed `Map` → `JSV.validate/2` → `Compiler.compile/1`
- Pattern 3 (`:digraph` topological sort, lines 438-491) — `:digraph.new([:acyclic])` + `add_vertex`/`add_edge` + `:digraph_utils.topsort/1` + `try/after :digraph.delete/1`

Critical hygiene rules from RESEARCH.md §Anti-Patterns:
- Do NOT pass `atoms: true` to `YamlElixir.read_from_file/2` (keep string keys — malicious YAML won't exhaust atom table)
- Do NOT `String.to_atom/1` workflow IDs
- Do NOT forget `:digraph.delete/1` in `after:` (ETS leak)
- Do NOT `rescue` cycle — match `{:error, _}` from `:digraph.add_edge/3` explicitly

D-62 Elixir-side validators run AFTER JSV in `Compiler.compile/1`:
1. Exactly one stage has `depends_on: []`
2. Topological sort succeeds
3. Every `depends_on` ID resolves to a stage ID
4. Every `on_failure.to` is a topological ancestor
5. Every `kind` has a matching file under `priv/stage_contracts/v1/`
6. `signature` is `null` (v1 invariant per D-65)

---

### `lib/kiln/artifacts/cas.ex` (file-I/O)

**Analog:** None in Phase 1 (no filesystem artifact code exists).

**Canonical pattern from RESEARCH.md §Architecture Pattern 5 (lines 600-666):**
- `File.open!(tmp_path, [:write, :binary, :raw], fn fd -> ... end)`
- `Enum.reduce(body, {:crypto.hash_init(:sha256), 0}, ...)` — streaming hash
- `File.rename(tmp_path, final_path)` — atomic rename (Pitfall #3: tmp + cas MUST be on same FS)
- `File.chmod(final_path, 0o444)` — best-effort; don't raise
- Two-level fan-out: `priv/artifacts/cas/<aa>/<bb>/<sha>`

---

### `lib/kiln/artifacts.ex` (context facade)

**Analog (API shape):** `/Users/jon/projects/kiln/lib/kiln/audit.ex` (public-API structure + Repo.transact + Logger.metadata fallback + @spec-forward docstrings)

**Analog (in-tx audit pairing):** `/Users/jon/projects/kiln/lib/kiln/external_operations.ex` lines 149-162 — insert row + `{:ok, _ev} = Audit.append(%{event_kind: :..., ...})` inside the same `Repo.transact`

**P2 `put/3` specifics** (per RESEARCH.md Pattern 5 lines 680-718):
```elixir
def put(stage_run_id, name, body, opts \\ []) do
  content_type = Keyword.fetch!(opts, :content_type)

  with {:ok, sha, size} <- CAS.put_stream(body) do
    Repo.transact(fn ->
      changeset = Artifact.changeset(%Artifact{}, %{...})

      with {:ok, artifact} <- Repo.insert(changeset),
           {:ok, _ev} <-
             Audit.append(%{
               event_kind: :artifact_written,
               run_id: artifact.run_id,
               stage_id: artifact.stage_run_id,
               correlation_id: Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
               payload: %{...}
             }) do
        {:ok, artifact}
      end
    end)
  end
end
```

---

### `priv/repo/migrations/20260419000001_extend_audit_event_kinds.exs` (migration)

**Analog:** `/Users/jon/projects/kiln/priv/repo/migrations/20260418000003_create_audit_events.exs` (CHECK-build pattern lines 49-58)

**Extract pattern from migration 3:**
```elixir
@event_kinds Kiln.Audit.EventKind.values_as_strings()

# ...
kinds_list = Enum.map_join(@event_kinds, ", ", &"'#{&1}'")

execute(
  """
  ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_event_kind_check
    CHECK (event_kind IN (#{kinds_list}))
  """,
  "ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check"
)
```

**P2 adaptation — drop + re-add** (per RESEARCH.md Pitfall #2):
```elixir
def up do
  execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")

  kinds_list = Enum.map_join(Kiln.Audit.EventKind.values_as_strings(), ", ", &"'#{&1}'")

  execute("""
  ALTER TABLE audit_events
    ADD CONSTRAINT audit_events_event_kind_check
    CHECK (event_kind IN (#{kinds_list}))
  """)
end

def down do
  # Re-create the ORIGINAL 22-kind constraint (hard-code the list — the module value
  # at down-time may already be 25, which would make down a no-op).
  original_kinds = ~w(run_state_transitioned stage_started ... escalation_triggered)

  execute("ALTER TABLE audit_events DROP CONSTRAINT audit_events_event_kind_check")
  # ... re-add with original_kinds ...
end
```

---

### `priv/repo/migrations/20260419000002_create_runs.exs` + `20260419000003_create_stage_runs.exs` + `20260419000004_create_artifacts.exs`

**Analog:** `/Users/jon/projects/kiln/priv/repo/migrations/20260418000006_create_external_operations.exs`

**Full pattern to copy** (lines 23-137):

**Table creation with uuidv7 PK** (lines 23-68):
```elixir
create table(:external_operations, primary_key: false) do
  add(:id, :binary_id,
    primary_key: true,
    default: fragment("uuid_generate_v7()"),
    null: false
  )

  add(:op_kind, :text, null: false)
  add(:idempotency_key, :text, null: false)
  add(:state, :text, null: false, default: "intent_recorded")
  add(:schema_version, :integer, null: false, default: 1)
  ...
  add(:run_id, :binary_id)
  add(:stage_id, :binary_id)
  timestamps(type: :utc_datetime_usec)
end
```

**Enum CHECK constraint pattern** (lines 71-81):
```elixir
@states ~w(intent_recorded action_in_flight completed failed abandoned)

states_list = Enum.map_join(@states, ", ", &"'#{&1}'")

execute(
  """
  ALTER TABLE external_operations
    ADD CONSTRAINT external_operations_state_check
    CHECK (state IN (#{states_list}))
  """,
  "ALTER TABLE external_operations DROP CONSTRAINT external_operations_state_check"
)
```

**Unique + partial + FK indexes** (lines 86-111):
```elixir
create(unique_index(:external_operations, [:idempotency_key], name: :external_operations_idempotency_key_idx))
create(index(:external_operations, [:state], where: "state IN (...)", name: :..._active_state_idx))
create(index(:external_operations, [:run_id], name: :..._run_id_idx))
```

**Owner transfer + kiln_app grants** (lines 115-127):
```elixir
execute(
  "ALTER TABLE external_operations OWNER TO kiln_owner",
  "ALTER TABLE external_operations OWNER TO current_user"
)

execute(
  "GRANT INSERT, SELECT, UPDATE ON external_operations TO kiln_app",
  "REVOKE INSERT, SELECT, UPDATE ON external_operations FROM kiln_app"
)
```

**P2 per-migration specifics:**
- `runs`: 9-state enum CHECK, FK to nothing (top-level), indexes on `(state)` for RunDirector's `list_active/0`, `(workflow_id, workflow_version)`, `(correlation_id)`
- `stage_runs`: FK to `runs(id) on_delete: :restrict`, unique `(run_id, workflow_stage_id, attempt)`, state enum CHECK, index on `(run_id)`
- `artifacts`: FK to `stage_runs(id) on_delete: :restrict` AND `runs(id) on_delete: :restrict` (both `:restrict` per D-81), unique `(stage_run_id, name)`, index on `(sha256)` and `(run_id, inserted_at)`, CHECK constraint on `sha256` format (`~ '^[0-9a-f]{64}$'`), CHECK on `size_bytes >= 0`

**IMPORTANT:** NO `UPDATE DELETE` grants on `artifacts` beyond what's needed — artifacts are semantically append-only (D-81). Stick to `GRANT INSERT, SELECT` on `artifacts` for `kiln_app` (matches audit_events grant pattern, not external_operations). The `ScrubWorker` / `GcWorker` that needs DELETE uses `SET LOCAL ROLE kiln_owner` (the Pruner pattern).

---

### `lib/kiln/application.ex` (modified — supervision tree 7 → 10)

**Analog:** itself.

**Existing staged-boot pattern** (lines 16-54):
```elixir
def start(_type, _args) do
  infra_children = [
    KilnWeb.Telemetry,
    Kiln.Repo,
    {Phoenix.PubSub, name: Kiln.PubSub},
    {Finch, name: Kiln.Finch},
    {Registry, keys: :unique, name: Kiln.RunRegistry},
    {Oban, Application.fetch_env!(:kiln, Oban)}
  ]

  opts = [strategy: :one_for_one, name: Kiln.Supervisor]

  case Supervisor.start_link(infra_children, opts) do
    {:ok, sup_pid} ->
      Kiln.BootChecks.run!()
      _ = ObanHandler.attach()
      {:ok, _endpoint_pid} = Supervisor.start_child(sup_pid, KilnWeb.Endpoint.child_spec([]))
      {:ok, sup_pid}
    other -> other
  end
end
```

**P2 extension:** Between `infra_children` (6) and `BootChecks.run!/0`, add three new children under `start_child` (keeping the staged pattern) OR extend the `infra_children` list to 9:
```elixir
infra_children = [
  # ... existing 6 ...
  Kiln.Runs.RunSupervisor,
  {Kiln.Runs.RunDirector, []},
  Kiln.Policies.StuckDetector
]
# Post-BootChecks, start Endpoint as 10th child (same dynamic pattern as P1).
```

Update the D-42 invariant comment from 7 to 10. Update `test/kiln/application_test.exs` assertion `length(child_ids) == 7` → `== 10`, and remove `Kiln.Runs.RunDirector`, `Kiln.Runs.RunSupervisor`, `Kiln.Policies.StuckDetector` from the `forbidden` list in the negative test.

---

### `lib/kiln/boot_checks.ex` (modified — add 5th invariant + extend context list)

**Analog:** itself.

**Invariant-fn pattern** (lines 116-136):
```elixir
defp check_contexts_compiled! do
  missing =
    @context_modules
    |> Enum.reject(&match?({:module, _}, Code.ensure_compiled(&1)))

  case missing do
    [] -> :ok
    mods ->
      raise Error,
        invariant: :contexts_compiled,
        details: %{missing_modules: mods, expected_count: length(@context_modules)},
        remediation_hint: "..."
  end
end
```

**P2 additions:**

1. Extend `@context_modules` — add `Kiln.Artifacts` (13th entry per D-97). Update `@type context_module ::` union type.

2. New invariant `check_workflow_schema_loads!/0`:
```elixir
defp check_workflow_schema_loads! do
  case Kiln.Workflows.SchemaRegistry.fetch(:workflow) do
    {:ok, _root} -> :ok
    {:error, reason} ->
      raise Error,
        invariant: :workflow_schema_loads,
        details: %{reason: reason},
        remediation_hint:
          "priv/workflow_schemas/v1/workflow.json failed JSV build. " <>
            "Check file exists, is valid JSON, and is a valid JSON Schema 2020-12 document."
  end
end
```

3. Wire the new check into `run!/0`:
```elixir
check_contexts_compiled!()
check_audit_revoke_active!()
check_audit_trigger_active!()
check_workflow_schema_loads!()  # NEW — before secrets
check_required_secrets!()
```

---

### `config/config.exs` (modified — Oban taxonomy)

**Analog:** itself (lines 53-75).

**Existing 2-queue pattern:**
```elixir
config :kiln, Oban,
  repo: Kiln.Repo,
  engine: Oban.Engines.Basic,
  queues: [default: 10, maintenance: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", Kiln.ExternalOperations.Pruner}
     ]}
  ]
```

**P2 replacement per D-67/D-69 + RESEARCH.md Pattern 8** (lines 924-948):
```elixir
config :kiln, Oban,
  repo: Kiln.Repo,
  engine: Oban.Engines.Basic,
  queues: [
    default: 2,
    stages: 4,
    github: 2,
    audit_async: 4,
    dtu: 2,
    maintenance: 2
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 3 * * *", Kiln.ExternalOperations.Pruner, queue: :maintenance},
       # {"*/5 * * * *", Kiln.Policies.StuckDetectorWorker, queue: :maintenance},  # P5
       # {"0 4 * * 0", Kiln.Sandboxes.DTU.ContractTestWorker, queue: :maintenance}  # P3
     ]}
  ]
```

---

### Tests

### `test/kiln/runs/transitions_test.exs`

**Analog:** `/Users/jon/projects/kiln/test/kiln/external_operations_test.exs`

**Copy verbatim structure:**
- `use Kiln.DataCase, async: true`
- `setup` block that sets `Logger.metadata(correlation_id: cid)` and `on_exit` resets it (lines 31-39)
- Describe blocks per behavior; assertions use `Audit.replay(correlation_id: cid)` to verify the paired audit event was written in the same tx (lines 57-62)
- Race test (two concurrent callers) uses `Task.async` + `Task.await_many`

**Setup pattern** (lines 31-39):
```elixir
setup do
  cid = Ecto.UUID.generate()
  Logger.metadata(correlation_id: cid)
  on_exit(fn -> Logger.metadata(correlation_id: nil) end)
  {:ok, correlation_id: cid}
end
```

**In-tx audit pairing assertion** (lines 57-62):
```elixir
assert [event] = Audit.replay(correlation_id: cid)
assert event.event_kind == :run_state_transitioned
assert event.payload["from"] == "queued"
assert event.payload["to"] == "planning"
```

---

### `test/kiln/stages/stage_worker_test.exs`

**Analog:** `/Users/jon/projects/kiln/test/kiln/oban/base_worker_test.exs`

**Copy structure:**
- `use Kiln.DataCase, async: false` (Oban.Testing is not async-safe with shared DB)
- `use Oban.Testing, repo: Kiln.Repo`
- `setup` with `Logger.metadata(correlation_id: ...)`
- `defmodule TestWorker do ... end` nested module for isolated worker testing (lines 30-49)
- Assertions via `assert_enqueued`, `perform_job`, `Oban.drain_queue`

---

### `test/integration/rehydration_test.exs` (BEAM-kill + reboot scenario)

**Analog:** None. This is the signature ORCH-04 test; no prior code establishes the pattern.

**Approach (from CONTEXT.md specifics line 245):**
- Seed a `runs` row in `:coding` via direct `Repo.insert`
- Seed `external_operations` intent for the stage
- Kill the `RunDirector` process (`Process.exit(pid, :kill)`)
- Wait for supervisor restart (a new `RunDirector` pid is born via `:permanent`)
- Assert: new `RunDirector.boot_scan` found the row + spawned subtree + monitor table has entry
- Simulate a retry: call `fetch_or_record_intent` again with the same key → `{:found_existing, _}`
- Assert exactly ONE `external_operations` row, ONE `external_op_intent_recorded` audit event, zero duplicate `stage_completed` events.

No direct analog — invent from primitives.

---

## Shared Patterns

### Postgres transaction + in-tx audit append + post-commit side effect

**Source:** `/Users/jon/projects/kiln/lib/kiln/external_operations.ex` lines 74-127 and 141-170

**Apply to:** `Kiln.Runs.Transitions`, `Kiln.Artifacts.put/3`, any future Phase 2 write path.

**Canonical shape:**
```elixir
Repo.transaction(fn ->  # OR Repo.transact/2 for new P2 code
  # 1. Mutate row (insert/update)
  case Repo.update(changeset) do
    {:ok, updated} ->
      # 2. Append audit event IN THE SAME TX
      {:ok, _ev} = Audit.append(%{event_kind: :..., run_id: ..., correlation_id: cid, payload: %{...}})
      updated

    {:error, cs} -> Repo.rollback(cs)
  end
end)

# 3. Post-commit side effects (PubSub, logs, more Oban enqueues) happen HERE,
#    NEVER inside the closure (Pitfall #1 from RESEARCH.md).
```

**Why:** P1's D-12 three-layer audit immutability + tx atomicity gives: either (state change + audit row) or (neither). Never one without the other.

---

### Idempotency-key + fetch_or_record_intent handler-level dedupe

**Source:** `/Users/jon/projects/kiln/lib/kiln/oban/base_worker.ex` + `/Users/jon/projects/kiln/lib/kiln/external_operations.ex`

**Apply to:** `Kiln.Stages.StageWorker`, any future Oban worker that has an external side-effect.

**Shape:**
```elixir
use Kiln.Oban.BaseWorker, queue: :stages  # insert-time unique on :idempotency_key

@impl Oban.Worker
def perform(%Oban.Job{args: %{"idempotency_key" => key} = args}) do
  case fetch_or_record_intent(key, %{op_kind: "stage_dispatch", intent_payload: args, run_id: args["run_id"]}) do
    {:found_existing, %{state: :completed} = op} -> {:ok, op}      # already done
    {:found_existing, %{state: :action_in_flight}} -> {:snooze, 5}  # sibling in flight
    {_status, op} ->
      # ... do the side-effect ...
      complete_op(op, %{...})
  end
end
```

**Canonical key shapes (per D-70):**
- StageWorker: `"run:#{run_id}:stage:#{stage_id}"`
- Audit async: `"audit:#{correlation_id}:#{kind}:#{sha256(payload)[0..15]}"`
- ExtOp completion: `"extop:#{external_operation_id}"`
- Pruner (cron): `"pruner:external_operations:#{date_bucket}"`

---

### Compile-time JSV schema registry (`@external_resource` + module attribute)

**Source:** `/Users/jon/projects/kiln/lib/kiln/audit/schema_registry.ex`

**Apply to:** `Kiln.Workflows.SchemaRegistry`, `Kiln.Stages.ContractRegistry`.

**Shape:** See RESEARCH.md §Architecture Pattern 1. Verbatim copy of P1 SchemaRegistry; change dir + kinds source; add `formats: true` to `@build_opts` per RESEARCH.md correction #1.

---

### Migration pattern: uuidv7 PK + enum CHECK + role grants + owner transfer

**Source:** `/Users/jon/projects/kiln/priv/repo/migrations/20260418000006_create_external_operations.exs`

**Apply to:** `20260419000002_create_runs.exs`, `20260419000003_create_stage_runs.exs`, `20260419000004_create_artifacts.exs`.

**Five-part shape:**
1. `create table(:..., primary_key: false) do add(:id, :binary_id, primary_key: true, default: fragment("uuid_generate_v7()"), null: false); ...`
2. Enum CHECK constraint via `Enum.map_join/3` + `ALTER TABLE ... ADD CONSTRAINT`
3. Indexes: unique index + partial (if active-state semantics) + FK indexes
4. `ALTER TABLE ... OWNER TO kiln_owner` (up + down reversal)
5. `GRANT INSERT, SELECT[, UPDATE] ON ... TO kiln_app` (NO DELETE for audit-like tables)

---

### Correlation-id propagation via Logger.metadata + Kiln.Telemetry.pack/unpack_ctx

**Source:** `/Users/jon/projects/kiln/lib/kiln/logger/metadata.ex` + `/Users/jon/projects/kiln/lib/kiln/telemetry/oban_handler.ex`

**Apply to:** Every Phase 2 Oban worker's `perform/1`, every GenServer handler that writes audit events.

**Shape:**
- Enqueue side: `Oban.insert(%{...}, meta: %{"kiln_ctx" => Kiln.Telemetry.pack_ctx()})`
- Perform side: first line of `perform/1` is `Kiln.Telemetry.unpack_ctx(job.meta["kiln_ctx"])` (or rely on P1's `ObanHandler` telemetry — already attached)
- Inside the function, `Logger.metadata()[:correlation_id]` is non-nil and is read by `Kiln.Audit.append/1` and `Kiln.ExternalOperations.*` as the correlation fallback

---

### Ecto schema convention for UUIDv7 PK + Jason.Encoder + Ecto.Enum + read_after_writes

**Source:** `/Users/jon/projects/kiln/lib/kiln/external_operations/operation.ex` (or `/Users/jon/projects/kiln/lib/kiln/audit/event.ex` — either works, Operation is newer)

**Apply to:** `Kiln.Runs.Run`, `Kiln.Stages.StageRun`, `Kiln.Artifacts.Artifact`.

**Shape:**
```elixir
use Ecto.Schema
import Ecto.Changeset

@type t :: %__MODULE__{}
@primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
@foreign_key_type :binary_id

@states [...]  # module-local atoms for any enum field

@derive {Jason.Encoder, only: [...]}

schema "..." do
  field(:state, Ecto.Enum, values: @states, default: :...)
  # ...
  timestamps(type: :utc_datetime_usec)  # or only inserted_at for append-only tables
end

def changeset(...), do: ... |> cast(...) |> validate_required(...) |> validate_inclusion(:state, @states)
def states, do: @states
```

---

## No Analog Found

Files with no direct Phase 1 analog (planner uses RESEARCH.md patterns + stdlib docs):

| File | Role | Data Flow | Reason | Pattern Source |
|------|------|-----------|--------|----------------|
| `lib/kiln/workflows/loader.ex` | loader | read-only transform | No YAML code in P1 | RESEARCH.md Pattern 2 |
| `lib/kiln/workflows/graph.ex` | graph transform | read-only | No graph code in P1 | RESEARCH.md Pattern 3 + `:digraph` stdlib |
| `lib/kiln/workflows/compiler.ex` | transform | read-only | No workflow compile in P1 | RESEARCH.md §Architecture (D-62 validators) |
| `lib/kiln/workflows/compiled_graph.ex` | struct | data | `Kiln.Scope` is closest (defstruct+@type t) but doesn't need the full pattern | stdlib `defstruct` + `@type t` |
| `lib/kiln/runs/run_supervisor.ex` | DynamicSupervisor | process tree | No DynamicSupervisor in P1 | Elixir stdlib `DynamicSupervisor` + D-95 `max_children: 10` |
| `lib/kiln/runs/run_director.ex` | GenServer | side-effect (process spawn) | No GenServer in P1 (closest is `Kiln.Telemetry.ObanHandler` but it's a telemetry handler, not GenServer) | RESEARCH.md Pattern 6 (verbatim) |
| `lib/kiln/runs/run_subtree.ex` | Supervisor | process tree | Net-new per-run subtree | stdlib `Supervisor` + `:one_for_all` strategy |
| `lib/kiln/artifacts/cas.ex` | file-I/O | fs streaming | No fs artifact code in P1 | RESEARCH.md Pattern 5 + POSIX rename(2) |
| `lib/kiln/policies/stuck_detector.ex` | GenServer | request-response | No GenServer in P1; sanctioned exception to D-42 | Standard GenServer module — `init/1` + `handle_call({:check, ctx}, ...)` returning `:ok` (no-op body per D-91) |
| `priv/workflows/elixir_phoenix_feature.yaml` | fixture | data | Net-new | D-58/D-59 canonical shape |
| `test/support/fixtures/workflows/minimal_two_stage.yaml` | test fixture | data | Net-new | D-64b 2-stage minimal shape |
| `test/kiln/artifacts/cas_test.exs` | test | file-I/O | No fs test pattern in P1 | Standard `ExUnit.Case` + `System.tmp_dir!/0` + tempfile cleanup |
| `test/integration/rehydration_test.exs` | integration test | process + DB | Signature ORCH-04 scenario; no prior pattern | Compose primitives: `Process.exit/2` + `Process.whereis/1` + `Repo` direct reads + `assert Repo.aggregate(..., :count) == 1` |

---

## Metadata

**Analog search scope:**
- `lib/kiln/audit/**/*.ex` — primary analogs for JSV SchemaRegistry, Ecto schema, Audit.append transactional pattern
- `lib/kiln/external_operations/**/*.ex` + `lib/kiln/external_operations.ex` — primary analogs for Ecto schema with Ecto.Enum, command-module transaction pattern, Oban cron worker
- `lib/kiln/oban/base_worker.ex` — analog for Oban worker use-pattern
- `lib/kiln/application.ex`, `lib/kiln/boot_checks.ex` — analogs for supervision-tree extension + boot invariants
- `priv/repo/migrations/` — analogs for table-creation DDL with enum CHECK + indexes + role grants + owner transfer
- `priv/audit_schemas/v1/*.json` — analogs for JSON Schema 2020-12 structure
- `test/kiln/audit/`, `test/kiln/external_operations_test.exs`, `test/kiln/oban/base_worker_test.exs`, `test/kiln/application_test.exs` — analogs for test style (DataCase, Logger.metadata setup, Audit.replay cross-check, supervision-tree invariant test)
- `config/config.exs` — analog for Oban queue/plugin config block

**Files scanned:** ~30 source files + 22 schema files + 6 migrations + 5 test files

**Key cross-cutting conventions extracted:**
1. Every Ecto schema uses `@primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}` with DB-side `uuid_generate_v7()` default
2. Every state enum is `@states [...]` module attribute + `Ecto.Enum` field + `validate_inclusion/3` + public `states/0` accessor
3. Every command module opens `Repo.transaction` (P1) or `Repo.transact` (new P2 per RESEARCH.md), performs mutation + `Audit.append/1` in the same closure, returns `{:ok, updated}` or `Repo.rollback(reason)`
4. Every Oban worker is `use Kiln.Oban.BaseWorker, queue: :<name>` unless it's maintenance/cron (those use bare `Oban.Worker`)
5. Every migration follows: `create table` → enum CHECK via `Enum.map_join` → indexes → `ALTER OWNER TO kiln_owner` → `GRANT ... TO kiln_app`
6. Every JSON Schema file: `"$schema": "https://json-schema.org/draft/2020-12/schema"` + `"$id": "kiln://..."` + `"type": "object"` + `"required": [...]` + `"properties": {...}` + `"additionalProperties": false`
7. Every Logger-metadata-sensitive callsite reads `Logger.metadata()[:correlation_id] || Ecto.UUID.generate()` as fallback
8. Post-commit side effects (PubSub, Oban enqueues) happen AFTER `Repo.transaction` returns `{:ok, _}`, never inside

**Pattern extraction date:** 2026-04-19
