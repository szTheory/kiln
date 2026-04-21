# Phase 7: Core Run UI (LiveView) - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

An operator can **watch runs**, **open run detail** (stage graph, diff, logs, events, agent chatter), **inspect workflow definitions** (read-only YAML + honest history), **see spend** reconciled to telemetry, and **browse the audit ledger** — all LiveView, streams-first, brand-aligned (UI-01..UI-06). Phase 7 does **not** ship intake, global factory header, unblock panel, or onboarding (Phase 8).

</domain>

<decisions>
## Implementation Decisions

### Routes & information architecture (D-701..D-704)

- **D-701 — Product vs ops split:** All five Phase 7 LiveViews live under **first-class domain paths** at the app root. **`/ops/*` stays BEAM/queue introspection only** (LiveDashboard, Oban Web). Rationale: Postgres-backed runs/workflows/audit/cost are **domain resources**, not VM telemetry; matches Argo CD / GitHub Actions mental models and Kiln’s “factory floor is the product” narrative.
- **D-702 — Canonical paths:**

| LiveView | Path |
|----------|------|
| `RunBoardLive` | `GET /` (home **is** the board — no extra hop) |
| `RunDetailLive` | `/runs/:run_id` |
| `WorkflowLive` | `/workflows` (index) and `/workflows/:workflow_id` (detail) |
| `CostLive` | `/costs` |
| `AuditLive` | `/audit` |

- **D-703 — `live_session`:** Add these routes to the **same** `live_session :default` as existing browser LiveViews (`KilnWeb.LiveScope`), so `push_navigate` / `push_patch` within the operator console stays client-side. Crossing into **`/ops/*` remains a separate scope** (intentional full navigation to “plumbing” tools — test `live_redirect` / `<.link navigate>` across the boundary).
- **D-704 — Spec editor:** Keep **`/specs/:id/edit`** as-is under the same session; deep links from cost/audit may use `~p"/runs/#{id}"` etc. No nesting of runs under `/specs`.

### Run detail deep linking (D-705..D-708)

- **D-705 — URL as source of truth:** Selected **stage** and **pane** are **always** reflected in the URL so refresh, reconnect, and pasted links reproduce state. Assign-only selection is **not** acceptable for v1 run inspection.
- **D-706 — Concrete shape:** `GET /runs/:run_id?stage=:stage_id&pane=diff|logs|events|chatter` (pane enum locked to these four + future optional keys documented in code). Use **`push_patch`** from stage graph clicks and pane tabs; implement **`handle_params/3`** to validate `stage_id` belongs to the run, then `stream(..., reset: true)` (or targeted updates) for stage-scoped collections.
- **D-707 — History hygiene:** Prefer **`replace: true`** only when intentionally avoiding spam (e.g. rapid pane toggles) — default **`push_patch`** for stage changes so Back traverses stages; document the choice in module moduledoc.
- **D-708 — Stale IDs:** Unknown `stage_id` → keep run shell, show **inline empty/error** per UI-SPEC tone (“Stage not found” / pick latest), never a blank LiveView.

### Diff viewer defaults (D-710..D-713)

- **D-710 — Default layout:** **Unified (inline)** diff first paint; **side-by-side** is a **first-class toggle**, not hidden — matches GitHub/GitLab laptop defaults and Kiln’s restrained density.
- **D-711 — Raw vs pretty:** **Pretty** first (syntax-aware readability); **Raw** is the **verification lens** (literal bytes/lines as stored). Orthogonal to layout: toggles compose (unified+raw, split+pretty, etc.).
- **D-712 — Width:** **Horizontal scroll, no wrap** by default for monospace bodies; optional **“Wrap long lines”** toggle (explicitly labeled display-only) for prose or narrow viewports.
- **D-713 — Persistence:** **Sticky operator defaults** via **`localStorage`** for `(layout, pretty/raw, wrap)`; optional **`push_patch`** query mirrors (`?layout=`, `?fmt=`, `?wrap=`) when shareable reproduction matters. Respect **`prefers-reduced-motion`** for any diff highlight animations. Mitigate huge lines: **truncate / cap / download** — never megabyte single-line DOM.

### Workflow registry “history” (D-715..D-719)

