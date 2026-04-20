# Phase 4: Agent Tree & Shared Memory - Research

**Researched:** 2026-04-20
**Domain:** OTP-supervised multi-agent runtime + Ecto-backed shared work ledger for Phoenix/Elixir
**Confidence:** HIGH

## User Constraints

No phase-specific `CONTEXT.md` exists for Phase 4, so planning is constrained by `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`, and `CLAUDE.md`. [VERIFIED: gsd init.phase-op] [VERIFIED: codebase grep]

- Locked phase goal: specialized agents run as supervised OTP processes per-run and coordinate through a native Ecto work-unit store with PubSub; no shell-out to `bd`, and no GenServer-per-work-unit. [VERIFIED: codebase grep]
- Locked success criteria: per-run `Kiln.Agents.SessionSupervisor`, seven role processes, append-only `work_unit_events`, three-tier PubSub topics, `blockers_open_count` ready-queue cache, and no destructive-by-default CLI surface. [VERIFIED: codebase grep]
- Existing runtime shape to preserve: per-run subtrees already hang under `Kiln.Runs.RunSupervisor`, and `Kiln.Agents.SessionSupervisor` already exists as a Phase 3 scaffold in the application tree. [VERIFIED: codebase grep]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AGENT-03 | Specialized agent roles as OTP processes under per-run `Agents.SessionSupervisor`; agent crash does not kill the run. [VERIFIED: codebase grep] | Use a per-run static `Supervisor` with `:one_for_all` semantics under the existing `RunSubtree`, plus role modules that share a common behaviour and persist all durable coordination state outside process memory. [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] [VERIFIED: codebase grep] |
| AGENT-04 | Agent-shared memory via native Ecto `work_units` + append-only `work_unit_events` + Phoenix.PubSub. [VERIFIED: codebase grep] | Use `Repo.transact/2`, `Ecto.Multi`, row locks, and PubSub after commit; keep current state in `work_units`, history in `work_unit_events`, and readiness in a denormalized `blockers_open_count` column. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
</phase_requirements>

## Summary

Phase 4 should extend the existing run subtree instead of inventing a second orchestration layer. The current codebase already has `RunSupervisor`, `RunSubtree`, `RunDirector`, a global `Kiln.Agents.SessionSupervisor` scaffold, and a convention that Postgres is the source of truth while OTP processes are transient accelerators. The correct Phase 4 move is to keep durable work coordination in Ecto and use OTP only for role behavior and crash isolation. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html]

The standard implementation pattern is: `RunDirector` hydrates a per-run subtree, the subtree owns a per-run agent-session supervisor, the role processes read and mutate work units through a `Kiln.WorkUnits` context, each mutation writes current state plus an append-only event in one transaction, and PubSub fan-out happens only after commit. That gives atomic claims, replayable history, fast board updates, and a clean failure model. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

The main unknowns are not library choice. They are queue semantics, handoff protocol, and where to denormalize for speed. The safest answer is to make `work_units` the mutable read model, keep `work_unit_events` immutable, treat blockers as explicit dependency rows reflected into `blockers_open_count`, and make claim/handoff operations database-serialized rather than process-coordinated. [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] [ASSUMED]

