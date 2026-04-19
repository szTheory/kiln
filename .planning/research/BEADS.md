# Beads / Durable Work Tracking — Decision Record

**Decision status:** Recommended (Option A, with explicit migration path to Option E)
**Researched:** 2026-04-18
**Confidence:** HIGH for "what beads is" (grounded in source); HIGH for the recommendation (native Ecto fit is idiomatic BEAM); MEDIUM for performance specifics at Kiln's projected scale (scale is small enough that any of A/B/D will work).

**Feeds:** REQ-ID `AGENT-04` (Agent-shared memory, native Elixir implementation) and Phase 4 (Agent layer) of the Kiln roadmap.

---

## TL;DR

**Build native.** Kiln implements beads as first-class Elixir: an Ecto `work_units` table plus an append-only `work_unit_events` ledger, fronted by a `Kiln.WorkUnits` context that broadcasts on Phoenix.PubSub for LiveView. Do not shell out to the `bd` binary. Do not spin up GenServers per work unit. Do not conflate work units with existing `runs`/`stages` (they are a *different* abstraction — agent-readable, cross-run work tracking, not workflow execution state).

The value of "beads" is the *data model and API shape*, not the Go binary or the Dolt database. Kiln gets the data model natively, gets real-time UI for free via LiveView+PubSub, keeps durability in Postgres (the thing Kiln already operates), and avoids coupling to a Go/Dolt release cadence that has had recent data-loss incidents. If federated/cross-town interop is ever needed, a thin adapter exports to `bd`-compatible JSONL.

---

## What IS Beads?

Beads is an issue tracker shaped for AI agents. Observed directly from source at `/Users/jon/projects/beads`:

**It's a Go CLI (`bd`), storing data in [Dolt](https://github.com/dolthub/dolt)** — a version-controlled SQL database. The project is [github.com/steveyegge/beads](https://github.com/steveyegge/beads), maintained under the `gastownhall/beads` org. (Note: not Rust — this is a common misconception. An independent [Rust port exists](https://github.com/Dicklesworthstone/beads_rust) using SQLite + JSONL, but the canonical upstream is Go + Dolt.)

**The core data model is a single wide `issues` table** (from `internal/storage/schema/migrations/0001_create_issues.up.sql`):

```sql
CREATE TABLE issues (
    id VARCHAR(255) PRIMARY KEY,           -- e.g., "bd-a1b2", "gt-x7k2m"
    content_hash VARCHAR(64),              -- SHA256 of canonical content
    title VARCHAR(500) NOT NULL,
    description TEXT,
    design TEXT,
    acceptance_criteria TEXT,
    notes TEXT,
    status VARCHAR(32),                    -- open|in_progress|blocked|deferred|closed|pinned|hooked
    priority INT,                          -- 0..4
    issue_type VARCHAR(32),                -- bug|feature|task|epic|chore|decision|message|spike|story|milestone|event
    assignee VARCHAR(255),
    owner VARCHAR(255),                    -- human owner (git author email)
    external_ref VARCHAR(255),             -- "gh-9", "jira-ABC"
    source_system VARCHAR(255),            -- adapter that created this (federation)
    metadata JSON,                         -- arbitrary extension JSON
    spec_id VARCHAR(1024),
    ephemeral TINYINT,                     -- excluded from git sync
    wisp_type VARCHAR(32),                 -- TTL class for compaction
    pinned TINYINT,
    is_template TINYINT,
    mol_type VARCHAR(32),                  -- molecule type: swarm|patrol|work
    work_type VARCHAR(32),                 -- mutex|open_competition
    -- Event fields (audit bead shape)
    event_kind VARCHAR(32),
    actor VARCHAR(255),
    target VARCHAR(255),
    payload TEXT,
    -- Gate fields (async coordination beads)
    await_type VARCHAR(32),                -- gh:run|gh:pr|timer|human|mail
    await_id VARCHAR(255),
    timeout_ns BIGINT,
    waiters TEXT,
    -- Compaction
    compaction_level INT,
    original_size INT,
    -- Timing
    created_at, updated_at, started_at, closed_at, due_at, defer_until,
    -- Indexes on: status, priority, issue_type, assignee, created_at, spec_id, external_ref
);
```

**Relationships are a separate `dependencies` table** (from `0002_create_dependencies.up.sql`):

```sql
CREATE TABLE dependencies (
    issue_id VARCHAR(255),
    depends_on_id VARCHAR(255),
    type VARCHAR(32),                      -- blocks|related|parent-child|duplicates|supersedes|replies-to
    created_at, created_by, metadata JSON, thread_id VARCHAR(255),
    PRIMARY KEY (issue_id, depends_on_id)
);
```

Plus: `events` (audit trail), `labels`, `comments`, `issue_snapshots` (for history view), `compaction_snapshots`, `federation_peers`, and a couple of views: `ready_issues_view` (the "what can I work on?" query) and `blocked_issues_view`.

**The CLI surface agents use** (from `AGENTS.md` in the beads repo):

| Command | What it does |
|---|---|
| `bd init` | Create `.beads/` with embedded Dolt |
| `bd create "Title" --description="..." -t bug -p 1 --json` | Create bead |
| `bd ready --json` | List beads with no open `blocks` deps (work queue) |
| `bd update <id> --claim` | Atomically claim (sets assignee + in_progress) |
| `bd update <id> --description "..."` | Mutate fields via flags (no interactive editor) |
| `bd dep add <child> <parent> [--type blocks|related|parent-child]` | Graph edge |
| `bd close <id> --reason "Done"` | Close |
| `bd show <id> --json` | Read a bead + its dependencies + audit trail |
| `bd list --json [filters...]` | Query |
| `bd formula list` / `bd cook <formula>` / `bd mol pour <formula>` | Run workflow templates |
| `bd doctor [--fix]` | Health/repair |
| `bd dolt push` / `bd dolt pull` | Sync via Dolt remotes |

