# Phase 8: Operator UX (Intake, Ops, Unblock, Onboarding) - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Kiln is **operable as a factory**: new work enters through **intake** (drafts, triage, promote), **ops** surfaces (provider health, cost intelligence, diagnostic bundle) answer “why did my run stall?” without log spelunking, **unblock** stays **typed + playbook + retry** (never chat-as-primary), **first-run onboarding** gates run start until environment readiness is proven, and **global factory chrome** (header, per-run progress, agent ticker) makes continuous activity obvious — all coherent with Phase 7 (domain routes at `/`, `/ops` = BEAM introspection only, streams-first, Linear-quiet realtime, brand book).

**Roadmap correction (naming):** `lib/kiln/intents.ex` defines **`Kiln.Intents` as queued operator run requests** (“start run”, `enqueue/1`) — **not** spec inbox. Inbox/draft/promote work lives under **`Kiln.Specs`** (draft lifecycle + promotion into existing `specs` / `spec_revisions`) unless a future ADR admits a separate bounded context. Importer module: **`Kiln.Specs.GitHubIssueImporter`** (not under `Kiln.Intents`). **Cost “intel”** ships inside **`KilnWeb.CostLive`** (tab/segment), not a separate `KilnWeb.CostIntelLive` top-level process for the same concern.

</domain>

<decisions>
## Implementation Decisions

### Routes & information architecture (D-801..D-805)

- **D-801 — `/ops/*` unchanged:** Provider health, cost intelligence, diagnostics, inbox, onboarding are **domain** concerns. **Never** mount them under `/ops` (preserves Phase 7 contract: LiveDashboard + Oban Web only).
- **D-802 — Cost intelligence on `/costs`:** Extend **`CostLive`** with a first-class **Intel / Advisory** surface (tab via `?tab=` + `push_patch` or path segment **`/costs/intel`** handled by the **same** LiveView via `handle_params/3`). One canonical “money & efficiency” URL family (GitHub Billing / AWS Cost Explorer pattern — numbers + narrative together). Avoid a second top-level `CostIntelLive` that duplicates queries/rules.
- **D-803 — Intel in header/cards as funnel, not home:** **Sparse, severity-gated** callouts in **`FactoryHeader`** and optionally run board cards linking to **`/costs?tab=intel`** (or patch). Not the sole store of advisories (avoids AWS Trusted Advisor-style banner fatigue and weak deep-links).
- **D-804 — New domain paths (concrete):** `/inbox` → `InboxLive`; `/health/providers` or `/providers` → `ProviderHealthLive` (pick one noun in plan; **recommended: `/providers`** — short, matches “factory floor”); `/onboarding` → `OnboardingLive`; diagnostic **trigger** can live on run detail + settings (`/settings/diagnostics` optional). All in the **same** `live_session :default` as Phase 7 unless a future `on_mount` split is required.
- **D-805 — Router sprawl:** Prefer **query-driven tabs** and **one LiveView per noun**; use `~p` helpers and stable bookmarks.

### Onboarding & environment gate (D-806..D-812)

- **D-806 — Primary surface = `/onboarding` route** (not a permanent blocking modal). Modals break refresh/deep-link; **`gh auth login` / Stripe CLI** mental model is **explicit flow + verify** (`gh auth status`). Optional **modal** only for catastrophic one-shot states (reuse sparingly).
- **D-807 — Three-layer gate, one module:** (1) **Router Plug** — redirect to `/onboarding` when factory not ready (allowlist: `/onboarding`, `/health`, static, `/ops/*`). (2) **Domain preflight** — `Runs` (or `RunDirector`) **must** reject enqueue/start when probes fail (**authoritative**; UI cannot disagree). (3) **`on_mount`** — enrich assigns / banner (“Setup incomplete”) for clarity — **never** the only enforcement.
- **D-808 — Readiness = probes + timestamps, not a one-way boolean:** Re-run relevant steps when API keys rot or `gh` logs out. Persist **check results / last success** in Postgres; **never** store secret **values** (SEC-01 — references + env/persistent_term only).
- **D-809 — Delegate to native tools:** Kiln **verifies** with read-only commands (`gh auth status`, Docker driver parity with `Kiln.Sandboxes`); links/docs for **`gh auth login`**, provider consoles — Kiln is not a second-rate OAuth host.
- **D-810 — Overlap with BootChecks:** **BootChecks** = port-binding integrity (audit, Oban, schema, infra secrets). **Onboarding** = **operator capability** (LLM keys, GitHub CLI identity, Docker CLI). Share **one implementation** of probe functions where both need the same truth; do not duplicate audit/DB invariants in the wizard UI.
- **D-811 — Escape hatch = D-33 family:** At most **one** loud env-based bypass for “I know what I’m doing,” **logged + auditable** (`safety_bypass_active`-class event), not many granular flags. Stigma in docs; same philosophy as `KILN_SKIP_BOOTCHECKS=1`.
- **D-812 — Recurring checklist:** Persistent **Settings → Environment** (or `/onboarding?review=1`) for **re-entry** without blocking every navigation — drawer/sidebar optional; primary first-run remains the wizard route.