**Primary recommendation:** Build Phase 4 as `RunSubtree -> per-run SessionSupervisor -> seven role workers`, backed by `Kiln.WorkUnits` using `Repo.transact/2` + row locking + after-commit PubSub, with no process-per-unit state. [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-run agent lifecycle | API / Backend | Database / Storage | Session and role processes are OTP concerns; DB only stores recoverable state. [CITED: https://hexdocs.pm/elixir/Supervisor.html] [VERIFIED: codebase grep] |
| Work-unit creation/claim/block/close | Database / Storage | API / Backend | Claims and blocker updates must be transactionally serialized in Postgres, then surfaced through context APIs. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://www.postgresql.org/docs/15/sql-select.html] |
| Crash recovery / rehydration | API / Backend | Database / Storage | `RunDirector` already rebuilds runtime state from active runs in Postgres; Phase 4 should extend that pattern. [VERIFIED: codebase grep] |
| Ready queue (`bd ready` equivalent) | Database / Storage | API / Backend | Readiness is a query problem over denormalized blocker counts and priority ordering, not a process-message problem. [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] [ASSUMED] |
| Agent-to-agent handoff visibility | API / Backend | Browser / Client | Handoffs are persisted as work-unit events and then broadcast to UI subscribers via PubSub. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [ASSUMED] |
| Operator live updates | Browser / Client | API / Backend | LiveView subscribes; backend owns topic naming and event payloads. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [VERIFIED: codebase grep] |

## Project Constraints (from CLAUDE.md)

- This is a Phoenix web application; use the existing Phoenix, LiveView, Ecto, and Tailwind patterns already in the repo. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- Use `Req` for HTTP requests; avoid `:httpoison`, `:tesla`, and `:httpc`. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- Repo guidance says to run `mix precommit` when done, but this repo currently has no `precommit` Mix task or alias, so the planner must not assume it exists as-is. [CITED: /Users/jon/projects/kiln/CLAUDE.md] [VERIFIED: mix help precommit]
- Never nest multiple modules in one file; never use map-access syntax on structs; never use `String.to_atom/1` on user input. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- Use OTP primitives (`DynamicSupervisor`, `Registry`, `Task.async_stream`) idiomatically; do not build fake process architectures for plain data. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- For Ecto: preload associations used in templates, use `Ecto.Changeset.get_field/2`, do not cast programmatic fields like `user_id`, and generate migrations with `mix ecto.gen.migration name_using_underscores`. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- For LiveView/UI work that touches this phase later: use streams for collections, use `<Layouts.app ...>` in LiveView templates, do not use inline `<script>`, and use imported core components like `<.input>` and `<.icon>`. [CITED: /Users/jon/projects/kiln/CLAUDE.md]
- For tests: use `start_supervised!/1`, avoid `Process.sleep/1` and `Process.alive?/1` when possible, prefer monitors and `_ = :sys.get_state/1` for synchronization. [CITED: /Users/jon/projects/kiln/CLAUDE.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / OTP | `1.19.5` / `28.1+` [VERIFIED: local runtime] | Supervision, GenServer, DynamicSupervisor, Registry | The current repo runtime and the official docs used here are on Elixir `1.19.5`; supervision semantics and `DynamicSupervisor` APIs are stable there. [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] [CITED: https://hexdocs.pm/elixir/Supervisor.html] |
| `ecto` + `ecto_sql` | `3.13.5` [VERIFIED: hex.pm registry] | Transactional work-unit store, migrations, locking queries | `Repo.transact/2`, `Ecto.Multi`, and lock expressions are the right substrate for atomic claims and append-only event writes. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] |
| PostgreSQL | `16.x` target, server reachable on `localhost:5432` [VERIFIED: codebase grep] [VERIFIED: pg_isready] | Durable source of truth for `work_units`, events, and ready-queue indexes | Postgres row locks and partial indexes are the established answer for queue-like tables with multiple consumers. [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] |
| `phoenix_pubsub` | `2.2.0` [VERIFIED: hex.pm registry] | Three-tier broadcasts (`work_units`, `work_units:<id>`, `work_units:run:<run_id>`) | Phoenix PubSub is already in the application tree and exposes simple `subscribe/3`, `broadcast/4`, and `broadcast_from/5` APIs. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `DynamicSupervisor` | stdlib in Elixir `1.19.5` [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] | Spawn per-run session supervisors or run-owned supervisors dynamically | Use at the run boundary, not for every work unit. [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] |
| `Supervisor` | stdlib in Elixir `1.19.5` [CITED: https://hexdocs.pm/elixir/Supervisor.html] | Own the seven fixed role workers under `:one_for_all` | Use for the static per-run role set where sibling restart semantics matter. [CITED: https://hexdocs.pm/elixir/Supervisor.html] |
| `Registry` | stdlib in Elixir `1.19.5` [VERIFIED: codebase grep] | Per-run name registration and lookup | Use for addressing per-run supervisors or roles by `{role, run_id}` without scanning supervisors. [VERIFIED: codebase grep] [ASSUMED] |
| `oban` | `2.21.1` [VERIFIED: hex.pm registry] | Bootstrap, escalation, or eventual background reconciliation jobs | Keep Oban for durable jobs around runs; do not use it as the primary shared-memory mechanism. [VERIFIED: codebase grep] [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native Ecto work ledger [VERIFIED: codebase grep] | Shelling out to `bd` / Dolt [VERIFIED: codebase grep] | Rejected because it breaks shared transactions with Postgres, adds a second datastore, and conflicts with the roadmap’s “no shell-out to `bd`” decision. [VERIFIED: codebase grep] |
| Per-run static role supervisor [CITED: https://hexdocs.pm/elixir/Supervisor.html] | Dynamic child spawn for every role action [ASSUMED] | Rejected because the role set is fixed and crash semantics are easier to reason about with a static tree. [ASSUMED] |
| Ecto rows for work units [VERIFIED: codebase grep] | GenServer-per-work-unit [VERIFIED: codebase grep] | Rejected because work units are data, not behavior; process-per-unit adds runtime cost without improving durability or queryability. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] |

**Installation:** Existing dependencies are already present in `mix.exs` and locked in `mix.lock`; Phase 4 should not add a new coordination library. [VERIFIED: codebase grep]

```bash
mix deps.get
```

**Version verification:** [VERIFIED: hex.pm registry]

- `phoenix` `1.8.5` — published `2026-03-05T15:22:23Z`
- `phoenix_pubsub` `2.2.0` — published `2025-10-22T17:14:04Z`
- `ecto_sql` `3.13.5` — published `2026-03-03T10:28:33Z`
- `oban` `2.21.1` — published `2026-03-26T12:56:39Z`
- `req` `0.5.17` — published `2026-01-05T21:11:49Z`

## Architecture Patterns

### System Architecture Diagram

Recommended data flow for this phase, derived from the current Kiln run tree plus OTP/Ecto/PubSub semantics. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

```text
Start run / rehydrate
        |
        v
Kiln.Runs.RunDirector
        |
        v
Kiln.Runs.RunSubtree (per run, :one_for_all)
        |
        +--> Kiln.Agents.SessionSupervisor (per-run owner)
                |
                +--> Mayor
                +--> Planner
                +--> Coder
                +--> Tester
                +--> Reviewer
                +--> UIUX
                +--> QAVerifier
                        |
                        v
                 Kiln.WorkUnits context
                        |
                        +--> Repo.transact / Ecto.Multi
                                |
                                +--> work_units (current state)
                                +--> work_unit_events (append-only)
                                +--> blocker edges / counters
                        |
                        v
                 Phoenix.PubSub after commit
                        |
                        +--> work_units
                        +--> work_units:<id>
                        +--> work_units:run:<run_id>
                        |
                        v
                 LiveView / other subscribers
```

### Recommended Project Structure

```text
lib/kiln/agents/
├── role.ex                  # common behaviour + shared helpers
├── session_supervisor.ex    # per-run owner/supervisor entrypoint
├── roles/
│   ├── mayor.ex
│   ├── planner.ex
│   ├── coder.ex
│   ├── tester.ex
│   ├── reviewer.ex
│   ├── uiux.ex
│   └── qa_verifier.ex
lib/kiln/work_units/
├── work_unit.ex             # current-state schema
├── work_unit_event.ex       # append-only event schema
├── dependency.ex            # blocker/related edges
├── ready_query.ex           # ready-queue query helpers
└── pubsub.ex                # topic helpers + payload shaping
lib/kiln/work_units.ex       # public context API
priv/repo/migrations/        # work_units, work_unit_events, dependency tables, indexes
docs/
└── pubsub-topics-phase-04.md
```

### Pattern 1: Fixed Per-Run Role Tree Under `:one_for_all`

**What:** A per-run `Supervisor` owns the seven role workers as a fixed child set; the subtree uses `:one_for_all` so abnormal child exit restarts sibling state together. [CITED: https://hexdocs.pm/elixir/Supervisor.html] [VERIFIED: codebase grep]

**When to use:** Use this for the specialized role set because the roles are fixed, stateful, and semantically coupled within a run. [ASSUMED]

**Example:**

```elixir
# Source: https://hexdocs.pm/elixir/Supervisor.html
defmodule Kiln.Agents.RunSession do
  use Supervisor

  def start_link(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    Supervisor.start_link(__MODULE__, opts, name: via(run_id))
  end

  @impl true
  def init(opts) do
    run_id = Keyword.fetch!(opts, :run_id)

    children = [
      {Kiln.Agents.Roles.Mayor, run_id: run_id},
      {Kiln.Agents.Roles.Planner, run_id: run_id},
      {Kiln.Agents.Roles.Coder, run_id: run_id},
      {Kiln.Agents.Roles.Tester, run_id: run_id},
      {Kiln.Agents.Roles.Reviewer, run_id: run_id},
      {Kiln.Agents.Roles.UIUX, run_id: run_id},
      {Kiln.Agents.Roles.QAVerifier, run_id: run_id}
    ]

    Supervisor.init(children, strategy: :one_for_all, max_restarts: 3, max_seconds: 5)
  end

  defp via(run_id), do: {:via, Registry, {Kiln.RunRegistry, {__MODULE__, run_id}}}
end
```

### Pattern 2: Context API Owns All Durable Work-Unit Mutations

**What:** Every create/claim/block/unblock/close operation enters through `Kiln.WorkUnits`, which updates the current row, inserts the event row, and only then broadcasts. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] [VERIFIED: codebase grep]

**When to use:** Use for every durable state transition, including handoffs and blocker changes. Do not let role processes update schemas directly. [ASSUMED]

**Example:**

```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
def claim(work_unit_id, agent_role) do
  Ecto.Multi.new()
  |> Ecto.Multi.run(:work_unit, fn repo, _changes ->
    query =
      from(w in Kiln.WorkUnits.WorkUnit,
        where: w.id == ^work_unit_id and is_nil(w.claimed_by_role),
        lock: "FOR UPDATE"
      )

    case repo.one(query) do
      nil -> {:error, :already_claimed}
      unit -> {:ok, unit}
    end
  end)
  |> Ecto.Multi.update(:updated_unit, fn %{work_unit: unit} ->
    Kiln.WorkUnits.WorkUnit.claim_changeset(unit, %{claimed_by_role: agent_role})
  end)
  |> Ecto.Multi.insert(:event, fn %{updated_unit: unit} ->
    Kiln.WorkUnits.WorkUnitEvent.changeset(%Kiln.WorkUnits.WorkUnitEvent{}, %{
      work_unit_id: unit.id,
      kind: :claimed,
      actor_role: agent_role
    })
  end)
  |> Kiln.Repo.transact()
end
```

### Pattern 3: Ready Queue Is a Read Model, Not a Recursive Runtime Walk

**What:** Store `blockers_open_count` on the work-unit row and keep it correct on every blocker mutation, then query `where blockers_open_count == 0` with stable ordering. [CITED: https://hexdocs.pm/ecto/Ecto.Query.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [ASSUMED]

**When to use:** Use for `bd ready` equivalence and any work picker used by Mayor or role workers. [ASSUMED]

**Example:**

```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Query.html
def ready_for_run(run_id) do
  from(w in Kiln.WorkUnits.WorkUnit,
    where: w.run_id == ^run_id and w.status in [:open, :in_progress],
    where: w.blockers_open_count == 0,
    order_by: [asc: w.priority, asc: w.inserted_at]
  )
  |> Kiln.Repo.all()
end
```

### Pattern 4: PubSub Topic Helpers, Not Ad-Hoc Strings

**What:** Centralize topic names in one module so producers and subscribers share the same contract. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [ASSUMED]

**When to use:** Use for all three work-unit topic tiers and for any future LiveView subscriptions. [ASSUMED]

### Anti-Patterns to Avoid

- **Global agent supervisor for all runs:** This breaks run isolation and fights the existing `RunSubtree` design. [VERIFIED: codebase grep]
- **GenServer-per-work-unit:** This turns queryable data into runtime state and conflicts with the roadmap and repo conventions. [VERIFIED: codebase grep]
- **Broadcasting from inside the transaction closure:** Subscribers can observe a state change that later rolls back. The existing `Kiln.Runs.Transitions` module already documents the correct after-commit pattern. [VERIFIED: codebase grep]
- **Recursive “ready” query over blocker edges on every read:** This will miss the latency target sooner than maintaining a denormalized counter. [ASSUMED]
- **Destructive recovery commands or `--force` admin flows:** This recreates the beads #2363 failure class that the roadmap explicitly excludes. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-run process restart orchestration | Custom monitor/link graph | `Supervisor` / `DynamicSupervisor` / `Registry` [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/elixir/DynamicSupervisor.html] | OTP already gives the restart semantics, intensity limits, and naming model this phase needs. [CITED: https://hexdocs.pm/elixir/Supervisor.html] |
| Cross-agent claim arbitration | ETS mutex or process mailbox arbitration | Postgres row locks inside `Repo.transact/2` [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | Claims need durability and crash safety, not only in-memory exclusivity. [CITED: https://www.postgresql.org/docs/15/sql-select.html] |
| Fan-out notifications | Ad-hoc process registry broadcast loops | `Phoenix.PubSub.broadcast/4` and `broadcast_from/5` [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] | PubSub already handles topic subscription and sender-suppression semantics. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| Event history compaction | In-place event rewriting or event deletion | Append-only events plus later summary events [VERIFIED: codebase grep] [ASSUMED] | The repo’s durability model is append-only; rewriting history increases recovery risk for little gain in Phase 4. [VERIFIED: codebase grep] [ASSUMED] |
| `bd` interoperability | Full CLI shell-out wrapper | Small JSONL export/import adapter stub [VERIFIED: codebase grep] [ASSUMED] | The roadmap only asks for a migration path, not dual-control-plane operation. [VERIFIED: codebase grep] |

**Key insight:** the hard parts here are concurrency, recovery, and observability; all three already have standard answers in OTP, Postgres, and Phoenix PubSub, so custom coordination mechanisms would mostly add risk. [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

## Common Pitfalls

### Pitfall 1: Reusing the Global `Kiln.Agents.SessionSupervisor`

**What goes wrong:** All runs share one agent supervisor and a crash or restart leaks across runs. [VERIFIED: codebase grep]

**Why it happens:** Phase 3 introduced a global scaffold in the application tree, which is useful as a placeholder but not as the final per-run owner. [VERIFIED: codebase grep]

**How to avoid:** Keep the global Phase 3 scaffold as infrastructure only if needed, but create a per-run session owner under `RunSubtree` for actual role children. [VERIFIED: codebase grep] [ASSUMED]

**Warning signs:** Role names need global uniqueness hacks, or a test for one run sees children from another. [ASSUMED]

### Pitfall 2: Duplicate PubSub Delivery

**What goes wrong:** Subscribers receive the same work-unit event multiple times. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

**Why it happens:** Phoenix PubSub allows duplicate subscriptions for the same pid/topic pair and will deliver duplicate events. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html]

**How to avoid:** Subscribe once per process per topic and centralize subscription setup in `mount/3` or init helpers. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [ASSUMED]

**Warning signs:** LiveView or test processes show doubled counters after a reconnect or re-mount. [ASSUMED]

### Pitfall 3: Claim Logic That Is “Atomic” Only in Elixir

**What goes wrong:** Two agents claim the same work unit under contention. [ASSUMED]

**Why it happens:** A check-then-update pattern runs outside a row lock or outside one transaction. [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]

**How to avoid:** Lock the target row, make the claim decision in the same transaction, and insert the corresponding event before commit. [CITED: https://www.postgresql.org/docs/15/sql-select.html] [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

**Warning signs:** Rare flaky tests where both claimers receive success, or event order shows two `claimed` events with no intervening release. [ASSUMED]

### Pitfall 4: Broadcasting Before Commit

**What goes wrong:** UI and peer agents react to state that never committed. [VERIFIED: codebase grep]

**Why it happens:** The broadcast is emitted inside the transaction closure. [VERIFIED: codebase grep]

**How to avoid:** Follow the same pattern as `Kiln.Runs.Transitions`: transact first, then broadcast on success. [VERIFIED: codebase grep]

**Warning signs:** Subscribers see an event, but a follow-up read cannot find the updated row or event record. [ASSUMED]

### Pitfall 5: Misusing `SKIP LOCKED`

**What goes wrong:** The ready queue behaves nondeterministically or silently starves certain items. [CITED: https://www.postgresql.org/docs/15/sql-select.html]

**Why it happens:** PostgreSQL documents `SKIP LOCKED` as giving an inconsistent view that is acceptable for queue-like consumers but not general-purpose reads. [CITED: https://www.postgresql.org/docs/15/sql-select.html]

**How to avoid:** Use plain indexed reads for the operator-visible ready queue, and reserve `FOR UPDATE SKIP LOCKED` for worker-side claim selection when contention is expected. [CITED: https://www.postgresql.org/docs/15/sql-select.html] [ASSUMED]

**Warning signs:** “Ready” counts flicker during active claiming, or old high-priority units never get picked under load. [ASSUMED]

### Pitfall 6: Compaction That Destroys Recovery Evidence

**What goes wrong:** Old handoffs or blocker reasons disappear, making recovery and audit trails incomplete. [ASSUMED]

**Why it happens:** Compaction is implemented as mutation or deletion of original events instead of additive summarization. [VERIFIED: codebase grep] [ASSUMED]

**How to avoid:** In Phase 4, do not auto-compact event history; if summarization is added later, write summary events and keep originals. [VERIFIED: codebase grep] [ASSUMED]

**Warning signs:** Operators cannot reconstruct why a work unit moved to blocked or who last held it. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### Dynamic Per-Run Start

```elixir
# Source: https://hexdocs.pm/elixir/DynamicSupervisor.html
{:ok, pid} =
  DynamicSupervisor.start_child(
    Kiln.Runs.RunSupervisor,
    {Kiln.Agents.RunSession, run_id: run.id}
  )
```

### Transactional Multi

```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Repo.html
# Source: https://hexdocs.pm/ecto/Ecto.Multi.html
Ecto.Multi.new()
|> Ecto.Multi.insert(:unit, unit_changeset)
|> Ecto.Multi.insert(:event, event_changeset)
|> Kiln.Repo.transact()
```

### Pessimistic Lock Query

```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Query.html
from(w in WorkUnit,
  where: w.id == ^id,
  lock: "FOR UPDATE"
)
```

### Cluster-Wide Broadcast

```elixir
# Source: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html
Phoenix.PubSub.broadcast(
  Kiln.PubSub,
  "work_units:run:#{run_id}",
  {:work_unit_updated, work_unit_id}
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | `Repo.transact/2` [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | Ecto `3.13` [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] | New work-unit code should use `transact/2` to match current Ecto APIs and existing repo conventions. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] |
| Polling or ad-hoc message buses [ASSUMED] | Phoenix PubSub topic fan-out [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] | Mature Phoenix standard, current in `2.2.0` [VERIFIED: hex.pm registry] | Lower coordination code and direct LiveView compatibility. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| Process-per-unit coordination [VERIFIED: codebase grep] | Ecto current-state row + append-only event row [VERIFIED: codebase grep] | Kiln roadmap and architecture decision already locked [VERIFIED: codebase grep] | Better durability, easier queries, and fewer BEAM processes. [VERIFIED: codebase grep] |
| External `bd` CLI as the memory plane [VERIFIED: codebase grep] | Native Ecto work ledger with optional JSONL bridge [VERIFIED: codebase grep] | Locked in Phase 4 roadmap text [VERIFIED: codebase grep] | Keeps a single transactional control plane and avoids destructive CLI recovery paths. [VERIFIED: codebase grep] |

**Deprecated/outdated:**

- `Repo.transaction/2` is deprecated in the current Ecto docs; use `Repo.transact/2`. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- A global-only `Kiln.Agents.SessionSupervisor` is Phase 3 scaffolding, not the final Phase 4 per-run agent tree. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The seven role workers should live under a static per-run `Supervisor` while `SessionSupervisor` remains the per-run owner entrypoint. | Architecture Patterns | Low to medium; implementation may need one extra wrapper module if the current scaffold is reused differently. |
| A2 | `blockers_open_count` should be maintained from explicit dependency rows instead of computed recursively on every ready query. | Architecture Patterns | Medium; if the data model changes, ready-query performance work shifts into SQL/materialized-view design. |
| A3 | Phase 4 should ship with no automatic event compaction and only additive summary events later. | Common Pitfalls | Low; affects retention and storage strategy more than correctness. |
| A4 | Use `SKIP LOCKED` only for worker-side claim picking, not for operator-visible ready reads. | Common Pitfalls | Low; alternative locking choices exist, but using `SKIP LOCKED` broadly would make semantics harder to explain. |

## Open Questions

1. **Should blocker edges live in a dedicated `work_unit_dependencies` table or be encoded only as events plus counters?**
   - What we know: Phase 4 requires `blockers_open_count` and a `bd ready` equivalent. [VERIFIED: codebase grep]
   - What's unclear: whether future UX needs first-class dependency traversal beyond blocker counts. [ASSUMED]
   - Recommendation: use a dedicated dependency table now, because counters without edge rows are hard to repair and audit. [ASSUMED]

2. **What is the minimal handoff contract between roles?**
   - What we know: the roadmap explicitly asks for Mayor delegation and QA reporting semantics. [VERIFIED: codebase grep]
   - What's unclear: whether handoff is represented as work-unit state changes only, or as work-unit events plus mailbox-like artifacts. [ASSUMED]
   - Recommendation: make the first version event-driven: `created`, `claimed`, `blocked`, `unblocked`, `closed`, `handoff_requested`, `handoff_completed`. Add richer mail later only if the event model proves insufficient. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Phase 4 implementation and tests | ✓ [VERIFIED: local runtime] | `1.19.5` | — |
| Mix | Build, migrations, tests | ✓ [VERIFIED: local runtime] | `1.19.5` | — |
| PostgreSQL server | Ecto repo, migrations, work-unit store | ✓ [VERIFIED: pg_isready] | `localhost:5432` accepting connections | — |
| `psql` client | DB inspection and debugging | ✓ [VERIFIED: local runtime] | `14.17` | Repo queries |
| Docker | Some integration suites and broader runtime work | ✓ [VERIFIED: local runtime] | `29.3.1` | Limited unit-only verification |
| Node.js | Asset toolchain and helper scripts | ✓ [VERIFIED: local runtime] | `v22.14.0` | — |

**Missing dependencies with no fallback:**

- None. [VERIFIED: local runtime]

**Missing dependencies with fallback:**

- None. [VERIFIED: local runtime]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Ecto SQL Sandbox + Phoenix.LiveViewTest/LazyHTML present in repo. [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs` and `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/kiln/runs/run_director_test.exs test/integration/run_subtree_crash_test.exs --include integration --max-failures=1` for tree wiring; add new Phase 4 files as they land. [VERIFIED: codebase grep] [ASSUMED] |
| Full suite command | `mix test` plus opt-in integration tags where relevant. [VERIFIED: codebase grep] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AGENT-03 | Per-run session tree starts seven role workers and contains crashes to the run subtree. [VERIFIED: codebase grep] | integration | `mix test test/kiln/agents/session_supervisor_test.exs test/integration/run_subtree_crash_test.exs --include integration --max-failures=1` | ❌ Wave 0 |
| AGENT-03 | Killing one role does not terminate the run; subtree restarts or escalates with typed reason. [VERIFIED: codebase grep] | integration | `mix test test/integration/agent_role_crash_test.exs --include integration --max-failures=1` | ❌ Wave 0 |
| AGENT-04 | Create/claim/block/unblock/close append events and broadcast all three topic tiers. [VERIFIED: codebase grep] | unit | `mix test test/kiln/work_units_test.exs test/kiln/work_units/pubsub_test.exs --max-failures=1` | ❌ Wave 0 |
| AGENT-04 | Cross-agent claim atomicity under contention. [VERIFIED: codebase grep] | integration | `mix test test/integration/work_unit_claim_race_test.exs --max-failures=1` | ❌ Wave 0 |
| AGENT-04 | Ready queue serves unblocked prioritized units from denormalized cache. [VERIFIED: codebase grep] | unit | `mix test test/kiln/work_units/ready_query_test.exs --max-failures=1` | ❌ Wave 0 |
| AGENT-04 | No destructive CLI/default force paths on work-unit admin surface. [VERIFIED: codebase grep] | unit | `mix test test/mix/tasks/work_units_cli_safety_test.exs --max-failures=1` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted `mix test` files for the changed role/context modules. [ASSUMED]
- **Per wave merge:** `mix test --include integration` for the new Phase 4 suite plus existing run-tree tests. [ASSUMED]
- **Phase gate:** full `mix test` green before `/gsd-verify-work`. [VERIFIED: .planning/config.json]

### Wave 0 Gaps

- [ ] `test/kiln/agents/session_supervisor_test.exs` — covers role-tree child set and restart contracts. [ASSUMED]
- [ ] `test/kiln/work_units_test.exs` — covers context CRUD and event append invariants. [ASSUMED]
- [ ] `test/kiln/work_units/pubsub_test.exs` — covers topic routing and after-commit broadcast behavior. [ASSUMED]
- [ ] `test/integration/work_unit_claim_race_test.exs` — covers atomic cross-agent claim behavior. [ASSUMED]
- [ ] `test/integration/agent_role_crash_test.exs` — covers real role crash containment semantics. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [ASSUMED] | Not a Phase 4 concern in this solo local-first phase. [ASSUMED] |
| V3 Session Management | no [ASSUMED] | Not a web-auth/session feature phase. [ASSUMED] |
| V4 Access Control | yes [VERIFIED: codebase grep] | Constrain role capabilities through `Kiln.Agents.Role` APIs and typed context functions; future holdout access rules must not route through broad context reads. [ASSUMED] |
| V5 Input Validation | yes [CITED: https://hexdocs.pm/ecto/Ecto.Changeset.html] | Validate work-unit and event payloads with changesets and enums, not free-form maps at write boundaries. [ASSUMED] |
| V6 Cryptography | no [ASSUMED] | No new crypto primitive should be introduced in this phase. [ASSUMED] |

### Known Threat Patterns for OTP + Ecto + PubSub

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Double claim of the same work unit | Tampering | Row-level lock + single transaction claim path. [CITED: https://www.postgresql.org/docs/15/sql-select.html] |
| Forged role mutation through direct schema writes | Elevation of Privilege | Keep mutations behind `Kiln.WorkUnits` context and avoid public direct `Repo.update` paths for work-unit schemas. [ASSUMED] |
| Duplicate event fan-out from duplicate subscriptions | Denial of Service | Single subscription discipline and topic helper centralization. [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] |
| Destructive recovery tooling | Tampering | No `--force` paths, no default delete/reset operations, and migrations only through `mix ecto.migrate`. [VERIFIED: codebase grep] [CITED: /Users/jon/projects/kiln/CLAUDE.md] |
| Runtime-only state loss after crash | Repudiation | Persist all durable coordination data to Postgres and treat processes as caches/actors only. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- `https://hexdocs.pm/elixir/Supervisor.html` - restart values, `:one_for_all` strategy, shutdown guidance
- `https://hexdocs.pm/elixir/DynamicSupervisor.html` - dynamic child start semantics and `:max_children`
- `https://hexdocs.pm/ecto/Ecto.Repo.html` - `Repo.transact/2`, aborted transaction behavior, process/transaction scope
- `https://hexdocs.pm/ecto/Ecto.Multi.html` - `Multi.run/3` behavior and transactional composition
- `https://hexdocs.pm/ecto/Ecto.Query.html` - `lock/3` query expression
- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html` - partial index support and migration guidance
- `https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html` - subscribe/broadcast APIs and duplicate-subscription behavior
- `https://www.postgresql.org/docs/15/sql-select.html` - `FOR UPDATE`, `NOWAIT`, `SKIP LOCKED` semantics
- Local codebase inspection via `rg`, `sed`, and runtime probes - current Kiln supervision tree, scaffolds, tests, config, and environment availability [VERIFIED: codebase grep] [VERIFIED: local runtime] [VERIFIED: pg_isready] [VERIFIED: mix help precommit]
- Hex registry metadata via `mix hex.info` and Hex API - current package versions and publish timestamps [VERIFIED: hex.pm registry]

### Secondary (MEDIUM confidence)

- `.planning/research/BEADS.md` - prior project synthesis on beads-equivalent behaviors; useful as project context but not treated as sole authority here. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)

- None. [VERIFIED: current research session]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - versions and APIs were verified from Hex registry, official docs, and the current repo. [VERIFIED: hex.pm registry] [VERIFIED: codebase grep]
- Architecture: HIGH - recommendation aligns with existing Kiln runtime scaffolding and official OTP/Ecto/PubSub semantics. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/elixir/Supervisor.html] [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html]
- Pitfalls: MEDIUM - the transactional and PubSub hazards are directly documented; compaction and handoff specifics remain design judgment until Phase 4 implementation proves them. [CITED: https://hexdocs.pm/ecto/Ecto.Repo.html] [CITED: https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html] [ASSUMED]

**Research date:** 2026-04-20
**Valid until:** 2026-05-20
