# Phase 33: Repeat-run continuity on attached repos - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the second and third runs on one attached repo feel native by reusing the known attached repo identity, managed workspace, prior bounded-request context, and prior trust artifacts without forcing the operator to rediscover the attach flow.

This phase is about the **continuity contract** for one attached repo. It should add a durable continuity entry point, explicit prior-run context, and safe carry-forward behavior for repeat work on the same repo.

It is **not** about widening brownfield refusal coverage beyond the current safety gate, detecting broader scope collisions, overlapping PR analysis, or tightening draft-PR handoff copy. Those stay in **Phases 34-35**.

</domain>

<decisions>
## Implementation Decisions

### Continuity entry point

- **D-3301:** Continuity should be anchored to a **durable attached repo object**, not to transient LiveView socket state, browser-local memory, or a raw prior chat/session.
- **D-3302:** The default repeat-run entry point should stay on the existing **`/attach`** surface for now, but become **route-backed continuity** rather than “type the repo source again every time.”
- **D-3303:** The continuity selector should be driven by **server-loaded identifiers in the URL** such as attached repo, draft, or prior run ids. Only ids belong in params; all real state must be reloaded and revalidated on the server.
- **D-3304:** For the current single-screen product shape, prefer **`/attach?...` with `handle_params/3` / `push_patch`** over hidden modal state or browser-owned resume state. If the surface later grows into a repo-centric shell, it may graduate to a repo-specific route, but Phase 33 should not require that leap.
- **D-3305:** “Resume last run” may exist as a **secondary shortcut**, but it must not be the primary continuity key. The primary continuity key is **repo + durable work object**.

### What counts as the durable work object

- **D-3306:** The Phase 33 continuity anchor is the **attached repo first**, then the nearest durable work object already owned by Kiln for that repo:
  - open attached draft
  - otherwise most recent promoted attached request
  - otherwise most recent linked run
- **D-3307:** Do **not** anchor repeat-run continuity on raw transcript history or ad hoc browser memory. Those are too stale and too hard to reason about in brownfield work.
- **D-3308:** Reusing one attached repo must remain **single-repo only**. Cross-repo or multi-root continuity is explicitly out of scope for this phase.

### Request carry-forward

- **D-3309:** Carry forward **authorial intent**, not opaque session state. The reusable pieces are:
  - request kind
  - change summary
  - acceptance criteria
  - out-of-scope notes
  - brief prior outcome summary
- **D-3310:** Prefill precedence should be explicit and least-surprising:
  - explicit draft from params, if it belongs to the selected attached repo
  - otherwise most recent open attached draft for that repo
  - otherwise most recent promoted attached request for that repo
  - otherwise blank form
- **D-3311:** Never silently prefill across repos. The operator must always be able to choose **Start blank**.
- **D-3312:** Auto-carry-forward is allowed only **within the same attached repo continuity object**. Cross-object or cross-repo carry-forward must be an explicit operator action, not a default.
- **D-3313:** Phase 33 should show **what was carried forward** so the operator can sanity-check it before starting the next run.

### Reuse vs re-check

- **D-3314:** Reuse **durable identity and immutable artifacts**:
  - attached repo identity
  - managed workspace key/path
  - prior bounded request snapshots
  - prior run linkage
  - prior draft PR / delivery snapshot for context
- **D-3315:** Always re-check **mutable brownfield reality** before launching a new run:
  - managed workspace hydration
  - attach safety gate
  - operator/provider start preflight
  - current repo state assumptions that could have drifted since the last run
- **D-3316:** Ready state is **not durable memory**. Never persist or trust a previously computed “ready” result across runs without rerunning the actual checks.
- **D-3317:** Prior branch names, frozen SHAs, and old delivery snapshots are **context only**, not launch inputs for the next run.

### Prior-run context shown to the operator

- **D-3318:** Show a compact **continuity card**, not a transcript dump.
- **D-3319:** The continuity card should surface the minimum factual context needed to make the next run feel native and safe:
  - repo identity
  - workspace path
  - base branch
  - last run time and status
  - last bounded request title / kind / summary
  - last delivery result when present
  - what will be carried forward
