# Phase 34: Brownfield preflight and narrowing guardrails - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Detect likely repo-state conflicts or scope collisions before coding begins on an attached repo, then give the operator explicit remediation or narrowing guidance that keeps the run inside one conservative PR-sized lane.

This phase extends the brownfield trust posture from Phases 30-33. It is about pre-coding safety, conflict detection, and narrowing guidance on `/attach`. It is not about draft PR handoff polish, approval gates, multi-repo behavior, or semantic AI-driven overlap analysis.

</domain>

<decisions>
## Implementation Decisions

### Preflight architecture
- **D-3401:** Keep `Kiln.Attach.SafetyGate` as the deterministic hard mutation gate for repo/workspace/runtime facts. Do not overload it with fuzzy overlap heuristics.
- **D-3402:** Add a sibling brownfield preflight boundary under the attach context that evaluates repo-state conflicts, overlap signals, and narrowing guidance after hard safety checks pass.
- **D-3403:** Model Phase 34 as a layered system:
  - hard gate answers "is this repo/workspace safe to touch at all?"
  - brownfield advisory preflight answers "is this request likely to collide, drift, or surprise the operator?"
- **D-3404:** Do not persist a durable "safe" or "ready" verdict on `attached_repos`. Recompute mutable reality on every launch, consistent with Phase 33.

### Conflict coverage
- **D-3405:** Phase 34 coverage should distinguish deterministic repo facts from heuristic collision signals. Git facts may block; heuristic findings should warn unless they clearly change the outcome.
- **D-3406:** Hard blockers remain for conditions that would make later branch/PR work unsafe or ambiguous:
  - dirty source repo or managed workspace
  - detached HEAD or no clear base branch
  - missing/non-GitHub remote needed for later delivery
  - missing `gh` auth or equivalent prerequisite for push/PR operations
  - exact same-lane ambiguity, such as continuity mismatch or an already-open Kiln PR for the same branch/run lane
- **D-3407:** Initial warning coverage should stay narrow and legible:
  - overlapping open PRs against the same repo/base branch
  - recent unmerged Kiln run on the same repo/base branch
  - likely same-scope request overlap against open attached drafts or recent promoted attached requests
  - request breadth that looks larger than one conservative PR-sized lane
- **D-3408:** Do not introduce deep predictive or LLM-based collision analysis in Phase 34. The system should stay explainable and conservative.

### Outcome policy
- **D-3409:** Replace the binary mental model with a typed preflight report that supports `:fatal`, `:warning`, and `:info` findings while preserving tuple-level blocking for truly unsafe conditions.
- **D-3410:** The operator interruption rule is:
  - block only when Kiln would otherwise mutate the wrong thing, mutate from an unsafe state, or create a misleading delivery path
  - warn when the run is still possible but confidence, scope, or trust posture is degraded unless the request is narrowed
  - show info when context is useful but no action is required
- **D-3411:** Do not use score-first or confidence-number-first UX in Phase 34. Prefer typed finding codes, clear severity, visible evidence, and concrete next actions.
- **D-3412:** Heuristic overlap findings must not become autonomous hard refusals in this phase unless backed by deterministic evidence.

### Scope-collision heuristic
- **D-3413:** Scope-collision detection stays same-repo only. Never infer overlap across repositories, workspaces, or browser-local state.
- **D-3414:** The candidate pool for overlap checks should be limited to:
  - open attached-intake drafts
  - recent promoted attached requests
  - recent same-repo runs, with extra weight for active or non-terminal runs
  - delivery snapshots when they show an in-flight branch/PR on the same repo/base branch
- **D-3415:** Use a conservative heuristic stack:
  - normalize title, summary, acceptance criteria, and out-of-scope text server-side
  - compare against same-repo recent work objects
  - boost concern when the matching work object is still open, active, or already has a frozen delivery branch/PR
- **D-3416:** Emit two heuristic classes only:
  - `:possible_duplicate` for strong evidence
  - `:possible_overlap` for moderate evidence