### Intake, inbox, GitHub import (D-813..D-820)

- **D-813 — Raw material vs released specs:** **Drafts** are staging (`spec_drafts` / `inbox_items` table name TBD in plan) — mutable triage. **Promotion** is the only path into **`specs` + `spec_revisions`** for run-bound artifacts. Runs **never** bind directly to unpromoted drafts.
- **D-814 — Context ownership:** **`Kiln.Specs`** owns draft CRUD, promote, archive, GitHub import orchestration, and **“File as follow-up”** generation. **`Kiln.Intents`** stays **run enqueue only** (Phase 2+ contract).
- **D-815 — GitHub import core:** **`Req` + GitHub Issues API** in application code (structured JSON, ETag/`If-None-Match`, injection-safe URL building — **no shell interpolation**). Optional **`gh`-based dev adapter** documented for “use my logged-in CLI session” — not the only path.
- **D-816 — Follow-up payload shape:** Store **`source_run_id`**, optional **stage pointers**, **`artifact_refs`** (CAS keys + kinds + sizes), and a **short deterministic `operator_summary`** at creation — **lazy-resolve** full bodies when opening/editing drafts. No megabyte blobs in inbox rows by default.
- **D-817 — Idempotency:** **“File as follow-up”** uses **`external_operations`** (or equivalent intent row) with key like `follow_up_draft:run_id:correlation_id` — duplicate click returns **same** draft id; **`Audit.Event`** for `follow_up_drafted` in the same transaction as insert.
- **D-818 — Ecto transitions:** `inbox_state` via **`Ecto.Enum`** + context functions **`promote/2`**, **`archive/2`** — not raw `cast` of state from untrusted params. **Archive = `archived_at` timestamp** (soft delete). **Partial unique index** on open GitHub imports by **`node_id`** / `(owner, repo, issue_number)` to prevent duplicate inbox rows.
- **D-819 — Stale imports:** `last_synced_at` + **Refresh** action using stored **ETag**; show operator-visible “last synced” copy.
- **D-820 — Guards:** Promotion transaction = assert state + insert spec revision + link `promoted_spec_id` + audit append — same Postgres transaction (matches D-12 culture).

### Global factory header & agent ticker (D-821..D-828)

- **D-821 — Single subscribing process for live chrome:** **`FactoryHeader`** receives assigns from **one** parent subscriber per layout tree — **not** a LiveComponent per page that each opens a **duplicate** `Phoenix.PubSub` subscription (process fan-out pitfall; spirit of P16).
- **D-822 — Topic split (aggregate vs chatter):** **`factory:summary`** (or equivalent fixed name) for **counts, blocked badge, spend rollup, provider RAG summary** — **low rate** + debounced publisher. **Never** wire header to `run:#{id}` high-volume topics (Phase 7 D-728). Optionally slow-pull **HealthPlug JSON** for pieces that do not need sub-second updates (align D-31).
- **D-823 — Agent ticker placement:** **Home `/` only** per roadmap SC 8.10 and cognitive-load discipline (GitHub Actions pattern: **live tail in dedicated panel**, not sidebar spam). Optional **“Open activity”** link on other pages navigates to `/` **without** subscribing until opened.
- **D-824 — Rate limits:** **Publisher token bucket** + **consumer batch 100–250 ms** for `agent_ticker`; **coalesce** rows by `(run_id, stage_id)` for “still running” noise. **Cap stream depth** (e.g. 50–100 lines) with **`stream_delete` tail** — ticker is **not** the audit log.
- **D-825 — Streams:** Ticker uses **`stream` prepend** (`at: -1`) + cap; **no** `reset: true` on routine batches (Phase 7 D-725 alignment).
- **D-826 — Board coexistence:** Board stays **Linear-quiet**; ticker is the **designated** high-churn “factory is alive” surface. **No Ember** for ticker line noise; Ember stays Phase 7 reserved list.
- **D-827 — Motion:** **`prefers-reduced-motion`** gates highlight animation; truth = **timestamp + column placement** (D-727).
- **D-828 — Toasts:** Reserve **toasts** (if any) for **actionable escalations** — not per-agent-line (Slack anti-pattern).

### Unblock panel & diagnostics (D-829..D-832)

- **D-829 — Unblock primary home:** **`UnblockPanelComponent`** inlined in **`RunDetailLive`** when run is **blocked** — scannable panel: typed reason, **playbook commands** (BLOCK-02), **“I fixed it — retry”** → resumes from last checkpoint. Optional compact **global badge** in header linking to **first blocked run** or `/` filter — not a chat drawer.
- **D-830 — Desktop notifications:** Reuse Phase 3 **`Kiln.Notifications`** on block/escalation; **do not duplicate** with redundant browser notification permission prompts unless product copy explicitly ties one channel.
- **D-831 — Diagnostic bundle:** **Server-generated zip** (“last 60 minutes”) via **`Kiln.Diagnostics.Snapshot`** — secrets redaction pipeline mandatory; artifact downloadable from **run detail** and/or **settings**; temp storage path + TTL documented in plan.
- **D-832 — Per-run progress (UI-08):** **`RunProgress`** component on **board card + run detail header** — stages done/total, elapsed, **estimate** from historical percentiles when N sufficient else “Not enough history”, **staleness ramp** (green/amber/red per roadmap). Reuse telemetry facts from Phase 3/7 — no fictional precision.