- **D-3320:** The card should expose clear next actions with least surprise:
  - continue from carried-forward request
  - start blank for this repo
  - inspect the prior run/request if needed
- **D-3321:** Operator-facing continuity copy should stay compact, factual, and calm. It should not imply that prior checks are still valid or that the next run is “safe because it worked last time.”

### Persistence and query shape

- **D-3322:** Do **not** introduce a generic “continuity state” table for Phase 33. Reuse the lifetimes that already exist:
  - `attached_repos` for repo identity
  - `spec_drafts` for editable attached intent
  - `spec_revisions` for frozen launched request snapshots
  - `runs` for execution history
- **D-3323:** The only new persistence that is justified in this phase is explicit **repo continuity usage metadata** on attached repos, such as `last_selected_at` and `last_run_started_at`, because `updated_at` will become ambiguous.
- **D-3324:** Build continuity lists and pickers with **join-based, narrow read models** rather than preload-everything detail fetches. Use preloads for single-record detail surfaces only after the continuity target has been selected.
- **D-3325:** Keep JSON snapshots as **derived/frozen context**, not the source of truth for primary continuity identity.

### Interaction and GSD preference

- **D-3326:** Phase 33 should shift low-impact continuity choices toward **recommended defaults** rather than forcing the operator to think through every small decision.
- **D-3327:** Operator interruptions should be reserved for **impactful choices** such as repo/work-object ambiguity, obvious scope mismatch, or cases where carry-forward would be materially risky.
- **D-3328:** The continuity UX should embody the same product posture the user requested for GSD more broadly: **strong coherent defaults first, ask only when the choice materially changes outcome or risk**.

### the agent's Discretion

- Exact URL param names and route shape, as long as continuity remains route-backed and server-authoritative.
- Exact continuity card layout and copy hierarchy, as long as the factual fields above remain visible.
- Exact query/module boundaries for the continuity read model, as long as contexts own persistence/query logic and the LiveView remains a projection of server-owned state.

</decisions>

<specifics>
## Specific Ideas

- The most coherent Phase 33 shape is:
  - keep `/attach` as the single brownfield entry surface
  - add a “recent attached repos” / continuity selector backed by durable repo identity
  - let the operator choose one repo and see one compact continuity card
  - prefill from the best matching prior request on that same repo
  - rerun hydration + safety/start preflight before any new run starts

- The strongest continuity precedence is:
  - explicit draft if selected
  - otherwise latest open draft on this repo
  - otherwise latest promoted request on this repo
  - otherwise blank

- The strongest anti-footgun rule is:
  - **reuse durable identity, recheck mutable reality**

- Ecosystem lessons that informed these decisions:
  - Successful tools like **Vercel, Netlify, Railway, Render, GitHub, and Codespaces** anchor repeat work on a durable project/repo/service object, not on “continue the last chat.”
  - Strong brownfield products show **history and status near the work object** so operators can understand what is being resumed.
  - Good AI/tooling UX carries forward **summaries and artifacts**, not giant opaque transcripts.
  - The main failure pattern to avoid is stale continuity: auto-resuming the wrong context, assuming yesterday’s repo state is still valid, or hiding what was reused.

- Phoenix/Ecto conventions to preserve:
  - URL params select the continuity target
  - contexts reload authoritative state from ids
  - LiveView renders forms from `to_form/2`
  - read models use narrow joins for list surfaces and explicit preloads for detail surfaces

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth

- `.planning/ROADMAP.md` — Phase 33 goal, milestone ordering, and `CONT-01` ownership
- `.planning/REQUIREMENTS.md` — `CONT-01` wording and milestone boundaries
- `.planning/PROJECT.md` — v0.7.0 brownfield loop intent and bounded-autonomy posture
- `.planning/STATE.md` — current milestone posture

### Prior phase context and summaries