- **D-3417:** Do not claim semantic certainty. Use language like "may overlap" and "likely similar scope", not "is duplicate", unless the evidence is materially stronger than lexical similarity.

### Narrowing guidance UX
- **D-3418:** Add a dedicated non-fatal narrowing guidance state on `/attach` rather than overloading the blocked state or hiding guidance in a small inline flash.
- **D-3419:** The narrowing state should say plainly:
  - the repo is attachable
  - the request is too wide or collision-prone as written
  - Kiln is recommending a narrower default before coding starts
- **D-3420:** The primary UX should be default-forward:
  - primary CTA: accept Kiln's suggested narrower request
  - secondary CTA: edit the request manually
  - optional inspect action: view the prior draft/run/PR that triggered the warning
- **D-3421:** Keep the visual semantics separate:
  - blocked = unsafe to proceed
  - warning/narrowing = safe to proceed, but not recommended as currently framed
  - info = context only
- **D-3422:** Show the evidence behind each finding near the repo/request object:
  - repo
  - base branch
  - current branch when relevant
  - prior draft/run/PR identity
  - plain-English why and next action

### Architecture and implementation posture
- **D-3423:** Keep the LiveView thin and server-authoritative. `/attach` should render a preflight report, not compute heuristics in the UI.
- **D-3424:** Keep durable truth relational and explicit through existing ids (`attached_repo_id`, `spec_id`, `spec_revision_id`, `run_id`). Do not create a generic JSON preflight-state bucket as the primary system of record.
- **D-3425:** Build the advisory layer as a read model plus heuristic evaluator under the attach context. Fetch bounded same-repo candidate sets with Ecto, then score them in Elixir for explainability and testability.
- **D-3426:** Preserve the current product preference across this phase and, where possible, broader GSD behavior: choose strong defaults automatically and interrupt only for materially risky or outcome-changing choices.

### the agent's Discretion
- Exact module names and report struct names, as long as the hard-gate vs advisory-preflight split remains explicit.
- Exact wording of warning copy, as long as it stays calm, factual, and default-forward.
- Exact normalization/tokenization details for overlap heuristics, as long as the implementation remains same-repo, bounded, and conservative.
- Exact DOM layout for the narrowing panel, as long as blocked vs warning semantics remain visually and behaviorally distinct.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth
- `.planning/ROADMAP.md` — Phase 34 goal, dependency on Phase 33, and milestone ordering
- `.planning/REQUIREMENTS.md` — `SAFE-01` and `SAFE-02` wording plus milestone traceability
- `.planning/PROJECT.md` — v0.7.0 brownfield loop intent, bounded-autonomy posture, and current product goals
- `.planning/STATE.md` — current milestone posture and immediate next-phase context

### Prior phase constraints
- `.planning/phases/29-attach-entry-surfaces/29-CONTEXT.md` — route-backed attach posture and honest brownfield framing
- `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-RESEARCH.md` — original safety-gate boundary and typed remediation vocabulary
- `.planning/phases/31-draft-pr-trust-ramp-and-attach-proof/31-CONTEXT.md` — draft-PR-first trust ramp and exact branch/PR delivery contract
- `.planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md` — reuse durable identity, recheck mutable reality, and continuity carry-forward rules

### Implementation anchors
- `lib/kiln/attach.ex` — public attach boundary and refresh/preflight seam
- `lib/kiln/attach/safety_gate.ex` — current deterministic hard-stop gate
- `lib/kiln/attach/continuity.ex` — same-repo continuity read model and prior work objects
- `lib/kiln/attach/attached_repo.ex` — durable attached repo identity and workspace metadata
- `lib/kiln/attach/delivery.ex` — frozen delivery snapshot facts that can inform overlap warnings
- `lib/kiln/attach/source.ex` — resolved source identity shape
- `lib/kiln/attach/workspace_manager.ex` — workspace hydration and base-branch derivation
- `lib/kiln/runs.ex` — attached request start seams and typed blocked-start patterns
- `lib/kiln/runs/run.ex` — `attached_repo_id` linkage and `github_delivery_snapshot`
- `lib/kiln_web/live/attach_entry_live.ex` — current ready/blocked/continuity UI states on `/attach`
- `lib/kiln/operator_setup.ex` — readiness checklist and remediation vocabulary