### Claude's Discretion

- Exact tab label copy (“Intel” vs “Advisory” vs “Recommendations”).
- Debounce ms within 100–250 ms band; ticker stream cap exact count in 50–100 range.
- Whether `/providers` vs `/health/providers` wins — D-804 recommends `/providers`.
- CSV export location for diagnostic manifest index.
- **Projection N** for cost intel when history is thin (reuse Phase 7 “not enough data” pattern).

### Folded Todos

- None (todo.match-phase returned zero).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 8 requirements & vision

- `.planning/ROADMAP.md` — Phase 8 goal, success criteria, pitfall P16/P18 notes.
- `.planning/REQUIREMENTS.md` — BLOCK-02, BLOCK-04, INTAKE-01..03, OPS-01, OPS-04, OPS-05, UI-07..09.
- `.planning/PROJECT.md` — Out of scope (no chat unblock, solo operator, desktop-first).

### Prior phase locks (do not contradict)

- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — Domain vs `/ops`, `/` board, D-725..731 realtime + auth + streams.
- `.planning/phases/07-core-run-ui-liveview/07-UI-SPEC.md` — Typography, palette, Ember reservation, microcopy, stable IDs.
- `prompts/kiln-brand-book.md` — Full brand contract.
- `CLAUDE.md` — LiveView + layout rules.

### Architecture & intent naming

- `.planning/research/ARCHITECTURE.md` — `Kiln.Intents` as run-intent layer; four-layer model.
- `lib/kiln/intents.ex` — Authoritative stub: Intents = queued operator requests, **not** inbox.

### Health & safety patterns

- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — D-31 HealthPlug JSON, D-33 `KILN_SKIP_BOOTCHECKS`, audit + `external_operations` patterns (D-14..D-21).

### Comparable operator UX (research analogues)

- **GitHub Actions / Billing** — Usage + narrative in one product area (informed D-802).
- **`gh auth` / Stripe CLI** — Delegate auth, verify status (informed D-809).
- **Argo CD / Grafana** — Sparse health + in-place updates vs log spam (informed D-821..D-828).
- **Linear** — Quiet baseline; non-blocking hints (informed D-803, D-826).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/kiln_web/live/cost_live.ex` — Extend with intel tab; reuse rollup queries from Phase 7.
- `lib/kiln_web/live/run_board_live.ex`, `lib/kiln_web/live/run_detail_live.ex` — Mount `RunProgress`, unblock panel, header assigns injection points.
- `lib/kiln_web/components/layouts.ex` — Shell for `FactoryHeader` slot/wrapper (domain only).
- `lib/kiln/intents.ex` — **Do not** add inbox code here; enqueue-only boundary.
- `lib/kiln/boot_checks.ex`, `lib/kiln/health_*` — Probe patterns for onboarding vs boot split (D-810).
- Phase 3 **`Kiln.Notifications`**, **`Kiln.Blockers`** — Typed reasons + desktop notify for unblock flows.

### Established Patterns

- **`live_session :default`** + `KilnWeb.LiveScope` — New LiveViews register same session; use `push_patch` for tab UX.
- **`Layouts.app` + `current_scope`** — All new pages wrap consistently.
- **`external_operations` + audit** — Intake idempotency and snapshot export must follow two-phase semantics.

### Integration Points

- **PubSub** — Register `factory:summary` + rate-limited `agent_ticker` in **telemetry or run transition** publisher design doc in plan; align with Phase 7 topic cardinality discipline.
- **`Kiln.ModelRegistry` + adapters** — Provider health panel data sources.

</code_context>

<specifics>
## Specific Ideas

- Subagent research synthesized 2026-04-21: parallel review of routes, onboarding, intake/Ecto, and LiveView header/ticker patterns — recommendations unified here for **least surprise**, **solo-operator DX**, and **cohesion with Phase 7**.
- **Explicit correction:** ROADMAP Phase 8 artifacts line naming `Kiln.Intents` for draft CRUD conflicts with `lib/kiln/intents.ex` and ARCHITECTURE — planning/plan phase should align naming to **`Kiln.Specs`** for inbox/drafts.

</specifics>

<deferred>
## Deferred Ideas

- **Separate bounded context `Kiln.Inbox`** — Only if `Kiln.Specs` grows too large; requires ADR if context count policy is strict at 13.
- **`/costs/intel` as first-class path segment** — If tab UX hits complexity ceiling; still single `CostLive`.
- **Headless GitHub import without `gh` in CI** — Req-only path is default; full integration tests may tag `docker` / network.
- **Email/webhook for BLOCK-03** — v1.1+ per REQUIREMENTS.md.

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 08-operator-ux-intake-ops-unblock-onboarding*
*Context gathered: 2026-04-21*
