# Phase 16: Read-only run replay - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **REPL-01**: operator **scrubs a read-only timeline** of **one run** from **persisted append-only data** (audit-first spine + stage context) for **incident-style review**. **MVP** = `SELECT`-only compositions; **no** mutation, **no** re-execution, **no** “branching realities” (REPL-02 deferred per `.planning/REQUIREMENTS.md`).

Out of scope: run comparison (15), fairness (14), templates/cost/post-mortem phases, hypothetical **REPL-02** re-run-from-checkpoint, merged workspace diff, materialized global event bus across unrelated tables.

</domain>

<decisions>
## Implementation Decisions

### Research synthesis (2026-04-22)

Four parallel research passes covered routing, data spine, scrub UX, and live-vs-frozen behavior. Themes: **run-centric deep links** (Honeycomb/GitHub Actions/Sentry), **one authoritative ordering** (event-sourcing / trace “spine vs logs” lesson), **log-viewer ergonomics** over cinematic playback, **follow-vs-paused** tail semantics (`tail -f`, Grafana). Below locks a **single coherent MVP** aligned with Phase 7 URL truth, Phase 15 router discipline, Postgres SoT, and D-12 append-only audit.

### Routes & shell

- **D-01 — Primary surface:** **`GET /runs/:run_id/replay`** as a **dedicated LiveView** (working name **`RunReplayLive`**) in the **same** `live_session :default` as `RunBoardLive` / `RunDetailLive` / compare — operator chrome and hooks stay consistent.
- **D-02 — Router ordering:** Add **`live "/runs/:run_id/replay", …`** in the same `live_session`, **grouped with other `/runs/:run_id/…` multi-segment routes** (see `DiagnosticsZipController` precedent in `router.ex`). This path is **not** the `/runs/compare` footgun (three segments vs two); still keep **literal multi-segment routes** easy to scan **above** the generic **`live "/runs/:run_id"`** route for consistency.
- **D-03 — URL drives scrub state:** Encode **cursor** in query (e.g. `at=<event_id>` or keyset pair documented in plan) and rebuild the **window around the cursor** in **`handle_params/3`**. **Intra-replay** scrub uses **`push_patch`**; **entering** replay from board/detail uses **`push_navigate`** (mode change).
- **D-04 — Param validation:** Reuse **`Ecto.UUID.cast/1`** on `run_id`; align error UX with **`RunDetailLive` / `RunCompareLive`** (flash + redirect or inline shell — pick one pattern in plan; default: **match detail** for invalid UUID).
- **D-05 — Ledger vs narrative:** Keep **`/audit` (`AuditLive`)** as the **cross-run filter-first** escape hatch; add **deep links** **replay → audit** with `run_id` pre-filled and **detail/board → replay** (“Timeline” / equivalent). Do **not** make `/audit` the primary scrub canvas — wrong mental model for “story of run X.”
- **D-06 — Read-only stance:** Replay surface presents **no** resume/unblock/compare pickers; forensic clarity beats feature density (contrast stuffing replay into **`RunDetailLive`** without a gate).

### Timeline spine & queries

- **D-07 — Canonical spine:** **`audit_events` for `run_id`**, total order **`ORDER BY occurred_at ASC, id ASC`** (document + test tie-break; aligns UUID v7 insertion correlation in `Kiln.Audit.Event`).
- **D-08 — No naive UNION MVP:** Do **not** interleave **`work_unit_events`** or mutable **`stages` / `runs` row timestamps** into the sorted spine without an explicit dedup/version contract — avoids double-count and “retroactive lie” footguns (CI step flattening / trace+log merge lessons).
- **D-09 — Stage checkpoints in REPL-01:** Treat **checkpoints** as **first-class audit kinds** already written in **the same Postgres transaction** as transitions where applicable; otherwise show **stage/run as header context** (labels, workflow stage id), **not** fake history from `updated_at` on mutable rows.
- **D-10 — Secondary lane (optional MVP slice):** If work-unit narrative is required for v1, use a **second pane or collapsible lane**: query `work_unit_events` by `run_id`, **locally ordered**, correlated by `stage_id` / ids — **same screen, separate sort**, not merged timestamp collage.
- **D-11 — Long runs:** Prefer **keyset** continuation over large **OFFSET**; surface **truncation** when over cap (today `Audit.replay/1` defaults **`limit: 500`** — replay must not **silently** clip without operator-visible copy).

### Scrub interaction & UI

- **D-12 — Primary controls:** **Focusable event list** (windowed / virtualized pattern) as the **spine** + **Prev / Next** (always) + **First/Last** optional; **single selection** drives detail panel (`current_event_id` in assigns + URL).
- **D-13 — Secondary scrubber:** **`<input type="range">` mapped to event index** (not raw milliseconds unless time zoom is explicitly scoped); **commit on pointerup** / debounced **`phx-change`** — avoid server storms on drag.
- **D-14 — Play/pause:** **Non-default**; if shipped, advance **discrete events** only (log viewer, not video). **`prefers-reduced-motion`:** disable smooth auto-scroll and auto-advance; prefer **instant seek** + stepped navigation.
- **D-15 — Skimming:** **Filter chips** (e.g. errors, stage, actor) + **search** beat high-speed playback for long runs.
- **D-16 — Brand & tests:** Borders-over-shadows, mono for timestamps/ids per brand book; stable DOM ids (`#run-replay`, `data-run-id`, `replay-event-{id}`, transport controls) for **LazyHTML** tests; basic **ARIA** (`slider`, list selection) where cheap.