### Testing anchors
- `test/kiln/attach/safety_gate_test.exs` — deterministic preflight coverage precedent
- `test/kiln/attach/continuity_test.exs` — same-repo continuity read-model expectations
- `test/kiln/runs/attached_continuity_test.exs` — repeat-run continuity behavior
- `test/kiln/runs/attached_request_start_test.exs` — attached request launch and blocked-start patterns
- `test/kiln_web/live/attach_entry_live_test.exs` — attach UI state and stable-id regression coverage

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Kiln.Attach.SafetyGate`: already provides deterministic git/gh readiness checks and typed blocker maps.
- `Kiln.Attach.Continuity`: already gives the same-repo recent-history corpus needed for overlap warnings without inventing new persistence.
- `github_delivery_snapshot` on `Kiln.Runs.Run`: already captures frozen branch/base/PR facts that can strengthen overlap evidence.
- `Kiln.OperatorSetup`: already establishes the remediation tone and exact-next-step vocabulary for blocked states.
- `AttachEntryLive`: already has explicit state-driven rendering and stable ids, which makes an added warning/narrowing branch a natural extension.

### Established Patterns
- The codebase prefers route-backed, server-authoritative LiveView flows over client-owned state.
- Hard command outcomes use tagged tuples and typed maps; this phase should preserve that style.
- Durable identity is explicit and relational (`attached_repo_id`, `spec_id`, `spec_revision_id`, `run_id`) rather than hidden in opaque blobs.
- Mutable repo reality is already understood as rerunnable runtime truth, not cached continuity state.

### Integration Points
- Phase 34 should hang off the existing attach refresh/preflight flow in `Kiln.Attach`, not create a parallel attach start system.
- The advisory preflight should consume same-repo candidates from `Specs`, `Runs`, and continuity/delivery facts, then hand a report to `/attach`.
- `/attach` should surface warnings and narrowing guidance before `Runs.start_for_attached_request/3`, while keeping the primary path obvious when continuation is still safe.

</code_context>

<specifics>
## Specific Ideas

- The coherent architecture is:
  - deterministic hard gate first
  - advisory brownfield preflight second
  - request narrowing UX third
  - run start only after the operator sees the resulting report

- The most important product posture for this phase is:
  - be factual
  - be conservative
  - default strongly
  - interrupt only when the outcome would materially change or the repo would become unsafe

- Lessons carried forward from adjacent tools:
  - GitHub treats base branch and PR comparison as explicit, meaningful facts rather than hidden inference.
  - Dependabot and Renovate are good models for limiting ambiguous in-flight work and avoiding parallel overlapping PR noise.
  - Netlify and Vercel keep import/connect flows explicit and durable-object-centered rather than chat-memory-centered.
  - Narrowing guidance should feel like a recommendation from a careful operator tool, not a vague AI confidence score.

- Broader preference from this discussion:
  - shift low-impact choice handling left within GSD where possible
  - reserve explicit operator interruptions for impactful trust, scope, or safety decisions

</specifics>

<deferred>
## Deferred Ideas

- Deep semantic or LLM-based overlap prediction across request text, diffs, and file touch sets
- Cross-repo or multi-root collision analysis
- Approval-gate UX or human-in-the-loop acceptance screens
- Draft PR handoff polish, proof citations, and review packaging — Phase 35
- Broader GSD-wide interaction-default tuning beyond the brownfield attach path

</deferred>

---

*Phase: 34-brownfield-preflight-and-narrowing-guardrails*
*Context gathered: 2026-04-24*
