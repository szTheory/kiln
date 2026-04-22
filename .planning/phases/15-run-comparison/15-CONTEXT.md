# Phase 15: Run comparison - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **PARA-02**: operator opens a **run comparison** for **two** runs (metadata, stage outcomes, artifact/diff pointers, cost summary) **without leaving the operator dashboard**. Entry from **run board or run detail**. Observable success: selection flow + comparison surface + **LiveView happy-path tests** with stable selectors.

Out of scope: **merged** diff of two workspaces, rename detection across runs, full artifact-tree compare inside this LiveView, replay (Phase 16), fairness tuning (14), templates/cost/post-mortem phases.

</domain>

<decisions>
## Implementation Decisions

### Research basis

Four parallel research passes (entry/selection, routing, layout, artifact depth) were synthesized into one contract. Themes: **URL as system of record** (Phase 7), **GitHub-style shareable compare** + **explicit baseline/candidate semantics** (avoid symmetric A/B confusion), **CI/Argo-style union-on-stable-keys**, **no second diff engine**.

### Routes & LiveView shell

- **D-01 — Canonical route:** `GET /runs/compare` implemented as a dedicated LiveView (working name **`RunCompareLive`**) in the **same** `live_session :default` as `RunBoardLive` / `RunDetailLive` (`KilnWeb.LiveScope`, `FactorySummaryHook`).
- **D-02 — Router ordering:** Declare **`live "/runs/compare", …` before `live "/runs/:run_id", …`** so the path segment `compare` is never interpreted as a `run_id` (today invalid UUID still matches the dynamic segment first).
- **D-03 — Required query (v1):** **`baseline=<uuid>&candidate=<uuid>`** — both required for a normal compare session. Names encode **semantics** (which side is reference vs subject) and reduce operator misreads vs anonymous `a`/`b` or path-ordered UUID pairs.
- **D-04 — Optional query (later / if needed):** Shared **`stage`**, **`pane`**, or alignment flags may mirror `RunDetailLive` query vocabulary; keep keys short if the list grows. Intra-compare changes use **`push_patch`**; entering compare from board/detail uses **`push_navigate`** (mode change, clear history boundary).
- **D-05 — Param validation:** **`Ecto.UUID.cast/1`** on both ids. **Malformed UUID** → **`put_flash(:error, …)` + `push_navigate` to `~p"/"`** — same spirit as `RunDetailLive` today.
- **D-06 — Missing run with valid UUIDs:** Keep the operator on **`/runs/compare?…`** and render the **compare shell** with an **inline error** in the column for the missing run (and actionable copy). **Rationale:** pasted/handoff links stay debuggable; differs slightly from single-run detail redirect but optimizes two-ID incident flows.
- **D-07 — Duplicate ids:** `baseline == candidate` → explicit policy in `handle_params` (warning row, single-column mode, or blocked — pick one in plan; default recommendation: **allow** with prominent “same run twice” warning for empty analytical value).
- **D-08 — Swap sides:** A **Swap** control **rewrites query params** (and uses `push_patch` or `push_navigate` consistently), never assign-only toggles.

### Entry & selection (board + detail)

- **D-09 — Convergent navigation:** Any entry path **lands on the same** `RunCompareLive` URL shape — no alternate “hidden compare” state.
- **D-10 — From run detail:** Current run is the **baseline** anchor; **“Compare with…”** opens a **modal or drawer** picker (search/recents; future: same-spec filter when cheap). Choosing the second run **`push_navigate`s** to `/runs/compare?baseline=…&candidate=…`.
- **D-11 — From run board:** Optional **two-slot compare strip** (or equivalent) fills **baseline** then **candidate**; when both chosen, **`push_navigate`** to the compare URL. Slots are **not** the long-lived source of truth — the URL is.
- **D-12 — PubSub:** Default **load on navigate**; if live drift is added later, **coalesce** updates and avoid board-style high-frequency streams on the compare page unless justified.

### Layout, alignment, cost

- **D-13 — Responsive hybrid:** **`≥lg`:** sticky **identity band** (titles, states, workflow fingerprint, refs) + **union stage spine** — **one row per stable stage key** (`workflow_stage_id` / compiled identity), **two subcells** (baseline | candidate) for outcome, duration, retries, cost numbers. **`<lg`:** same union ordering; subcells **stack** within the row (single scroll container). Avoid independent dual scroll panes for the primary spine.
- **D-14 — Alignment:** **Never** pair stages by **list index alone**. When workflows diverge, show **gaps** (“present only in baseline”, “missing on candidate”) per Argo CD / CI compare patterns.
- **D-15 — Cost:** **Summary strip** at top (totals + delta when stage keys align) + **per-stage numbers** in the union table. Use **tabular numerals** / mono per Phase 7 cost rules where applicable.
- **D-16 — Density & motion:** Brand contract — borders over shadows, Ember **only** for primary actions (e.g. open diff, swap). **No** continuous reordering of rows on tick; update cells in place; respect **`prefers-reduced-motion`**.