- **D-715 — Honest semantics:** The side list is labeled **“Snapshots”** (or **“Loaded definitions”**) — **not** unqualified “Version history” (avoids Git-semver confusion). Each row = **one immutable definition the factory accepted** at a point in time.
- **D-716 — Storage (v1):** **Postgres snapshot rows** on each **successful** workflow load/compile: at minimum `workflow_id`, `inserted_at`, YAML `version` integer (from metadata / D-55), **`compiled_checksum`** (64-char hex, same meaning as `CompiledGraph.checksum` / `runs.workflow_checksum`), and either **bounded inline YAML** or **`artifact_id`** into CAS when size demands. **Never** use filesystem `mtime` as version identity.
- **D-717 — Reconciliation:** Runs keep frozen **`workflow_version` + `workflow_checksum`** (existing D-94); registry UI must show that a run pinned to checksum **X** may differ from **“current”** snapshot when operators iterate YAML — surface that relationship explicitly in copy/tooltips, not silently.
- **D-718 — Upgrade path:** Optional later columns: `source_ref` (`:git`, `:path`, `:upload`), `git_rev`, semver from metadata — **schema-ready narrative**, not required for v1 UI read-only viewer.
- **D-719 — Anti-feature:** **No** browser editor; actions are inspect / copy checksum / (later) compare — never mutating YAML through LiveView forms.

### Cost dashboard landing & trust (D-720..D-724)

- **D-720 — First paint:** **Time-first summary strip** — **Today** and **This week (operator-local calendar)** with **actuals** only in the strip. Primary breakdown uses **dimension tabs**: **Run | Workflow | Agent role | Provider** over the **same** rollup dataset (pivot queries, not duplicate pages). **Default tab: Run** (fastest path to “which run is burning budget”); Provider remains one click away for multi-vendor views.
- **D-721 — Projection:** **Never** mix projection into the same number as actuals without a sublabel. Separate row/card: **“Week projection (estimate)”** with explicit basis microcopy (e.g. average over last **48h** or last **N** completed agent calls — **N** visible). Run-scoped projection references **bounded-autonomy cap snapshot** when present; omit cap language when absent. Below threshold **N**, show **“Not enough calls to project”** (no fake precision).
- **D-722 — Reconciliation:** Rollups **only** from the same canonical facts as `[:kiln, :agent, :call, :stop]` (and related) telemetry; **attribute USD to `actual_model_used`**. When `requested_model ≠ actual_model_used`, show **muted** requested column + **“Routed”** affordance linking to **Audit** filter preset (`model_routing_fallback` / OPS-02 story).
- **D-723 — Numbers:** Display USD to **cents** with **tabular numerals** (IBM Plex Mono per UI-SPEC); store higher precision internally; timezone = **UTC storage, local display** with explicit chip text for week boundaries.
- **D-724 — Footer trust:** **“Last updated {timestamp}”** on rollups; optional **CSV export** at the same grain as the visible table for operator audit; **“Unpriced model”** bucket when pricing tables miss a model (never silent zero).

### Real-time run board affordance (D-725..D-728)

- **D-725 — Baseline:** **Linear-quiet** default — **no toasts, no sounds, no full-board flash** for routine PubSub updates. Truth updates in place via **`stream_insert` / `stream_delete` / reorder** per run id; **never** `stream(:runs, ..., reset: true)` on every trivial field change (morph churn / heap risk vs roadmap SC1).
- **D-726 — Per-card cue:** On run-scoped change (state move, checks snapshot, `last_activity_at`), apply a **~250ms** **neutral** border/background shift (**Char / Iron / Ash** only). **Do not use Ember** for refresh feedback — Ember stays reserved per UI-SPEC (primary CTA, active run, in-progress graph node, focus ring).
- **D-727 — Motion safety:** Gate the highlight animation on **`prefers-reduced-motion: reduce`** → skip animation; rely on **updated mono timestamp** + column placement for truth.
- **D-728 — Bursts:** If PubSub floods (e.g. log-heavy ancillary events), **debounce board-level metadata** at publisher or LV boundary so card chrome does not strobe; do not subscribe the board process to high-volume topics meant for run detail.

### Cross-cutting engineering (D-729..D-731)

- **D-729 — Auth stub:** Every new `handle_event/3` (and sensitive `handle_params/3` if ever mutating) includes an **`allow?/1`-style guard** — solo v1 may delegate to `true`, but the **call site exists** for P18 compliance.
- **D-730 — Stable DOM IDs:** Per ROADMAP + UI-SPEC — `id="run-board"`, `id="audit-filter-form"`, etc., for **LazyHTML** tests.
- **D-731 — Oban / LiveDashboard:** **Do not relocate** `/ops/dashboard` or `/ops/oban`; link from run surfaces only when operator-facing copy calls for it (“View trace” / ops metaphors stay consistent with UI-SPEC).

