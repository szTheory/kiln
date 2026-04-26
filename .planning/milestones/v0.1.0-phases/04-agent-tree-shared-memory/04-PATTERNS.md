# Phase 4: Agent Tree & Shared Memory - Pattern Map

**Mapped:** 2026-04-20
**Research source:** `.planning/phases/04-agent-tree-shared-memory/04-RESEARCH.md`
**Files analyzed:** 17
**Analogs found:** 11 / 11 scoped targets

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/kiln/agents/session_supervisor.ex` (modify) | supervisor | event-driven | `lib/kiln/runs/run_subtree.ex` | role-match |
| `lib/kiln/runs/run_subtree.ex` (modify) | supervisor | event-driven | `lib/kiln/runs/run_subtree.ex` | exact |
| `lib/kiln/work_units.ex` (new) | context/service | CRUD + request-response | `lib/kiln/runs/transitions.ex`, `lib/kiln/external_operations.ex`, `lib/kiln/artifacts.ex` | composite |
| `lib/kiln/work_units/work_unit.ex` (new) | schema/model | CRUD | `lib/kiln/runs/run.ex`, `lib/kiln/stages/stage_run.ex`, `lib/kiln/external_operations/operation.ex` | composite |
| `lib/kiln/work_units/work_unit_event.ex` (new) | schema/model | append-only ledger | `lib/kiln/audit/event.ex` | role-match |
| `lib/kiln/work_units/dependency.ex` (new) | schema/model | CRUD | `lib/kiln/external_operations/operation.ex`, `lib/kiln/stages/stage_run.ex` | partial |
| `lib/kiln/work_units/pubsub.ex` (new) | utility | event-driven | `lib/kiln/runs/transitions.ex` | partial |
| `lib/kiln/work_units/ready_query.ex` (new) | utility | transform/query | `lib/kiln/runs.ex`, `lib/kiln/external_operations.ex` | partial |
| `priv/repo/migrations/*_create_work_units*.exs` (new) | migration | CRUD | `priv/repo/migrations/20260419000002_create_runs.exs`, `priv/repo/migrations/20260419000003_create_stage_runs.exs`, `priv/repo/migrations/20260418000006_create_external_operations.exs` | composite |
| `priv/repo/migrations/*_create_work_unit_events*.exs` (new) | migration | append-only ledger | `priv/repo/migrations/20260418000003_create_audit_events.exs`, `priv/repo/migrations/20260418000004_audit_events_immutability.exs` | composite |
| `test/kiln/work_units*_test.exs`, `test/integration/*phase4*` (new) | test | CRUD + event-driven | `test/kiln/runs/transitions_test.exs`, `test/integration/rehydration_test.exs`, `test/integration/run_subtree_crash_test.exs`, `test/kiln/repo/migrations/audit_events_immutability_test.exs` | composite |

## Hard Constraints To Preserve

- **No GenServer-per-work-unit.** The project contract is explicit: work units are Ecto rows plus PubSub, not OTP processes. See [CLAUDE.md](/Users/jon/projects/kiln/CLAUDE.md) and [lib/kiln/runs/run_subtree.ex:20](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:20).
- **Durable coordination stays in Postgres/Ecto.** Runtime processes are transient accelerators only. Copy the `Repo.transact` / row-lock command pattern from [lib/kiln/runs/transitions.ex:5](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex:5) and [lib/kiln/external_operations.ex:19](/Users/jon/projects/kiln/lib/kiln/external_operations.ex:19).
- **PubSub only after commit.** `Transitions` is the local canonical pattern; do not broadcast from inside the transaction closure. See [lib/kiln/runs/transitions.ex:105](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex:105).
- **Per-run registry naming.** New per-run supervisors/workers should use `{:via, Registry, {Kiln.RunRegistry, {..., run_id}}}` naming like [lib/kiln/runs/run_subtree.ex:117](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:117).
- **Current supervision-tree shape is authoritative.** Per-run runtime hangs under `RunSupervisor -> RunSubtree`; Phase 4 extends that tree instead of adding a second owner. See [lib/kiln/application.ex:78](/Users/jon/projects/kiln/lib/kiln/application.ex:78), [lib/kiln/runs/run_supervisor.ex:3](/Users/jon/projects/kiln/lib/kiln/runs/run_supervisor.ex:3), [lib/kiln/runs/run_director.ex:6](/Users/jon/projects/kiln/lib/kiln/runs/run_director.ex:6).
- **Append-only ledgers stay append-only.** `work_unit_events` should copy the `audit_events` immutability posture, not the mutable current-state table shape. See [priv/repo/migrations/20260418000004_audit_events_immutability.exs:3](/Users/jon/projects/kiln/priv/repo/migrations/20260418000004_audit_events_immutability.exs:3).
- **Tests must handle singleton/runtime processes explicitly.** Reuse sandbox-allow and singleton reset patterns from [test/support/rehydration_case.ex:128](/Users/jon/projects/kiln/test/support/rehydration_case.ex:128) and concurrent DB access setup from [test/kiln/runs/transitions_test.exs:219](/Users/jon/projects/kiln/test/kiln/runs/transitions_test.exs:219).
- **Current global `Kiln.Agents.SessionSupervisor` is a scaffold, not the final Phase 4 ownership model.** It currently starts as a named global `DynamicSupervisor`; Phase 4 plans must migrate it toward per-run ownership under `RunSubtree` without losing app-tree expectations accidentally. See [lib/kiln/agents/session_supervisor.ex:6](/Users/jon/projects/kiln/lib/kiln/agents/session_supervisor.ex:6) and [test/kiln/application_test.exs:31](/Users/jon/projects/kiln/test/kiln/application_test.exs:31).

## Pattern Assignments

### `lib/kiln/agents/session_supervisor.ex` (modify)

**Use as primary analog:** [lib/kiln/runs/run_subtree.ex](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex)

This module should stop behaving like a global singleton and start looking like a per-run child under `RunSubtree`.

**Per-run child spec + registry naming** from [lib/kiln/runs/run_subtree.ex:63](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:63):

```elixir
def child_spec(opts) do
  run_id = Keyword.fetch!(opts, :run_id)

  %{
    id: {__MODULE__, run_id},
    start: {__MODULE__, :start_link, [opts]},
    restart: :transient,
    shutdown: 5_000,
    type: :supervisor
  }
end

def start_link(opts) do
  run_id = Keyword.fetch!(opts, :run_id)
  Supervisor.start_link(__MODULE__, opts, name: via(run_id))
end
```

**Two-layer supervision (preserve both):**

1. **`RunSubtree`** — `:one_for_all` over its per-run children (today: `SessionSupervisor` only; future siblings such as sandboxes follow the same subtree contract) from [lib/kiln/runs/run_subtree.ex](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex):

```elixir
Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
```

2. **`SessionSupervisor` (per-run)** — **`:one_for_one`** over the seven fixed role workers in [lib/kiln/agents/session_supervisor.ex](/Users/jon/projects/kiln/lib/kiln/agents/session_supervisor.ex) so one role crash restarts only that process; coordination stays in `Kiln.WorkUnits`.

**Constraint:** legacy global `SessionSupervisor` boot remains an empty `Supervisor` until removed from the app tree; per-run mode is the target shape for seven role workers.

### `lib/kiln/runs/run_subtree.ex` (modify)

**Use as primary analog:** [lib/kiln/runs/run_subtree.ex](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex)

Phase 4 should change only the child list and helper surface, not the ownership model.

**Existing child replacement comment is already the plan** at [lib/kiln/runs/run_subtree.ex:46](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:46):

```elixir
children = [
  {Kiln.Agents.SessionSupervisor, run_id: run_id},
  {Kiln.Sandboxes.Supervisor, run_id: run_id}
]
```

**Registry lookup pattern** from [lib/kiln/runs/run_subtree.ex:109](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:109):

```elixir
def lived_child_pid(run_id) do
  case Registry.lookup(Kiln.RunRegistry, {__MODULE__.Tasks, run_id}) do
    [{pid, _}] when is_pid(pid) -> pid
    _ -> nil
  end
end
```

Phase 4 can generalize this helper shape for session supervisor / role pids rather than inventing a second registry.

### `lib/kiln/work_units.ex` (new)

**Use as primary analogs:** [lib/kiln/runs/transitions.ex](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex), [lib/kiln/external_operations.ex](/Users/jon/projects/kiln/lib/kiln/external_operations.ex), [lib/kiln/artifacts.ex](/Users/jon/projects/kiln/lib/kiln/artifacts.ex)

This should be a thin public context with command-style functions that own row locking, audit pairing, and post-commit broadcast.

**Canonical transaction + row-lock command pattern** from [lib/kiln/runs/transitions.ex:93](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex:93):

```elixir
result =
  Repo.transact(fn ->
    with {:ok, run} <- lock_run(run_id),
         :ok <- assert_allowed(run.state, to),
         {:ok, updated} <- update_state(run, to, meta),
         {:ok, _event} <- append_audit(updated, run.state, to, meta) do
      {:ok, updated}
    end
  end)
```

**Post-commit broadcast pattern** from [lib/kiln/runs/transitions.ex:109](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex:109):

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

**Conflict / winner re-read pattern** for claim-style APIs from [lib/kiln/external_operations.ex:84](/Users/jon/projects/kiln/lib/kiln/external_operations.ex:84):

```elixir
case Repo.insert(changeset,
       on_conflict: :nothing,
       conflict_target: :idempotency_key
     ) do
  {:ok, %Operation{id: nil}} ->
    Repo.one!(from(o in Operation, where: o.idempotency_key == ^idempotency_key, lock: "FOR UPDATE"))
```

Use that pattern for “claim if still open” or deduped work-unit creation.

**Atomic row write + paired ledger insert** from [lib/kiln/artifacts.ex:81](/Users/jon/projects/kiln/lib/kiln/artifacts.ex:81):

```elixir
Repo.transact(fn ->
  with {:ok, artifact} <- Repo.insert(cs),
       {:ok, _ev} <- Audit.append(%{...}) do
    {:ok, artifact}
  end
end)
```

### `lib/kiln/work_units/work_unit.ex` (new)

**Use as primary analogs:** [lib/kiln/stages/stage_run.ex](/Users/jon/projects/kiln/lib/kiln/stages/stage_run.ex), [lib/kiln/runs/run.ex](/Users/jon/projects/kiln/lib/kiln/runs/run.ex), [lib/kiln/external_operations/operation.ex](/Users/jon/projects/kiln/lib/kiln/external_operations/operation.ex)

Copy the local schema conventions:

- `@primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}`
- `@foreign_key_type :binary_id`
- `Ecto.Enum` for bounded state/kind fields
- app-layer validations plus matching DB constraint names

**Schema + enum pattern** from [lib/kiln/stages/stage_run.ex:39](/Users/jon/projects/kiln/lib/kiln/stages/stage_run.ex:39):

```elixir
@primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
@foreign_key_type :binary_id

field(:state, Ecto.Enum, values: @states, default: :pending)
```

**Constraint wiring pattern** from [lib/kiln/stages/stage_run.ex:117](/Users/jon/projects/kiln/lib/kiln/stages/stage_run.ex:117):

```elixir
|> unique_constraint([:run_id, :workflow_stage_id, :attempt],
  name: :stage_runs_run_stage_attempt_idx
)
|> check_constraint(:state, name: :stage_runs_state_check)
```

**Hot-path denormalized fields belong on the mutable row, not in audit payloads** from [lib/kiln/stages/stage_run.ex:4](/Users/jon/projects/kiln/lib/kiln/stages/stage_run.ex:4). Phase 4’s `blockers_open_count` follows that pattern.

### `lib/kiln/work_units/work_unit_event.ex` (new)

**Use as primary analogs:** [lib/kiln/audit/event.ex](/Users/jon/projects/kiln/lib/kiln/audit/event.ex), [lib/kiln/audit.ex](/Users/jon/projects/kiln/lib/kiln/audit.ex)

The event table is the append-only history, distinct from the mutable `work_units` read model.

**Append-only event schema conventions** from [lib/kiln/audit/event.ex:37](/Users/jon/projects/kiln/lib/kiln/audit/event.ex:37):

```elixir
@primary_key {:id, :binary_id, autogenerate: false, read_after_writes: true}
@foreign_key_type :binary_id

schema "audit_events" do
  field(:event_kind, Ecto.Enum, values: EventKind.values())
  field(:payload, :map, default: %{})
  field(:occurred_at, :utc_datetime_usec)
  timestamps(type: :utc_datetime_usec, updated_at: false)
end
```

**Important constraint:** do not collapse current state and history into one table. This codebase already separates mutable state (`runs`, `stage_runs`, `external_operations`) from immutable history (`audit_events`).

### `lib/kiln/work_units/pubsub.ex` (new)

**Use as primary analog:** [lib/kiln/runs/transitions.ex](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex)

Topic helpers should be plain string builders plus small broadcast wrappers. Keep them outside the transaction and keep payloads small.

**Broadcast shape to copy** from [lib/kiln/runs/transitions.ex:111](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex:111):

```elixir
Phoenix.PubSub.broadcast(Kiln.PubSub, "run:#{run.id}", {:run_state, run})
Phoenix.PubSub.broadcast(Kiln.PubSub, "runs:board", {:run_state, run})
```

For Phase 4, the research topics `work_units`, `work_units:<id>`, and `work_units:run:<run_id>` should follow this exact pattern.

### `lib/kiln/work_units/ready_query.ex` (new)

**Use as primary analogs:** [lib/kiln/runs.ex](/Users/jon/projects/kiln/lib/kiln/runs.ex), [lib/kiln/external_operations.ex](/Users/jon/projects/kiln/lib/kiln/external_operations.ex)

Keep read-model queries as simple `from(...) |> Repo.all()` helpers in the context layer.

**Simple query helper pattern** from [lib/kiln/runs.ex:68](/Users/jon/projects/kiln/lib/kiln/runs.ex:68):

```elixir
from(r in Run,
  where: r.state in ^active,
  order_by: [asc: r.inserted_at]
)
|> Repo.all()
```

Phase 4’s ready queue should stay query-driven (`blockers_open_count == 0`, stable ordering) instead of scanning process state.

### Migrations for `work_units`, `dependencies`, `work_unit_events`

**Use as primary analogs:** [priv/repo/migrations/20260419000002_create_runs.exs](/Users/jon/projects/kiln/priv/repo/migrations/20260419000002_create_runs.exs), [priv/repo/migrations/20260419000003_create_stage_runs.exs](/Users/jon/projects/kiln/priv/repo/migrations/20260419000003_create_stage_runs.exs), [priv/repo/migrations/20260418000006_create_external_operations.exs](/Users/jon/projects/kiln/priv/repo/migrations/20260418000006_create_external_operations.exs), [priv/repo/migrations/20260418000003_create_audit_events.exs](/Users/jon/projects/kiln/priv/repo/migrations/20260418000003_create_audit_events.exs), [priv/repo/migrations/20260418000004_audit_events_immutability.exs](/Users/jon/projects/kiln/priv/repo/migrations/20260418000004_audit_events_immutability.exs)

**Migration conventions to copy:**

- uuidv7 PK via `default: fragment("uuid_generate_v7()")`
- app enum mirrored by generated CHECK constraint
- partial indexes for active/ready reads
- owner transfer + explicit `kiln_app` grants
- no DELETE grants on forensic tables

**CHECK generation pattern** from [priv/repo/migrations/20260419000003_create_stage_runs.exs:76](/Users/jon/projects/kiln/priv/repo/migrations/20260419000003_create_stage_runs.exs:76):

```elixir
for {col, vals} <- [...] do
  list = Enum.map_join(vals, ", ", &"'#{&1}'")

  execute(
    "ALTER TABLE stage_runs ADD CONSTRAINT stage_runs_#{col}_check CHECK (#{col} IN (#{list}))",
    "ALTER TABLE stage_runs DROP CONSTRAINT stage_runs_#{col}_check"
  )
end
```

**Append-only immutability enforcement** from [priv/repo/migrations/20260418000004_audit_events_immutability.exs:31](/Users/jon/projects/kiln/priv/repo/migrations/20260418000004_audit_events_immutability.exs:31):

```sql
CREATE OR REPLACE FUNCTION audit_events_immutable() RETURNS trigger ...
CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON audit_events ...
CREATE RULE audit_events_no_update_rule AS ON UPDATE TO audit_events DO INSTEAD NOTHING
ALTER TABLE audit_events DISABLE RULE audit_events_no_update_rule
```

Use this for `work_unit_events`, not for `work_units`.

### Tests for Phase 4 runtime/data layer

**Use as primary analogs:** [test/kiln/runs/transitions_test.exs](/Users/jon/projects/kiln/test/kiln/runs/transitions_test.exs), [test/integration/rehydration_test.exs](/Users/jon/projects/kiln/test/integration/rehydration_test.exs), [test/integration/run_subtree_crash_test.exs](/Users/jon/projects/kiln/test/integration/run_subtree_crash_test.exs), [test/kiln/repo/migrations/audit_events_immutability_test.exs](/Users/jon/projects/kiln/test/kiln/repo/migrations/audit_events_immutability_test.exs)

**What to copy:**

- command tests verify allowed edges, audit pairing, no-op on rejects, after-commit PubSub, and concurrency with real row locks
- integration tests verify subtree crash containment and rehydration through the real singleton `RunDirector`
- migration tests verify each append-only enforcement layer independently

**Concurrent row-lock test pattern** from [test/kiln/runs/transitions_test.exs:227](/Users/jon/projects/kiln/test/kiln/runs/transitions_test.exs:227):

```elixir
tasks =
  for _ <- 1..2 do
    Task.async(fn ->
      Ecto.Adapters.SQL.Sandbox.allow(Kiln.Repo, parent, self())
      Transitions.transition(run.id, :planning)
    end)
  end
```

**Rehydration/singleton reset pattern** from [test/support/rehydration_case.ex:151](/Users/jon/projects/kiln/test/support/rehydration_case.ex:151):

```elixir
case Process.whereis(director) do
  nil -> :ok
  pid ->
    _ = try_allow_sandbox(pid)
    send(pid, :boot_scan)
    Process.sleep(100)
end
```

**Append-only migration test shape** from [test/kiln/repo/migrations/audit_events_immutability_test.exs:16](/Users/jon/projects/kiln/test/kiln/repo/migrations/audit_events_immutability_test.exs:16): test each layer independently instead of only testing the whole stack once.

## Shared Patterns

### Durable Command Modules

**Sources:** [lib/kiln/runs/transitions.ex](/Users/jon/projects/kiln/lib/kiln/runs/transitions.ex), [lib/kiln/external_operations.ex](/Users/jon/projects/kiln/lib/kiln/external_operations.ex), [lib/kiln/artifacts.ex](/Users/jon/projects/kiln/lib/kiln/artifacts.ex)

Apply to all `Kiln.WorkUnits` write APIs:

- open one transaction
- lock or dedupe at the DB boundary
- mutate current-state row
- append companion ledger/audit row in the same transaction
- broadcast only after commit

### Compile-Time Registry Pattern

**Sources:** [lib/kiln/audit/schema_registry.ex](/Users/jon/projects/kiln/lib/kiln/audit/schema_registry.ex), [lib/kiln/workflows/schema_registry.ex](/Users/jon/projects/kiln/lib/kiln/workflows/schema_registry.ex), [lib/kiln/stages/contract_registry.ex](/Users/jon/projects/kiln/lib/kiln/stages/contract_registry.ex), [lib/kiln/blockers/playbook_registry.ex](/Users/jon/projects/kiln/lib/kiln/blockers/playbook_registry.ex)

If Phase 4 adds a work-unit event schema registry or topic registry, follow the local compile-time `@external_resource` pattern instead of runtime file reads.

### Registry-Based Per-Run Addressing

**Sources:** [lib/kiln/runs/run_subtree.ex:35](/Users/jon/projects/kiln/lib/kiln/runs/run_subtree.ex:35), [lib/kiln/application.ex:85](/Users/jon/projects/kiln/lib/kiln/application.ex:85)

Per-run runtime names should live in `Kiln.RunRegistry`; do not add ad hoc global names for each role process.

### Append-Only Taxonomy Discipline

**Sources:** [lib/kiln/audit/event_kind.ex](/Users/jon/projects/kiln/lib/kiln/audit/event_kind.ex), [test/kiln/audit/append_test.exs:34](/Users/jon/projects/kiln/test/kiln/audit/append_test.exs:34)

Work-unit event kinds already exist in the audit taxonomy (`:work_unit_created`, `:work_unit_state_changed`). If Phase 4 starts emitting them, add the missing JSON schemas/tests rather than inventing parallel ad hoc payloads.

## Anti-Patterns To Avoid

- Do not model work units as OTP children. The codebase already calls this out as an anti-pattern; keep OTP for run/session/role behavior only.
- Do not broadcast before commit. `Transitions` documents this explicitly.
- Do not let role workers write schemas directly. Current local practice is context-owned mutations.
- Do not store ready-queue state only in memory. Use denormalized DB columns and query helpers.
- Do not make `work_unit_events` mutable. Copy the `audit_events` append-only enforcement.
- Do not add a second per-run naming mechanism when `Kiln.RunRegistry` already exists.

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/kiln/agents/roles/*.ex` | worker | event-driven | There is no existing specialized per-run role worker module yet; use `RunSubtree`/`SessionSupervisor` for supervision shape and keep durable state in `Kiln.WorkUnits`. |
| `lib/kiln/work_units/dependency.ex` | schema/model | graph-like CRUD | No current dependency-edge schema exists; closest local analog is “state row + indexed query + no direct process state” from `StageRun` and `ExternalOperations.Operation`. |

## Metadata

- **Analog search scope:** `lib/kiln/runs`, `lib/kiln/agents`, `lib/kiln/audit`, `lib/kiln/stages`, `lib/kiln/external_operations`, `lib/kiln/artifacts`, `priv/repo/migrations`, `test/kiln`, `test/integration`, `test/support`
- **Pattern extraction date:** 2026-04-20