### Artifacts & diff pointers (depth)

- **D-17 — Hybrid v1 (no scope creep):** For each comparable artifact row: **logical key**, **byte size**, **digest when persisted** (`sha256` or project-standard), **coarse equality** (same / different / unknown / one-sided). **Primary action:** **deep-link** into **`RunDetailLive`** diff (and pane/stage query) for **each** run — **reuse Phase 7 diff pipeline**; **do not** build a second highlighter or merged workspace diff in this phase.
- **D-18 — Micro-preview (optional):** At most **tiny** inline excerpt for text artifacts, under the **same cap philosophy** as run detail (e.g. 512 KiB / truncation); must link to the **canonical** diff pane. Default off until cheap.
- **D-19 — Data loading:** Build a **read model** in a context function (e.g. `Kiln.Runs` compare API): **one or two bounded queries** with **`preload`**, **no N+1**; **exclude** large blob fields from compare queries. LiveView assigns hold **presentation-ready** rows + URLs only.
- **D-20 — Copy:** Prefer **“Same digest (SHA-256)”** / **“Different bytes”** / **“Present only in baseline”** over vague “same file.”

### Verification

- **D-21 — Tests:** LiveView tests for happy path: board (or detail) → compare URL → both columns render; assert **stable ids** (e.g. `#run-compare`, `data-baseline-id`, `data-candidate-id`, row `data-stage-key`). Cover **invalid UUID** redirect and **one missing run** inline error if implemented.

### Claude's Discretion

- Exact **PubSub** subscription strategy for in-flight runs on compare page.
- Picker UX details (search debounce, recents count, empty picker).
- Whether **micro-preview** ships in v1 or is deferred.
- **Collapse / focus** UX when stage cardinality is large (e.g. show first divergence ± N) without new product capabilities.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — PARA-02  
- `.planning/ROADMAP.md` — Phase 15 goal and success criteria  
- `.planning/PROJECT.md` — Postgres SoT, bounded autonomy, solo-operator scope  

### Prior UI & run inspection contracts

- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — D-701–D-731 (routes, URL truth, streams, stable IDs, diff defaults)  
- `.planning/phases/07-core-run-ui-liveview/07-UI-SPEC.md` — typography, palette, stream/async table rules  
- `prompts/kiln-brand-book.md` — brand contract  
- `lib/kiln_web/live/run_board_live.ex` — board streams / PubSub  
- `lib/kiln_web/live/run_detail_live.ex` — `handle_params`, panes, diff caps, `Runs.get` / UUID validation  
- `lib/kiln_web/router.ex` — `live_session :default` composition  

### Adjacent milestone context

- `.planning/phases/14-fair-parallel-runs/14-CONTEXT.md` — explicit out-of-scope boundary for Phase 15  

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`RunBoardLive`**: Kanban streams per state; natural home for compare slot UI + navigate to compare.  
- **`RunDetailLive`**: UUID gate + flash redirect pattern; stage/pane query contract; diff loading via **`Artifacts.read!/1`** with byte cap — **link here** rather than reimplement.  
- **`KilnWeb.Router`**: Add static **`/runs/compare`** before **`/runs/:run_id`**.

### Established patterns

- URL-driven inspection (`push_patch` on detail); use **`push_navigate`** when opening the compare **surface** from elsewhere.  
- LazyHTML-oriented **stable DOM ids** on operator surfaces.

### Integration points

- New **`RunCompareLive`** + context-layer **compare read model** + links back to **`~p"/runs/#{id}"?…`**.

</code_context>

<specifics>
## Specific Ideas

- Cross-ecosystem patterns explicitly borrowed: **GitHub compare** (durable GET URLs), **Argo CD / CI job compare** (union on stable keys + gap semantics), **Honeycomb/Grafana** (delta summary discipline).  
- Operator mental model: **Baseline = reference run**, **Candidate = subject under inspection** (copy and URL params stay consistent everywhere).

</specifics>

<deferred>
## Deferred Ideas

- **Merged workspace / semantic diff** across two runs — future phase if product demands.  
- **Saved comparisons** table, share tokens beyond UUID query params, automation export (CSV) — after PARA-02 MVP.  
- **Realtime drift banner** (“runs changed since opened”) — optional enhancement.

</deferred>

---

*Phase: 15-run-comparison*  
*Context gathered: 2026-04-22*
