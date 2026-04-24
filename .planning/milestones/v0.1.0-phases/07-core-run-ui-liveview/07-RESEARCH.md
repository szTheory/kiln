# Phase 7 — Technical Research

**Question:** What do we need to know to plan Core Run UI (LiveView) well?

**Status:** RESEARCH COMPLETE

---

## 1. PubSub and board cardinality

`Kiln.Runs.Transitions` already broadcasts after successful commits:

- Topic `runs:board` with `{:run_state, %Run{}}` — ideal single subscription for `RunBoardLive` (P16: bounded topics).
- Topic `run:#{run.id}` — reserved for run-scoped detail streams (logs, stage updates) without flooding the board process (D-728).

**Implication:** Board subscribes only to `runs:board`; debounce card chrome updates on burst (D-728). Detail LiveView subscribes to `run:<id>` plus optional stage-scoped topics if introduced later.

---

## 2. Data sources by surface

| Surface | Primary SSOT | Notes |
|---------|--------------|-------|
| Run board | `runs` table via `Kiln.Runs.list_active/0` + full list query for terminals in kanban | Terminal columns need `from(r in Run, where: r.state in ^terminal)` — extend `Kiln.Runs` with `list_for_board/0` or two queries merged in LV |
| Run detail | `Kiln.Runs.get!/1`, `Kiln.Stages.list_for_run/1`, diff/logs from artifacts / stage completion (verify existing artifact paths in `Kiln.Artifacts`) | Stage graph topology from `CompiledGraph` keyed by run’s `workflow_id` + frozen `workflow_version` / `workflow_checksum` |
| Workflow registry | New `workflow_definition_snapshots` table (D-716) + loader hook | On successful `Workflows.Loader.load/1` (or compile path), insert snapshot row; never `mtime` |
| Cost | `stage_runs.cost_usd`, `actual_model_used`, `requested_model` joined to `runs`, `workflow_id`, `agent_role` | Reconciles with telemetry metadata documented in `Kiln.Agents.TelemetryHandler` / adapter `:stop` events |
| Audit | `Kiln.Audit.replay/1` | Today filters: `run_id`, `event_kind`, `correlation_id`. UI-05 needs `stage_id`, actor fields, time window — extend `apply_replay_filters/2` |

---

## 3. LiveView mechanics (Phoenix 1.8)

- **Streams:** Board uses `stream(:runs, ...)` with `phx-update="stream"`; per ROADMAP avoid `reset: true` on every PubSub message — use `stream_insert` / `stream_delete` / in-place updates (D-725).
- **`handle_params/3`:** Run detail URL is source of truth (D-705–D-706); validate `stage_id` belongs to run before loading pane streams.
- **`stream_async/4`:** Use for large YAML bodies in `WorkflowLive` when file exceeds threshold (UI-SPEC).
- **Auth stub:** Solo v1 — `defp allow?(_socket), do: true` at top of each new `handle_event` / sensitive `handle_params` branch (D-729, P18).

---

## 4. Router and sessions

- D-701–D-703: Domain routes in `live_session :default` with `KilnWeb.LiveScope`; `/ops/*` unchanged.
- Replace `get "/", PageController, :redirect_to_ops` with `live "/", RunBoardLive, :index` (or named action).

---

## 5. Brand and Tailwind v4

- Inter + IBM Plex Mono: ensure `@font-face` or Google fonts link in root layout; map semantic colors to Coal/Char/Iron/Bone/Ash/Ember/Clay/Smoke (see `07-UI-SPEC.md` + `prompts/kiln-brand-book.md`).
- Remove default Phoenix marketing chrome from `Layouts.app` nav over time — plan 01 scopes minimal operator nav (links to `/workflows`, `/costs`, `/audit`, `/specs/...`, `/ops/dashboard`).

---

## 6. Testing strategy

- `Phoenix.LiveViewTest` + `LazyHTML` with stable IDs from UI-SPEC (`id="run-board"`, `id="audit-filter-form"`, etc.).
- Dev-only query logging optional for N+1 guard (P14) — document; not blocking CI.

---

## 7. Pitfalls mapping (ROADMAP P13–P18)

| Pitfall | Mitigation in implementation |
|---------|-------------------------------|
| P13 heap | Streams everywhere; bounded log assign |
| P14 N+1 | Preload associations in `mount`/`handle_params`; index-backed queries |
| P16 topic explosion | Fixed topic names only |
| P17 OTel | Optional follow-up: `opentelemetry_process_propagator` in LV connect — note in plan if deferred |
| P18 auth | `allow?/1` on every `handle_event` |

---

## Validation Architecture

**Nyquist Dimension 8 — feedback loop:** Every plan’s tasks must end with automated verification (`mix test` scoped paths). LiveView tests may be slower; cap with `--max-failures=1` during iteration, full `mix test test/kiln_web/` before phase close.

**Sampling:**

- After each task: plan’s `<automated>` command.
- After each wave: `mix test test/kiln_web/ --max-failures=5`.
- Gate: `mix check` before UAT.

**Manual / load (non-blocking for plan execution):** 200ms board with 10+ runs and 1h heap test — document as follow-up scenario in VALIDATION.md manual table; local `mix test` cannot simulate full load.

---

## RESEARCH COMPLETE

Proceed to `07-VALIDATION.md` + `07-PATTERNS.md` + executable `07-*-PLAN.md` files.
