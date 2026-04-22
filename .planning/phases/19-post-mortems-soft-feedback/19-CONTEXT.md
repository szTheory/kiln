# Phase 19: Post-mortems & soft feedback - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **SELF-01** + **FEEDBACK-01**: (1) On **merge**, persist a **structured post-mortem** (tokens/$ by stage, retries, `requested_model` vs `actual_model_used`, scenario verdict trail, block reasons) and make it **discoverable from the run**; (2) **One-line soft nudge** during a run → **`operator_feedback_received`** audit (append taxonomy); **non-blocking** — no new approval gates; scenario runner remains acceptance oracle (**UAT-02** unchanged).

Out of scope: multi-operator nudge threads, Slack/webhook delivery as required path, training pipelines on nudge text, changing `:paused` / state machine for steering, freeform chat-to-unblock, cross-run personalization.

</domain>

<decisions>
## Implementation Decisions

### Research method (D-1900)

- **D-1900 — One-shot synthesis:** Operator selected **all four** discuss gray areas and requested **parallel subagent research** (persistence, async timing, runtime contract, UX). Recommendations below are merged into a **single coherent** v1 that fits **Postgres SOT**, **append-only audit**, **`Kiln.Audit.EventKind`** append-only migrations, **`RunDetailLive`**, **Oban idempotency**, and **Phase 18 / 16 / 15** surfaces (run detail, thresholds, replay/compare).

### SELF-01 — Persistence & discovery (D-1901–D-1906)

- **D-1901 — Primary store (hybrid core):** Introduce **`run_postmortems`** (1:1 `run_id`, **`unique_index(:run_id)`**). Hold **typed summary columns** for anything operators filter on (e.g. terminal reason class, total USD bands, workflow id/version, scenario outcome enum) plus **`schema_version`** and **JSONB** for nested sections (per-stage breakdown, verdict trail, routing history).
- **D-1902 — Optional CAS attachment:** Link **`artifact_id` / digest** from the row when an **immutable export-grade** or oversized bundle is needed. **Postgres row is authoritative** for the app; CAS is **evidence / export**, not the only query path — avoids CAS-only footguns (weak SQL, GC broken links).
- **D-1903 — Avoid fat `runs`:** Do **not** park the full post-mortem blob on `runs` — keeps hot row small, avoids TOAST on every run list query, preserves clear lifecycle (run state vs analytic snapshot).
- **D-1904 — Discoverability:** **Primary surface** = **`RunDetailLive`** (same mental model as Phase **18** cost panel): panel or tab **keyed by `run_id`**, preload `has_one :postmortem` / left join. **Secondary:** deep links from **compare** / **replay** UIs using **`run_id`** only (no second navigation model).
- **D-1905 — Schema evolution:** Writers own one generator; **`schema_version`** on row; readers tolerate **N and N-1**; unknown major → calm fallback (raw JSON + operator notice). Regenerate = new job / new row generation — **do not mutate** append-only audit to fix old summaries.
- **D-1906 — Secrets / PII:** Scrub at write time — post-mortem JSON must **not** echo raw secrets, full prompts, or unredacted tool payloads unless an explicit future REQ allows it.

### SELF-01 — Generation timing & sources (D-1910–D-1917)

- **D-1910 — Async materialization (primary):** On successful **`:merged`** transition **after** `Repo.transact` commits, enqueue **one** Oban worker with **insert-time uniqueness** e.g. idempotency key **`post_mortem_materialize:<run_id>`** (same spirit as `Kiln.Oban.BaseWorker` + `external_operations` patterns). **Do not** run heavy aggregation inside the merge transaction.
- **D-1911 — Thin merge transaction:** Merge path stays: state update + mandatory **`run_state_transitioned`** (and existing invariants) only — same bounded shape as today’s transitions.
- **D-1912 — Source-of-truth cut:** Build snapshot from **`stage_runs`** (metrics, models, costs) + **ordered audit replay** (capped walk) with an explicit **`source_watermark`** (e.g. max `audit_events.id` or `(occurred_at, id)` at enqueue time). Document whether **tail events after watermark** appear as a separate UI section vs excluded — **fixed cut** preferred for forensics.
- **D-1913 — Read path until row exists:** If post-mortem row missing, UI shows **deterministic partial** from `stage_runs` + recent audit tail + calm **“Summary generating”** (mirrors “materializing” patterns from CI job summaries / analytics projections).
- **D-1914 — Idempotent upsert:** Worker uses **`INSERT … ON CONFLICT (run_id)`** semantics (`DO NOTHING` if complete + same watermark, or controlled `DO UPDATE` if regeneration allowed). Short-circuit if snapshot **`status: :complete`** and inputs unchanged.
- **D-1915 — Failure posture:** If job exhausts retries, run remains **`:merged`** (correct); surface **degraded** state in UI + metric; offer **operator-triggered rebuild** enqueue (new idempotency suffix) — optional in v1 but pattern reserved.
- **D-1916 — Lazy-only rejected:** **Do not** rely on first-view full recompute as sole persistence — thundering herd, timeouts, inconsistent first paint. Lazy read is **pre-snapshot UX only**.
- **D-1917 — Optional ledger echo:** One optional append-only audit kind after successful snapshot (e.g. pointer + `schema_version` + watermark) — **not** a duplicate of the full JSON narrative. **Exact atom name** left to plan (taxonomy migration).