- `.planning/phases/29-attach-entry-surfaces/29-CONTEXT.md` — route-backed attach posture and single-repo boundary
- `.planning/phases/31-draft-pr-trust-ramp-and-attach-proof/31-CONTEXT.md` — attached-repo trust ramp and run-scoped draft PR contract
- `.planning/phases/32-pr-sized-attached-repo-intake/32-01-SUMMARY.md` — bounded attached request contract and durable request snapshots
- `.planning/phases/32-pr-sized-attached-repo-intake/32-02-SUMMARY.md` — explicit run foreign keys and attach-aware launch seam
- `.planning/phases/32-pr-sized-attached-repo-intake/32-03-SUMMARY.md` — `/attach` ready-state launch UX and LiveView constraints
- `.planning/phases/32-pr-sized-attached-repo-intake/32-RESEARCH.md` — research assumptions that Phase 33 now builds on

### Implementation anchors

- `lib/kiln/attach.ex` — attached repo lookup and persistence boundary
- `lib/kiln/attach/attached_repo.ex` — durable attached repo identity schema
- `lib/kiln/attach/workspace_manager.ex` — deterministic workspace reuse contract
- `lib/kiln/attach/safety_gate.ex` — mutable brownfield checks that must be rerun
- `lib/kiln/attach/intake.ex` — bounded attached request draft creation
- `lib/kiln/specs.ex` — draft promotion and request snapshot copy path
- `lib/kiln/specs/spec_draft.ex` — editable attached request state
- `lib/kiln/specs/spec_revision.ex` — immutable promoted request state
- `lib/kiln/runs.ex` — attach-aware run start and start preflight
- `lib/kiln/runs/run.ex` — durable attached run identity and delivery snapshot seam
- `lib/kiln/attach/delivery.ex` — run-scoped delivery snapshot facts
- `lib/kiln_web/live/attach_entry_live.ex` — current attach continuity limitations and future entry surface

### Testing anchors

- `test/integration/attached_repo_intake_test.exs` — repeat attached launches remain linked
- `test/kiln/runs/attached_request_start_test.exs` — attached run linkage and blocked-start behavior
- `test/kiln_web/live/attach_entry_live_test.exs` — `/attach` ready-state request flow
- `test/kiln/attach/workspace_manager_test.exs` — deterministic workspace reuse
- `test/kiln/attach/safety_gate_test.exs` — mutable-state refusal behavior

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `attached_repos` already gives Phase 33 a durable single-repo anchor with stable identity and managed workspace metadata.
- `WorkspaceManager` already provides deterministic workspace reuse, which is the right substrate for continuity.
- `spec_drafts`, `spec_revisions`, and `runs` already split editable intent, frozen launched intent, and execution history along clean lifetimes.
- `Runs.start_for_attached_request/3` already gives Phase 33 a server-owned launch seam after continuity selection is resolved.

### Established Patterns

- Kiln already prefers **server-authoritative persistence and validation** over browser-owned state.
- Attach work already uses **explicit foreign keys** for durable identity instead of hiding core linkage inside JSON.
- Mutable repo safety is already modeled as **rerunnable runtime checks**, not as cached status.
- LiveView forms already follow the right Phoenix pattern: `to_form/2` + context-owned write paths.

### Integration Points

- Phase 33 should add a **continuity read model** under existing contexts rather than making `/attach` own more state itself.
- The continuity read model should assemble:
  - current attached repo facts
  - recent attached drafts
  - recent promoted attached requests
  - recent linked runs
  - last delivery snapshot and/or post-mortem when present
- `/attach` should consume that read model via params and then still call workspace hydration, safety gate, and run-start preflight before launch.

</code_context>

<deferred>
## Deferred Ideas

- Broader brownfield conflict and overlap analysis — Phase 34
- PR handoff tightening, proof citations, and review packaging — Phase 35
- Cross-repo continuity or multi-root attach flows
- Transcript-first or chat-first resume semantics
- Browser-local recents as the system of record
- Generic continuity-state table that duplicates existing draft/revision/run lifetimes

</deferred>

---

*Phase: 33-repeat-run-continuity-on-attached-repos*
*Context gathered: 2026-04-24*