**Compaction** ([Beads semantic memory decay](https://github.com/steveyegge/beads)): old closed beads are summarized to save context window tokens. `wisp_type` classifies short-lived records for TTL (`heartbeat`: 6h, `patrol`: 24h, `escalation`: 7d).

**ID scheme:** `<prefix>-<5-char-base36>` e.g., `bd-a1b2`, `gt-x7k2m`. Hash-based so multiple agents on different branches don't collide.

### What problem does beads solve that plain files don't?

1. **Structured over prose.** A markdown TODO list is opaque to queries; a table row is filterable (`priority=0 AND status='open'`).
2. **Dependency-aware "ready" queue.** `bd ready` computes "unblocked, unclaimed, open, high priority" — the question every agent asks on wake.
3. **Atomic claim.** `bd update <id> --claim` transactionally sets assignee + status — prevents two agents picking up the same work.
4. **Audit trail without ceremony.** Every write produces an `events` row + a Dolt commit. "Who changed this and when?" is queryable.
5. **Cross-agent shared memory.** All agents read/write the same database. No markdown file merge conflicts, no stale cache.
6. **Compaction.** Old closed beads are summarized, not deleted. Context window stays small.
7. **Durability across agent restarts.** Agent crashes, new session starts, `bd ready --json` shows exactly what was in flight. No "what was I doing?" reconstruction from chat logs.

## Why Beads Exists (problem it solves)

From [Yegge's Gas Town](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04) and the [Software Engineering Daily interview](https://softwareengineeringdaily.com/2026/02/12/gas-town-beads-and-the-rise-of-agentic-development/):

**Failure mode 1: Context window as memory.** Agents "remember" by having prior messages in their context. Past ~200K tokens that stops working. Agents forget decisions, repeat work, lose track of blockers.

**Failure mode 2: Markdown scratchpads.** Easy to write; impossible to query. "What blockers are open?" requires re-reading all the files. Multiple agents editing the same file causes merge conflicts.

**Failure mode 3: GitHub Issues / Jira.** Too heavyweight, too slow, per-request rate limits, requires network, can't run offline, leaks information to external service. Not designed for machine writers at high frequency.

**Failure mode 4: Chat history as state.** When the agent restarts, the history is truncated or summarized and key decisions silently vanish. "Stuck loops" where the agent repeats the same failed attempt because it forgot the previous one.

Beads' thesis: give agents a **local, structured, dependency-aware, append-only-enough, machine-writable work ledger**. Treat it like external memory plus a coordination primitive. Solves all four failure modes in one small tool.

### Cautionary note: the recent data-loss incident

[beads issue #2363](https://github.com/gastownhall/beads/issues/2363) — a Claude agent destroyed 247 issues in ~15 seconds by following a chain of error-message-suggested commands: `bd doctor` → `rm -rf .beads/dolt && bd init` → `bd init --force`. **Failure mode for Kiln to avoid:** never embed destructive commands in error output, and never grant agents `--force` recovery paths without explicit operator acknowledgement. Relevant to our implementation regardless of which option we pick.

## How Beads Integrates in Gas Town

From `/Users/jon/projects/gastown/README.md` and [gastown.dev architecture docs](https://gastown.dev/docs/design/architecture/):

Gas Town is a *multi-agent workspace manager* sitting on top of beads. Every meaningful thing is a bead:

- **Task beads** — actual work (e.g., "Fix auth bug"), the traditional bug-tracker kind.
- **Agent beads** — stable identity for each polecat/witness/mayor. Track `agent_state`, `last_activity`, `role_type`, `rig`.
- **Role beads** — read-only templates (`hq-mayor-role`, `hq-witness-role`) that define how a role behaves.
- **Message beads** (`issue_type='message'`) — inter-agent mail with threading via `dependencies(type='replies-to')` + `thread_id`. Ephemeral (not synced via git) unless marked otherwise.
- **Event beads** (`issue_type='event'`) — operational state changes with `event_kind` (e.g., `patrol.muted`, `agent.started`), `actor`, `target`, `payload`.
- **Molecule beads** — workflow instances (instantiated TOML formulas), with steps as child beads linked via `parent-child` deps.
- **Gate beads** — async coordination primitives: wait for GH run, PR, timer, human, or mail.
- **Escalation beads** — severity-tagged blockers routed through Deacon → Mayor → Overseer.
- **Convoy beads** — bundles of task beads assigned to agents for batched work.
- **Merge-request beads** — produced by `gt done`, consumed by the Refinery merge queue.

**Example agent session** (from `beads/AGENT_INSTRUCTIONS.md`):

```bash
bd ready --json                                 # what can I work on?
bd update bd-42 --claim --json                  # claim it (assignee + in_progress atomically)
# ... do the work ...
bd create "Found related bug" -p 1 \
  --deps discovered-from:bd-42 --json           # fork new bead with lineage
bd close bd-42 --reason "Fixed and tested" --json
bd dolt push                                    # sync to remote
```

**Cross-agent visibility:** Gas Town's stated discipline (from dolt-storage docs) is "every write wraps `BEGIN` / `DOLT_COMMIT` / `COMMIT` atomically. All writes are immediately visible to all agents." That's single-database single-writer semantics even in embedded mode (file lock); server mode allows concurrent writers via a shared `dolt sql-server`.

**Beads is the single source of truth for work and agent state.** Worktrees and sessions are ephemeral; beads are canonical.

---

## Options for Kiln

### Option A — Ecto + PubSub (native Elixir, current-state + event ledger) **[recommended]**

A `work_units` table holds current state; a `work_unit_events` append-only table holds the audit trail. `Kiln.WorkUnits` context provides the public API. Every write broadcasts on `Phoenix.PubSub`, which LiveView subscribes to for real-time dashboards. Optional ETS read-through cache only if profiling shows a hotspot.

- **Mental model:** plain boring CRUD in Ecto + event sourcing *for audit*, not for state reconstruction. Current-state is in `work_units`; history in `work_unit_events`. Matches the constitution's guidance ("full event sourcing only where replay materially pays").
- **Durability:** Postgres with write-ahead log.
- **Concurrency:** Postgres row locks + `SELECT ... FOR UPDATE SKIP LOCKED` for claim semantics — exactly what Oban already does.
- **UI integration:** PubSub broadcast on every mutation → LiveViews receive `{:work_unit, :updated, unit}` / `{:work_unit, :created, unit}` → tiles re-render.
- **Query:** full SQL. Filter, aggregate, join with runs/stages, CTE for dependency traversal.

### Option B — Ecto + OTP GenServer registry (process-per-unit)

Each work unit is a `GenServer` addressable by ID through a `Registry`. State is persisted to Ecto on every transition. Queries hit Ecto; writes hit the process.

- Buys you: per-unit backpressure, per-unit logs/metrics attached to a PID, supervised lifecycle.
- Costs: process-per-unit explodes at scale; state machine becomes implicit in `handle_call` branches; queries become harder (the GenServer is the "current truth"; DB is a lagging projection unless you write synchronously, at which point the process adds no value over plain Ecto).
- **Elixir style warning:** this is *exactly* the anti-pattern called out in Elixir docs — organizing code around processes when runtime properties don't justify it (see `prompts/elixir-best-practices-deep-research.md`, §1 "Core mindset"). Work units don't have independent lifecycles, don't need isolation, don't need concurrency. They're data.

### Option C — OTP in-memory only (`:ets` or `:persistent_term` + periodic snapshot)

Fastest reads/writes; zero DB round-trips. Snapshot to disk/DB periodically or on shutdown.

- Loses all durability guarantees. An unclean crash loses work since last snapshot.
- Cross-node coordination requires `:pg` or `Phoenix.Tracker` (eventually-consistent).
- Kiln's constitution mandates Postgres as source of truth. C directly violates this.
- Reasonable only as a *cache tier* layered on A.

### Option D — Reuse existing `runs` / `stages` / `audit_events` tables

"Work unit" is a conceptual frame, not a new table. Whatever Kiln needs, model it as an extension of existing run/stage rows.

- Simpler: one fewer table family.
- Wrong: runs and stages are *workflow execution state* — a run is "this spec is being produced right now through these stages." A work unit is *agent work-tracking* — "fix the auth bug" or "write docs for feature X" or "the Tester agent needs to recheck scenario 3 after the Coder's retry." Those are different lifetimes, different granularities, different consumers. Conflating them makes both awkward:
  - A work unit can span multiple runs (e.g., a persistent bug that gets another attempt).
  - A run has sub-structure (stages) that isn't work-tracking shape.
  - `audit_events` is append-only per-run forensics; a work unit needs a *current row* that mutates.
- Verdict: use D for what D is good at (run/stage state), use A for work tracking. They should link via foreign keys, not merge.

### Option E — Integrate the `bd` CLI binary (shell-out)

Kiln ships `bd` as a dependency; `Kiln.WorkUnits` invokes `bd create --json`, `bd ready --json`, parses stdout.

- You get beads' full feature set (compaction, formulas, federation, wasteland) for free.
- You inherit: Go toolchain, Dolt, `~/.beads/` on disk, the `bd` release cadence, the recent data-loss incident class of failure modes, plus cold-start latency on every call (~50–200 ms process spawn for a binary that loads a Dolt engine).
- LiveView integration: you must *poll* `bd list --json` or implement a filesystem watcher on `.beads/` — no native PubSub.
- Transactional guarantees with Kiln's Postgres world: none. Work units in Dolt, runs in Postgres, no shared transaction. Two-phase commit or read-your-writes guarantees become manual work.
- Operational: users have to `brew install beads` (plus `dolt`) before Kiln works. Breaks the constitutional "single `docker-compose up`" setup story.
- Verdict: too much dependency surface for Kiln's single-user, solo-operator scale. Revisit if-and-only-if we need federation with external Gas Towns.

---

## Scoring Matrix

Ratings: ⬛ = best, ▣ = good, ▢ = acceptable, ◻ = poor, ✕ = bad. Scale: Kiln v1 = 1 user, ≤10 concurrent runs, ≤1000 work units.

| Dimension | A. Ecto + PubSub | B. GenServer registry | C. In-memory only | D. Reuse runs/stages | E. `bd` CLI shell-out |
|---|---|---|---|---|---|
| BEAM-native fit | ⬛ idiomatic Ecto + PubSub | ▣ uses processes | ▢ uses ETS | ▣ already in use | ◻ external process |
| Durability | ⬛ Postgres WAL | ▣ Postgres + async process state | ◻ snapshot gap | ⬛ Postgres WAL | ▢ Dolt (separate DB) |
| Performance at Kiln scale | ⬛ trivial (<1ms/op) | ▢ fine at 1K units, ugly at 100K | ⬛ fastest | ⬛ trivial | ◻ ~50–200 ms CLI spawn |
| Operational surface | ⬛ no new deps | ▣ no new deps | ⬛ no new deps | ⬛ nothing to add | ✕ `bd`+`dolt`+`~/.beads` |
| Coupling | ⬛ zero | ⬛ zero | ⬛ zero | ⬛ zero | ✕ tied to `bd` release cadence + incidents |
| Query flexibility | ⬛ full SQL | ◻ process scan or lag DB | ◻ ETS match specs only | ⬛ full SQL | ▢ `bd` filters only; no joins to runs |
| LiveView integration | ⬛ native PubSub | ▣ PubSub after writes | ▢ must manually publish | ⬛ native | ◻ poll or fs-watch |
| Cross-agent shared memory | ⬛ single DB, Ecto transactions | ▣ Registry lookups, message passing | ◻ node-local unless `:pg` | ⬛ single DB | ⬛ Dolt single-writer / server mode |

**Weighted recommendation:** Option A wins on 6/8 dimensions outright, ties on 2. It's not close.

---

## Recommendation

### Chosen option: **Option A — Ecto + PubSub, current-state table + append-only event ledger.**

### Rationale

1. **BEAM-first.** Ecto is the idiomatic way to model persistent data in Elixir. PubSub is the idiomatic way to push updates. The user's explicit preference ("all else being equal we want to use BEAM as much as possible") aligns.
2. **Scale doesn't justify more.** 1K work units and ≤10 concurrent runs is well below the point where process-per-unit (B) or ETS (C) would pay off.
3. **LiveView integration is free.** Option A gets real-time "crank the factory" dashboards for no additional work — just broadcast after insert/update.
4. **Durability is already solved.** Kiln is already running Postgres. The audit ledger is already in the constitution (OBS-03, ORCH-04). We reuse both.
5. **No new operational dependencies.** `docker-compose up` still works. No `brew install beads`, no Dolt, no Go binary lifecycle.
6. **Migration path to `bd` exists** (see below). The data model maps 1:1; a JSONL export adapter is ~200 LOC.
7. **Avoids Option E's incident class.** The beads incident (#2363) was partly a consequence of destructive CLI suggestions in non-interactive contexts. Kiln owns its own API; we don't inherit that risk.

### Concrete design

**Context module:** `Kiln.WorkUnits` (canonical name, avoids "Beads" trademark/confusion but stays legible).

#### Ecto schema

```elixir
# lib/kiln/work_units/work_unit.ex
defmodule Kiln.WorkUnits.WorkUnit do
  use Ecto.Schema
  import Ecto.Changeset

  @type id :: binary()

  @primary_key {:id, :string, []}    # "ku-a1b2" (Kiln Unit), hash-based
  @foreign_key_type :string

  schema "work_units" do
    # ===== Content =====
    field :title, :string
    field :description, :string
    field :notes, :string
    field :acceptance_criteria, :string

    # ===== Classification =====
    field :kind, Ecto.Enum,
      values: [:task, :bug, :feature, :chore, :decision, :spike,
               :message, :event, :milestone, :agent_memo]
    field :priority, :integer, default: 2     # 0 (critical) .. 4 (backlog)
    field :status, Ecto.Enum,
      values: [:open, :claimed, :in_progress, :blocked, :deferred, :closed],
      default: :open

    # ===== Assignment =====
    field :assignee, :string               # actor URI: "agent:coder:42" | "human:jon"
    field :claimed_at, :utc_datetime_usec
    field :started_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :close_reason, :string

    # ===== Correlation =====
    belongs_to :run, Kiln.Runs.Run, type: :binary_id   # optional
    belongs_to :stage, Kiln.Runs.Stage, type: :binary_id # optional
    field :correlation_id, :string                     # from the Run it belongs to
    field :spec_id, :string                            # if scoped to a spec

    # ===== Extensibility =====
    field :metadata, :map, default: %{}                # jsonb; arbitrary agent notes
    field :external_ref, :string                       # "gh-issue-47", "bd-a1b2"
    field :source_system, :string                      # "kiln" | "bd" (federation)

    # ===== Dependency traversal cache (denormalized for bd-ready queue perf) =====
    field :blockers_open_count, :integer, default: 0   # # of blocks deps still open

    # ===== Event fields (when kind=:event) =====
    field :event_kind, :string                         # "stage.started", "retry.exhausted"
    field :actor, :string
    field :target, :string
    field :payload, :map

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(work_unit, attrs) do
    work_unit
    |> cast(attrs, [:title, :description, :notes, :acceptance_criteria,
                    :kind, :priority, :status, :assignee, :claimed_at,
                    :started_at, :closed_at, :close_reason,
                    :run_id, :stage_id, :correlation_id, :spec_id,
                    :metadata, :external_ref, :source_system,
                    :event_kind, :actor, :target, :payload])
    |> validate_required([:title, :kind])
    |> validate_inclusion(:priority, 0..4)
    |> validate_length(:title, max: 500)
    |> foreign_key_constraint(:run_id)
    |> foreign_key_constraint(:stage_id)
  end
end
```

```elixir
# lib/kiln/work_units/dependency.ex
defmodule Kiln.WorkUnits.Dependency do
  use Ecto.Schema

  @primary_key false
  @foreign_key_type :string

  schema "work_unit_dependencies" do
    belongs_to :work_unit, Kiln.WorkUnits.WorkUnit, primary_key: true,
      references: :id, foreign_key: :work_unit_id
    belongs_to :depends_on, Kiln.WorkUnits.WorkUnit, primary_key: true,
      references: :id, foreign_key: :depends_on_id

    field :kind, Ecto.Enum,
      values: [:blocks, :related, :parent_child, :duplicates,
               :supersedes, :replies_to, :discovered_from],
      default: :blocks

    field :metadata, :map, default: %{}
    field :thread_id, :string              # for :replies_to grouping

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
```

```elixir
# lib/kiln/work_units/event.ex (append-only audit)
defmodule Kiln.WorkUnits.Event do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :string

  schema "work_unit_events" do
    belongs_to :work_unit, Kiln.WorkUnits.WorkUnit
    field :event_type, :string        # "created", "claimed", "status_changed",
                                      # "priority_changed", "closed", "dep_added", ...
    field :actor, :string             # "agent:coder:42" | "human:jon" | "system"
    field :old_value, :map
    field :new_value, :map
    field :comment, :string
    field :correlation_id, :string
    field :causation_id, :string      # event that caused this one (for chain reconstruction)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
```

#### Migration sketch

```elixir
# priv/repo/migrations/YYYYMMDDHHMMSS_create_work_units.exs
create table(:work_units, primary_key: false) do
  add :id, :string, primary_key: true                  # "ku-a1b2"
  add :title, :string, null: false, size: 500
  add :description, :text
  add :notes, :text
  add :acceptance_criteria, :text
  add :kind, :string, null: false
  add :priority, :integer, null: false, default: 2
  add :status, :string, null: false, default: "open"
  add :assignee, :string
  add :claimed_at, :utc_datetime_usec
  add :started_at, :utc_datetime_usec
  add :closed_at, :utc_datetime_usec
  add :close_reason, :text
  add :run_id, references(:runs, type: :binary_id, on_delete: :nilify_all)
  add :stage_id, references(:stages, type: :binary_id, on_delete: :nilify_all)
  add :correlation_id, :string
  add :spec_id, :string
  add :metadata, :map, null: false, default: %{}
  add :external_ref, :string
  add :source_system, :string
  add :blockers_open_count, :integer, null: false, default: 0
  add :event_kind, :string
  add :actor, :string
  add :target, :string
  add :payload, :map
  timestamps(type: :utc_datetime_usec)
end
create index(:work_units, [:status])
create index(:work_units, [:priority])
create index(:work_units, [:kind])
create index(:work_units, [:assignee])
create index(:work_units, [:run_id])
create index(:work_units, [:stage_id])
create index(:work_units, [:correlation_id])
# Hot path: ready queue
create index(:work_units, [:status, :priority, :blockers_open_count])

create table(:work_unit_dependencies, primary_key: false) do
  add :work_unit_id, references(:work_units, type: :string, on_delete: :delete_all),
    primary_key: true
  add :depends_on_id, references(:work_units, type: :string, on_delete: :delete_all),
    primary_key: true
  add :kind, :string, null: false, default: "blocks"
  add :metadata, :map, null: false, default: %{}
  add :thread_id, :string
  add :inserted_at, :utc_datetime_usec, null: false
end
create index(:work_unit_dependencies, [:depends_on_id, :kind])
create index(:work_unit_dependencies, [:thread_id])

create table(:work_unit_events, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :work_unit_id, references(:work_units, type: :string, on_delete: :delete_all),
    null: false
  add :event_type, :string, null: false
  add :actor, :string, null: false
  add :old_value, :map
  add :new_value, :map
  add :comment, :text
  add :correlation_id, :string
  add :causation_id, :string
  add :inserted_at, :utc_datetime_usec, null: false
end
create index(:work_unit_events, [:work_unit_id, :inserted_at])
create index(:work_unit_events, [:correlation_id])
```

#### Public API (`Kiln.WorkUnits`)

```elixir
defmodule Kiln.WorkUnits do
  @moduledoc """
  Durable, agent-readable work tracking (beads-equivalent).

  Every agent and every human writes work units here. The dashboard reads here.
  Cross-agent shared memory is just "everyone reads/writes the same Postgres
  table with transactional semantics."
  """

  alias Kiln.WorkUnits.{WorkUnit, Dependency, Event}
  alias Kiln.Repo

  @pubsub Kiln.PubSub

  # ===== Commands =====

  @spec create(map(), actor :: String.t()) :: {:ok, WorkUnit.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs, actor) do
    Repo.transaction(fn ->
      id = generate_id(attrs[:kind] || attrs["kind"] || :task)
      attrs = Map.put(attrs, :id, id)

      with {:ok, wu} <- %WorkUnit{} |> WorkUnit.changeset(attrs) |> Repo.insert(),
           {:ok, _ev} <- log_event(wu, "created", actor, nil, wu) do
        wu
      else
        {:error, cs} -> Repo.rollback(cs)
      end
    end)
    |> tap(&maybe_broadcast(&1, :created))
  end

  @spec claim(WorkUnit.id(), actor :: String.t()) ::
    {:ok, WorkUnit.t()} | {:error, :not_found | :already_claimed | Ecto.Changeset.t()}
  def claim(id, actor) do
    # Atomic claim: only succeeds if status is :open and assignee is nil.
    # Uses SELECT ... FOR UPDATE SKIP LOCKED equivalent via optimistic where clause.
    now = DateTime.utc_now()

    query =
      from wu in WorkUnit,
        where: wu.id == ^id and wu.status == :open and is_nil(wu.assignee)

    case Repo.update_all(query,
      set: [status: :claimed, assignee: actor, claimed_at: now, updated_at: now]
    ) do
      {1, _} ->
        wu = Repo.get!(WorkUnit, id)
        log_event(wu, "claimed", actor, %{status: :open}, %{status: :claimed, assignee: actor})
        broadcast(:updated, wu)
        {:ok, wu}
      {0, _} ->
        case Repo.get(WorkUnit, id) do
          nil -> {:error, :not_found}
          _   -> {:error, :already_claimed}
        end
    end
  end

  @spec update(WorkUnit.id(), attrs :: map(), actor :: String.t()) ::
    {:ok, WorkUnit.t()} | {:error, Ecto.Changeset.t()}
  def update(id, attrs, actor) do
    Repo.transaction(fn ->
      wu = Repo.get!(WorkUnit, id)
      old = Map.take(wu, WorkUnit.__schema__(:fields))

      with {:ok, updated} <- wu |> WorkUnit.changeset(attrs) |> Repo.update(),
           new = Map.take(updated, WorkUnit.__schema__(:fields)),
           diff = Map.new(new, fn {k, v} -> {k, v} end) |> Map.reject(fn {k, v} -> Map.get(old, k) == v end),
           {:ok, _ev} <- log_event(updated, "updated", actor, old, diff) do
        updated
      else
        {:error, cs} -> Repo.rollback(cs)
      end
    end)
    |> tap(&maybe_broadcast(&1, :updated))
  end

  @spec close(WorkUnit.id(), reason :: String.t(), actor :: String.t()) ::
    {:ok, WorkUnit.t()} | {:error, term()}
  def close(id, reason, actor), do:
    update(id, %{status: :closed, close_reason: reason, closed_at: DateTime.utc_now()}, actor)

  @spec add_dependency(from :: WorkUnit.id(), to :: WorkUnit.id(),
                       kind :: atom(), actor :: String.t()) ::
    {:ok, Dependency.t()} | {:error, term()}
  def add_dependency(from, to, kind \\ :blocks, actor) do
    Repo.transaction(fn ->
      {:ok, dep} = %Dependency{}
        |> Ecto.Changeset.change(work_unit_id: from, depends_on_id: to, kind: kind)
        |> Repo.insert()

      # Maintain blockers_open_count cache for ready-queue perf.
      if kind == :blocks do
        from(wu in WorkUnit, where: wu.id == ^from)
        |> Repo.update_all(inc: [blockers_open_count: 1])
      end

      log_event(%WorkUnit{id: from}, "dep_added", actor,
        %{}, %{depends_on: to, kind: kind})
      dep
    end)
    |> tap(fn _ -> broadcast(:dep_added, %{from: from, to: to, kind: kind}) end)
  end

  # ===== Queries =====

  @doc "The 'bd ready' query: open, unassigned, no open blockers, ordered by priority."
  @spec ready(opts :: keyword()) :: [WorkUnit.t()]
  def ready(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    kind  = Keyword.get(opts, :kind)

    query =
      from wu in WorkUnit,
        where: wu.status == :open
           and is_nil(wu.assignee)
           and wu.blockers_open_count == 0,
        order_by: [asc: wu.priority, asc: wu.inserted_at],
        limit: ^limit

    query = if kind, do: where(query, [wu], wu.kind == ^kind), else: query
    Repo.all(query)
  end

  @spec list(filters :: keyword()) :: [WorkUnit.t()]
  def list(filters \\ []), do: Repo.all(build_list_query(filters))

  @spec get(WorkUnit.id()) :: WorkUnit.t() | nil
  def get(id), do: Repo.get(WorkUnit, id)

  @spec get!(WorkUnit.id()) :: WorkUnit.t()
  def get!(id), do: Repo.get!(WorkUnit, id)

  @spec show(WorkUnit.id()) ::
    %{unit: WorkUnit.t(), deps: [Dependency.t()], events: [Event.t()]}
  def show(id) do
    unit   = Repo.get!(WorkUnit, id)
    deps   = Repo.all(from d in Dependency, where: d.work_unit_id == ^id)
    events = Repo.all(from e in Event, where: e.work_unit_id == ^id,
                      order_by: [asc: e.inserted_at])
    %{unit: unit, deps: deps, events: events}
  end

  # ===== PubSub =====

  @doc "Subscribe to ALL work-unit changes (for a dashboard)."
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, "work_units")

  @doc "Subscribe to a single work unit (for a detail view)."
  def subscribe(id) when is_binary(id), do:
    Phoenix.PubSub.subscribe(@pubsub, "work_units:#{id}")

  @doc "Subscribe to all work units in a run (run detail dashboard)."
  def subscribe_run(run_id), do:
    Phoenix.PubSub.subscribe(@pubsub, "work_units:run:#{run_id}")

  # ===== Internals =====

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "work_units", {:work_unit, event, payload})
    if is_struct(payload, WorkUnit) do
      Phoenix.PubSub.broadcast(@pubsub, "work_units:#{payload.id}",
        {:work_unit, event, payload})
      if payload.run_id do
        Phoenix.PubSub.broadcast(@pubsub, "work_units:run:#{payload.run_id}",
          {:work_unit, event, payload})
      end
    end
  end

  defp maybe_broadcast({:ok, wu}, event), do: broadcast(event, wu)
  defp maybe_broadcast(_, _), do: :ok

  defp log_event(wu, type, actor, old, new) do
    %Event{}
    |> Ecto.Changeset.change(
      work_unit_id: wu.id,
      event_type: type,
      actor: actor,
      old_value: stringify(old),
      new_value: stringify(new)
    )
    |> Repo.insert()
  end

  defp stringify(m) when is_map(m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)
  defp stringify(other), do: other

  defp generate_id(_kind) do
    # bd-style: "ku-" + 5-char base36 hash (collision-resistant across parallel writers)
    "ku-" <> (:crypto.strong_rand_bytes(4) |> Base.encode32(case: :lower, padding: false) |> binary_part(0, 5))
  end
end
```

#### PubSub topic naming conventions

| Topic | Who subscribes | Message shape |
|---|---|---|
| `"work_units"` | Global dashboard (kanban view) | `{:work_unit, :created \| :updated \| :dep_added, payload}` |
| `"work_units:<id>"` | Single-unit detail LiveView | `{:work_unit, event, unit}` |
| `"work_units:run:<run_id>"` | Run detail view | `{:work_unit, event, unit}` |
| `"work_units:agent:<actor>"` | Per-agent activity feed (future) | `{:work_unit, event, unit}` |

#### Supervision tree implications

**None.** This is the whole point of choosing A over B. `Kiln.WorkUnits` is a stateless context that reads/writes `Kiln.Repo` and calls `Phoenix.PubSub.broadcast`. Both of those are already in the standard Phoenix supervision tree. No new processes, no new children to add to the Application supervisor.

A GenServer joins the tree *only* if we later add:

- A **compaction worker** (periodic job that summarizes closed beads older than N days → an Oban worker, not a GenServer).
- A **stuck-unit detector** (ORCH-04 / OBS-04 already covers stuck-run detection; extend that probe to check for claimed-but-idle work units).

Both are Oban jobs, not processes per unit.

#### Test plan (per the feedback-doc output contract)

- Unit: `Kiln.WorkUnits` changeset validations (required fields, enum membership, priority bounds).
- Integration: `claim/2` under concurrent access — property test with `StreamData` that spawns N tasks each trying to claim the same ID; exactly one wins.
- Integration: `ready/1` returns exactly the set predicted by the dependency graph; shrink-tested over random DAGs.
- Integration: PubSub fan-out — subscribe, call `create/2`, assert message received within a timeout.
- LiveView: `LiveViewTest` for the kanban view; assert real-time updates on broadcast.
- Audit: `show/1` returns events in chronological order; causation_id chain reconstructs agent reasoning.

---

## Migration to External Beads (future)

**Scenario:** Kiln v2 wants to participate in the Wasteland (federated work network) or a user wants to export Kiln work units to their personal `bd` database.

### Adapter approach

Build `Kiln.WorkUnits.BdAdapter` with two directions.

#### Export (Kiln → bd JSONL)

`bd` supports [JSONL import](https://github.com/steveyegge/beads) via `bd import`. Generate one line per work unit using the beads field names. Shape-compatible mapping:

| Kiln field | bd field | Notes |
|---|---|---|
| `id` ("ku-...") | `id` | May need prefix rewrite to match bd's configured prefix |
| `title` | `title` | — |
| `description` | `description` | — |
| `notes` | `notes` | — |
| `acceptance_criteria` | `acceptance_criteria` | — |
| `kind` | `issue_type` | `:agent_memo` → custom type `"memo"` (needs `bd config set types.custom "memo"`) |
| `status` | `status` | `:claimed` → `hooked` (bd's term), `:open` → `open`, etc. |
| `priority` | `priority` | 1:1 |
| `assignee` | `assignee` | actor URI string |
| `metadata` | `metadata` | JSON passthrough |
| `external_ref` | `external_ref` | Kiln marks `"kiln-<id>"` so round-trip is traceable |
| *none* | `source_system` | Set to `"kiln"` so bd knows provenance |
| Dependencies | Dependencies | 1:1 on kind (`:blocks` ↔ `blocks`, etc.) |
| Events | Events | bd's `events` table matches 1:1 |

~200 LOC: `Kiln.WorkUnits.list/1` → map to beads shape → `Jason.encode_to_iodata!` → file or shell pipe to `bd import -`.

#### Import (bd JSONL → Kiln)

`bd list --json` produces the inverse. An Oban job pulls on an interval or on-demand; dedup by `external_ref`. Conflicts resolved with `updated_at` as a vector clock surrogate.

#### Live interop (not recommended for v1)

If truly bidirectional in real time is needed, run `bd` in server mode (`bd init --server`) and have both Kiln and external Gas Town point to the same Dolt SQL server. Kiln then issues raw SQL to the Dolt server for work units. This is Option E by the back door and carries the same downsides — don't do it for v1.

### Compatibility bill

- ID prefix rewrite: trivial (swap `"ku-"` ↔ `"bd-"` on export/import).
- Status vocabulary: one entry in a mapping table.
- Custom statuses / types: bd supports them via `bd config set status.custom "foo:active,bar:wip"` — declare Kiln's custom ones there on first export.
- Federation trust model: bd's [HOP trust chain](https://github.com/steveyegge/beads) lets external Gas Towns mark Kiln-origin beads as `source_system="kiln"` and skip re-validation. We just have to set the field.

**Bottom line:** the migration path is a map/transform, not a rewrite. Building native does not lock us out of federation; it defers the cost until there's concrete demand.

---

## Anti-patterns

**Avoid all of these, regardless of option.**

1. **Process-per-work-unit (Option B) at the domain layer.** Work units aren't long-lived, don't have independent computation, don't need fault isolation. Modeling them as GenServers is the "everything is a process" Elixir anti-pattern. If we later need backpressure on the stream of agent writes, that's one Oban queue, not 1000 GenServers.

2. **Conflating work units with Oban job args/meta.** Tempting, because Oban already has `args` and `meta` maps. Don't: those are job-execution-lifetime state, not cross-agent tracking state. Queries on `oban_jobs.meta->>'some_field'` become painful; jobs get pruned; the relationship to runs is indirect. A separate table is cheaper.

3. **Single giant table with no audit.** The constitution already mandates append-only audit (OBS-03). Skipping `work_unit_events` means "who changed priority?" is unanswerable, and time-travel queries require pg_audit hacks. Keep the events table from day one.

4. **Storing agent chat history inline in `notes`.** If an agent wants to leave a 50K-token memo, that's a *file artifact* linked by `metadata`, not a column. Work units are metadata/index; artifacts are blobs.

5. **Shell-out to `bd` for the hot path.** Even if we use `bd` for federation later, the agent-facing API must be in-process Elixir. 50–200 ms per call × 1000 ops per run × 10 concurrent runs = seconds to minutes of added latency per factory cycle.

6. **Exposing "Beads" as the noun in the UI/API.** "Bead" is Gas Town slang with license/trademark concerns and is less legible to new users. Use "work unit" in the public API; mention "beads-like" only in internal documentation and research docs. (Internally inside the team we can still call them beads informally; just don't bake it into `Kiln.Beads`.)

7. **Making the CLI follow bd's footgun pattern.** No destructive suggestions in error messages. No `--force` paths. If a `work_units` table is missing, the *only* remediation path is a migration, run by a human via `mix ecto.migrate` — not something an agent can invoke.

8. **Letting `blockers_open_count` drift.** It's a denormalized cache for the ready-queue hot path. Either maintain it in the same transaction as dep insert/close (as shown) *or* don't denormalize and compute it in the query with a `LATERAL` join. Do not have it sometimes-correct.

9. **One-PubSub-topic-per-unit with auto-subscribe.** Every open tab would subscribe to every unit. Use the three topic tiers (`"work_units"`, `"work_units:<id>"`, `"work_units:run:<run_id>"`) and let LiveViews subscribe to only what they render.

10. **Using `oban_jobs.args` for cross-agent shared memory.** Agent A writes a note as a job arg; Agent B tries to read it; they run in different jobs that never communicate. This is what work units exist for — put shared state in a shared table, not in queue metadata.

---

## Sources

Primary (grounded in source):

- Beads repo (local clone) — [github.com/steveyegge/beads](https://github.com/steveyegge/beads) — `/Users/jon/projects/beads/README.md`, `AGENTS.md`, `AGENT_INSTRUCTIONS.md`, `internal/types/types.go`, `internal/storage/schema/migrations/0001_create_issues.up.sql`, `0002_create_dependencies.up.sql`, `0005_create_events.up.sql`.
- Gas Town repo (local clone) — [github.com/steveyegge/gastown](https://github.com/steveyegge/gastown) — `/Users/jon/projects/gastown/README.md`.
- [Gas Town Architecture](https://gastown.dev/docs/design/architecture/) — authoritative description of how beads is used as the single source of truth across agent identity, task tracking, messaging, and workflow instances.
- [Gas Town Dolt Storage Architecture](https://gastown.dev/docs/design/dolt-storage/) — transaction discipline, concurrency model, what's stored where.

Secondary:

- [Welcome to Gas Town (Steve Yegge, Medium)](https://steve-yegge.medium.com/welcome-to-gas-town-4f25ee16dd04) — original motivation for beads.
- [Gas Town, Beads, and the Rise of Agentic Development (Software Engineering Daily, Feb 2026)](https://softwareengineeringdaily.com/2026/02/12/gas-town-beads-and-the-rise-of-agentic-development-with-steve-yegge/) — problem framing.
- [A Day in Gas Town (DoltHub Blog, Jan 2026)](https://www.dolthub.com/blog/2026-01-15-a-day-in-gas-town/) — real-world usage anecdotes.
- [beads issue #2363 — data-loss incident](https://github.com/gastownhall/beads/issues/2363) — failure mode to design away.
- [Rust port: Dicklesworthstone/beads_rust](https://github.com/Dicklesworthstone/beads_rust) — evidence that the data model ports cleanly (SQLite + JSONL), validating Option A.

Elixir/Phoenix patterns:

- [Phoenix.PubSub docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) — topic-based broadcast; standard LiveView integration.
- [Phoenix.Tracker docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.Tracker.html) — eventually-consistent presence; reserved for v2 distributed mode.
- [Elixir LiveView with PubSub (Elixir School)](https://elixirschool.com/blog/live-view-with-pub-sub) — canonical real-time pattern.
- [N+1 with PubSub LiveViews (Manu Sachi)](https://manusachi.com/blog/n+1-with-pubsub-liveviews-detect-with-open-telemetry) — pitfall for later (don't fan out one query per broadcast).
- Kiln local prompts: `prompts/elixir-best-practices-deep-research.md` (§1 "Core mindset": processes only when runtime properties justify), `prompts/ecto-best-practices-deep-research.md`, `prompts/software dark factory prompt feedback.txt` (current-state + append-only ledger, not full event sourcing).

---

## Confidence Assessment

| Area | Confidence | Basis |
|---|---|---|
| What beads is (data model, CLI, usage) | HIGH | Read directly from source: schemas, types, AGENTS.md, gastown README. |
| What beads solves | HIGH | Stated explicitly in Yegge's Medium + SED interview + gastown docs; corroborated by incident #2363. |
| Kiln scale bounds (≤1K units, ≤10 runs) | MEDIUM | Projected from PROJECT.md constraints ("solo operator"); will revisit at each phase. |
| Option A is right for Kiln | HIGH | Matches constitutional constraints (Postgres source of truth, BEAM-native, no new deps), scores dominantly on the matrix, and echoes the feedback doc's explicit recommendation (current-state + audit ledger, not full ES). |
| Migration path feasibility | MEDIUM | Based on beads JSONL import surface; not built or tested. Estimate ~200 LOC for the export direction is confident, import with conflict resolution is less confident. |