### FEEDBACK-01 — Runtime contract (D-1920–D-1928)

- **D-1920 — Write path:** Every accepted nudge ends as **`operator_feedback_received`** (new **`EventKind`** + migration CHECK append + JSON schema under `priv/audit_schemas/`). Optional narrow **`operator_nudges`** table **or** payload-only-on-audit — planner chooses in plan; **audit row is the FEEDBACK-01 contract**.
- **D-1921 — Consumption boundary (planner-only):** After persistence, expose a **structured `OperatorNudge` context** (run_id, stage_seq / ids, monotonic seq, UTC, **bounded UTF-8 body**, optional future **intent enum**) **only** to **planning / replan** paths — **not** every coding LLM turn, **not** tool arguments, **not** scenario YAML, **not** shell.
- **D-1922 — No raw coding injection:** If coding must change, it flows through **plan deltas the planner produced**, influenced by the structured object — **never** paste raw operator string into codegen system prompts.
- **D-1923 — Advisory framing:** Model-facing template states explicitly: **advisory**; **cannot waive tests**; **scenario runner is oracle** — same constitution as **BLOCK-01** separation (typed blocks stop; nudges steer).
- **D-1924 — SoT = Postgres:** Accept nudge in **HTTP/LiveView → transaction** writing audit (+ optional row); **do not** buffer only in `Run.Server` mailbox. Consumption reads **DB** at stage boundary; advance **`last_consumed_seq`** (column or side table) **in the same transaction** as “applied to planner context” to prevent double-delivery on retry.
- **D-1925 — Validation:** Hard max **~200 graphemes** (align UX D-1931); strip control chars; normalize whitespace; reject empty-after-trim.
- **D-1926 — Telemetry / logs:** Emit **`[:kiln, :operator, :nudge, :received | :consumed]`** with counts/metadata **only** — **no** raw body in logs, spans, or metrics backends.
- **D-1927 — Pure audit-only path rejected for Phase 19:** Audit+UI without **any** consumption fails **SEED-001** intent and solo-operator trust; **D-1921** is the minimal behavior slice.
- **D-1928 — Full freeform injection rejected:** Broad **(B)-style** raw system-message injection maximizes prompt-injection surface and redaction gaps — **out of scope** for Phase 19.

### FEEDBACK-01 — UX & guardrails (D-1930–D-1936)

- **D-1930 — Placement:** **Inline composer** on **`RunDetailLive`**, anchored to **header / primary status band** (same region as run state + primary actions). **Read-only** nudge markers in **timeline / replay** as first-class events (append-only feel; borders-over-shadows density).
- **D-1931 — Length & shape:** Default **single-line** input; **~140–200 character** hard cap; optional “expand detail” → max **3 lines** only if product needs it — default stays **PagerDuty-note / GitHub-single-comment** discipline, not Slack thread.
- **D-1932 — Spam guards:** **10–30 s soft cooldown** between submits + generous **hourly cap**; **`phx-disable-with`** on submit; **client + server** idempotency (reuse `external_operations` pattern if POST crosses network boundary twice).
- **D-1933 — Microcopy:** Operational, time-scoped, **steering not chat** — e.g. “Reminder: …”, “Heads-up: …”. **Never** unblock negotiation tone (that stays **typed block playbooks**).
- **D-1934 — Blocked runs:** Composer **allowed** (non-blocking by definition) but **must not** replace or mimic **BLOCK** remediation UI — visual separation so operators do not confuse **nudge** with **unblock**.
- **D-1935 — Accessibility:** Label **“Operator note (nudge)”**, `aria-describedby` with limits + cooldown text; **Enter submits**, **Shift+Enter** only if multiline enabled.
- **D-1936 — Optimistic UI:** Optional **single** pending timeline row with server reconcile; **no** duplicate immutables without `client_message_id` / ref dedupe.

### Cross-cutting (D-1940–D-1943)