### Claude's Discretion

- Exact **debounce ms**, **projection N** threshold, **CSV** column order.
- Whether **`/runs` alias** redirects to `/` or is omitted entirely (either is fine if bookmarks stay stable).
- Side-by-side diff implementation detail (CSS grid vs table) as long as D-710–D-712 behaviors hold.
- Snapshot retention / pruning policy once table grows (document in plan; v1 can ship with generous retention + follow-up).

### Folded Todos

- None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 7 design & requirements

- `.planning/phases/07-core-run-ui-liveview/07-UI-SPEC.md` — Approved UI contract (typography, palette, streams/async table, copy, stable IDs, accent rules).
- `prompts/kiln-brand-book.md` — Full brand contract; UI-06 checklist source.
- `.planning/ROADMAP.md` — Phase 7 goal, success criteria (200ms board, streams, PubSub, `stream_async/4`, reconciliation, P13–P18 pitfalls).
- `.planning/REQUIREMENTS.md` — UI-01 through UI-06 acceptance text.
- `CLAUDE.md` — Condensed brand + Phoenix 1.8 LiveView rules (Layouts.app, `current_scope`, `<.icon>`, streams).

### Workflow & run integrity (existing code contracts)

- `lib/kiln/workflows/compiled_graph.ex` — `version`, `checksum` (D-94), D-55 composite key semantics.
- `lib/kiln/runs/run.ex` — `workflow_version`, `workflow_checksum` frozen fields.
- `lib/kiln/runs/run_director.ex` — Rehydration checksum compare against `runs.workflow_checksum`.

### Prior phase context

- `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md` — Telemetry shape (`requested_model`, `actual_model_used`), PubSub deferred out of P3, `stream_async/4` consumer note for P7.
- `.planning/phases/06-github-integration/06-CONTEXT.md` — GitHub PR/checks vocabulary for run cards (“Checks passing / failing” per UI-SPEC).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/kiln_web/router.ex` — `live_session :default` + `KilnWeb.LiveScope`; `/ops` scope for LiveDashboard + Oban Web only today.
- `lib/kiln_web/controllers/page_controller.ex` — `redirect_to_ops/2` currently sends `/` → `/ops/dashboard`; Phase 7 **replaces** this with `RunBoardLive` at `/` (or equivalent redirect policy **explicitly** chosen in plan — CONTEXT locks **board at `/`**).
- `lib/kiln_web/live/spec_editor_live.ex` — Existing LiveView + `Layouts.app` pattern to mirror.
- `lib/kiln/runs/run.ex`, `lib/kiln/workflows/compiled_graph.ex` — Source of truth for workflow/version/checksum fields referenced by registry + cards.

### Established Patterns

- **Browser pipeline:** `pipe_through :browser` + `KilnWeb.Plugs.Scope` for HTML LiveViews.
- **D-94 integrity** — Any workflow “current vs run-frozen” UI must use checksum language already enforced at persistence layer.

### Integration Points

- **PubSub topics** — Named concretely in plan (bounded cardinality per ROADMAP P16); board subscribes to coarse run summary topics, not detail log firehoses.
- **Telemetry** — Cost rollups must attach to the same events Phase 3 defined for USD/token attribution.

</code_context>

<specifics>
## Specific Ideas

- Research synthesis requested **one-shot cohesive** recommendations: **domain routes at `/`**, **`/ops` = introspection only**, **query-driven run detail**, **unified default diff**, **Postgres workflow snapshots**, **time-first cost strip + Run tab default + separated projection**, **Linear-quiet realtime with neutral per-card highlight**.
- Optional URL query mirror for diff toggles when sharing “exact view” links matters more than minimal URLs.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 8** — Global factory header, agent ticker, provider health, cost **intel** callouts, unblock panel, onboarding wizard (may reuse `/costs` vs new `/cost-intel` path — defer path decision to Phase 8 CONTEXT).
- **Nested REST path** for stages (`/runs/:id/stages/:stage_id`) if audit exports demand hierarchy — v1 explicitly uses query form for less router surface.

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 07-core-run-ui-liveview*
*Context gathered: 2026-04-21*