### Live vs frozen snapshot

- **D-17 — Initial load:** Always **query persisted timeline from DB** on mount / `handle_params` — REPL-01 core.
- **D-18 — Terminal runs** (`merged` \| `failed` \| `escalated`): **No live subscription** to audit tail; timeline is a **frozen snapshot**. Optional single **Refresh** control.
- **D-19 — In-flight runs:** **Subscribe** to existing **run-scoped PubSub** (or audit fan-in filtered server-side) for **append-only** tail with **coalesced `handle_info`** (debounced flush or micro-batch).
- **D-20 — Follow vs inspect:** Apply streamed events only when UI is at **live edge** (cursor at latest / pinned tail); when scrubbed away from edge, **buffer** and show **“N new events — jump to latest”** (log viewer / “run changed since opened” family) — **never** append under an active scrub without explicit user jump.
- **D-21 — Status copy:** One line: **Live** vs **Complete** + **last event time** when live — reduces false completeness during bursts.

### Shared read model & DX

- **D-22 — Context layer:** One module (name TBD in plan) exposes **`timeline_window(run_id, cursor, opts)`** (audit spine + optional lane queries) callable from **`RunReplayLive`** and tests — avoid forked query logic between replay and **`AuditLive`**.
- **D-23 — Verification:** LiveView tests: happy path **navigate → replay URL →** list + selection; **invalid UUID** path; **truncation / empty** states; stable selectors from D-16.

### Claude's Discretion

- Exact query param names for cursor/keyset.
- Whether **work-unit lane** ships in MVP slice or first dot release after audit-only spine is proven.
- Mini-map / tick rail for error density (stretch).
- **16.1 idea:** drift banner using max audit sequence vs opened generation (compose with Phase 15 “changed since opened” patterns when cheap).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — REPL-01, REPL-02 deferred note  
- `.planning/ROADMAP.md` — Phase 16 goal and success criteria  
- `.planning/PROJECT.md` — Postgres SoT, append-only audit (D-12), bounded autonomy, solo operator  

### Prior phase contracts

- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — URL truth, `RunDetailLive`, streams, stable ids  
- `.planning/phases/15-run-comparison/15-CONTEXT.md` — D-01–D-08 router ordering, query validation, compare vs replay boundary  
- `.planning/phases/14-fair-parallel-runs/14-CONTEXT.md` — fairness out of scope; telemetry patterns if dwell metrics ever touch replay  

### Implementation anchors

- `lib/kiln/audit.ex` — `replay/1`, filters, default limit  
- `lib/kiln/audit/event.ex` — schema, UUID v7 note  
- `lib/kiln_web/live/audit_live.ex` — `/audit` stream + `handle_params`  
- `lib/kiln_web/live/run_detail_live.ex` — UUID gate, panes, existing audit usage  
- `lib/kiln_web/router.ex` — `live_session :default`, ordering vs `/runs/compare`  
- `prompts/kiln-brand-book.md` — visual/voice contract  

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`Audit.replay/1`** — run-scoped ordered events; extend with keyset + explicit truncation UX rather than forking.  
- **`AuditLive`** — patterns for `handle_params` → query → `stream(..., reset: true)`; link target with pre-filled filters.  
- **`RunDetailLive`** — stage/pane query vocabulary; possible **“Open timeline”** navigation source.  
- **`RunCompareLive` / router** — precedent for **static path before** `/runs/:run_id`.

### Established patterns

- Append-only **`audit_events`** as durable narrative; JSV-validated payloads at append.  
- PubSub after run transitions — reuse for **D-19** with gating (D-20).

### Integration points

- New **`RunReplayLive`** + **timeline read API** in `Kiln.Audit` (and/or `Kiln.Runs`) + router entry **before** dynamic run id route.

</code_context>

<specifics>
## Specific Ideas

- Cross-product patterns explicitly considered: **GitHub Actions** run/step permalinks, **Honeycomb/Sentry** event-centric URLs, **Grafana** time-in-URL reproducibility, **trace vs log separation** in APM — inform **D-07–D-10** and **D-18–D-20** without copying their complexity.

</specifics>

<deferred>
## Deferred Ideas

- **REPL-02** — re-execution / alternate branch from checkpoint — explicit defer in REQUIREMENTS.  
- **Materialized unified timeline table** — only if profiling proves need.  
- **Heuristic timestamp interleave** across audit + work units without dedup keys — avoid.  
- **Session-replay-style ghost cursor / cinematic UX** — off-brand; not planned.

</deferred>

---

*Phase: 16-read-only-run-replay*  
*Context gathered: 2026-04-22*