- **D-1940 — Taxonomy migration:** Add **`:operator_feedback_received`** (+ optional **`:post_mortem_snapshot_stored`** if D-1917 ships) via **append-only** `@kinds` + generated CHECK migration — same discipline as **Phase 18** `:budget_threshold_crossed`.
- **D-1941 — PubSub:** On post-mortem row insert / nudge accept, broadcast on existing **`run:#{id}`** channel so **`RunDetailLive`** refreshes without full reload.
- **D-1942 — Verification:** LiveView tests (composer states, disabled submit, cooldown messaging); Oban job unit tests (idempotency, watermark); audit changeset tests for new kind; **no** raw nudge text in log capture assertions.
- **D-1943 — Brand:** **`prompts/kiln-brand-book.md`** — calm, precise, rectangles-first; nudge UI is **annotation**, not a second chat product.

### Claude's Discretion

- Exact **grapheme cap** (140 vs 200), **cooldown seconds**, and **hourly cap** numbers; whether **`operator_nudges`** table ships vs audit-payload-only.
- Whether **`:post_mortem_snapshot_stored`** audit kind ships in Phase 19 or post-mortem row alone is enough for replay.
- Whether **CAS artifact** for post-mortem ships in **19** or a fast-follow **19.x** once JSONB size observed in dogfood.
- Optional **intent enum** chips on nudge composer (future UX).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — **SELF-01**, **FEEDBACK-01**
- `.planning/ROADMAP.md` — Phase 19 goal and success criteria
- `.planning/PROJECT.md` — Dark factory, no approval gates, bounded autonomy, Postgres SOT, brand
- `.planning/seeds/SEED-001-operator-feedback-loop.md` — Full steering-loop intent and historical open questions (now resolved at D-1920–D-1928 / D-1930–D-1936)

### Audit & durability

- `lib/kiln/audit/event_kind.ex` — Append-only taxonomy pattern
- `lib/kiln/audit/event.ex` — Event schema
- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — Append-only ledger invariants (D-12 family)

### Runs, stages, transitions

- `lib/kiln/runs/transitions.ex` — Merge transition boundary (post-commit enqueue hook)
- `lib/kiln/runs/run.ex` — States including `:merged`
- `lib/kiln/stages/stage_run.ex` — Metrics / cost facts for aggregation

### Operator UI

- `lib/kiln_web/live/run_detail_live.ex` — Primary surface for post-mortem panel + nudge composer (D-1904, D-1930)
- `.planning/phases/18-cost-hints-budget-alerts/18-CONTEXT.md` — Run detail panel + PubSub cadence patterns (compose, do not duplicate COST semantics)
- `.planning/phases/16-read-only-run-replay/16-CONTEXT.md` — Timeline / replay cohesion (nudge as event type)
- `.planning/phases/15-run-comparison/15-CONTEXT.md` — Compare linking by `run_id`

### Voice

- `prompts/kiln-brand-book.md` — Operator microcopy discipline

### Prior phase constraints

- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-CONTEXT.md` — Typed blocks vs chat; keep nudge visually and semantically distinct
- `.planning/phases/02-workflow-engine-core/02-CONTEXT.md` — `:paused` / FEEDBACK deferred history — Phase 19 does **not** add `:paused`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`Kiln.Audit.EventKind` + migration-generated CHECK** — Pattern for **`:operator_feedback_received`** (+ optional snapshot kind).
- **`Kiln.Runs.Transitions`** — Post-commit enqueue point (mirror notification / PubSub ordering).
- **`RunDetailLive` + `run:#{id}` PubSub** — Single locus for cost hints (**Phase 18**), post-mortem panel, nudge composer.
- **`Kiln.Oban.BaseWorker` + idempotency keys** — Deduplicated materialization jobs.

### Established patterns

- **Postgres transactional truth**; GenServers rehydrate policy from DB — nudges **must not** rely on process mailbox alone.
- **Append-only audit** for operator-visible facts; **JSON schemas** in `priv/audit_schemas/v1/`.

### Integration points

- **Merge success path** → Oban **`PostMortemMaterialize`** (name TBD) worker.
- **Stage planning entry** → read unconsumed nudges + advance cursor → inject structured planner context only.
- **Replay / compare** → render `operator_feedback_received` + post-mortem row as timeline facts.

</code_context>

<specifics>
## Specific Ideas

- Parallel **research synthesis** requested by operator: treat **hybrid post-mortem storage**, **async Oban materialization**, **planner-only bounded consumption**, and **run-detail inline nudge** as a single shipped story — not four competing designs.

</specifics>

<deferred>
## Deferred Ideas

- **Webhook / desktop push for nudges** — channel layer; not required for FEEDBACK-01 v1.
- **Multi-line threaded operator chat** — violates “steering not chat”; out of scope.
- **Automatic model routing changes from nudge text** — conflicts adaptive routing integrity; never.
- **Cross-run “learning” on nudge corpus** — training / personalization cluster; out of Phase 19.

### Reviewed Todos (not folded)

- None — `todo.match-phase 19` returned no pending matches.

</deferred>

---

*Phase: 19-post-mortems-soft-feedback*  
*Context gathered: 2026-04-22*
