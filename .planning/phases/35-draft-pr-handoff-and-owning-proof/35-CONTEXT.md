# Phase 35: Draft PR handoff and owning proof - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Tighten the attached-repo draft PR output so the operator receives a reviewable handoff with a scoped summary, concrete proof citations, and milestone-owning verification coverage.

This phase refines the existing attached-repo delivery contract. It does not add new attach source types, new approval gates, richer run-dashboard products, or a second proof-command family.

</domain>

<decisions>
## Implementation Decisions

### Carry-forward constraints
- **D-3501:** Preserve the Phase 31 trust posture: attached-repo delivery stays draft-first, factual, compact, and human-reviewable rather than bot-noisy or approval-gated.
- **D-3502:** Preserve the Phase 33 and Phase 34 boundary split: the PR handoff packages the final scoped result and proof surface; it does not replay broad continuity state or dump advisory preflight logs into the PR body.
- **D-3503:** Carry forward the user preference to shift low-impact defaults left inside GSD and Kiln where possible. Interruptions should remain reserved for materially outcome-changing trust, scope, or safety choices.

### Verification citations
- **D-3504:** The PR `Verification` section must cite the owning proof command `MIX_ENV=test mix kiln.attach.prove`.
- **D-3505:** The PR `Verification` section must also cite the exact locked proof layers that the owning command runs, rather than relying on generic assurance prose alone.
- **D-3506:** Phase 35 should keep the cited proof layers explicit and reviewable. The current locked set is:
  - `test/integration/github_delivery_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs`
- **D-3507:** Do not use generic claims like “workspace was marked ready before delivery” as the only verification language. Evidence must be concrete enough that a reviewer can rerun or inspect it without reverse-engineering intent.
- **D-3508:** Do not introduce artifact-linked or run-linked proof citations as the primary PR-body proof mechanism in this phase. Richer run/check URLs can be a future capability, but they are not required for the Phase 35 handoff contract.

### PR body framing
- **D-3509:** The draft PR body should render a compact human-first `Summary` section derived from the bounded attached request, not a generic attached-repo update placeholder.
- **D-3510:** The PR body should render `Acceptance criteria` from the stored attached request so the reviewer can see the bounded done-definition without inferring it from the diff.
- **D-3511:** The PR body should render `Out of scope` only when the stored list is non-empty and materially clarifies the lane boundary.
- **D-3512:** Do not paste the full attached request markdown body or a raw metadata dump into the PR. The visible PR body must stay reviewable as a normal feature or bugfix handoff.
- **D-3513:** Keep `Out of scope` conditional. Never render empty or boilerplate boundary sections just to satisfy template shape.

### Repo-fitting context
- **D-3514:** Keep the PR human-first and compact: include the scoped request framing, verification citations, and the repo facts a reviewer actually uses.
- **D-3515:** Include `branch` and `base branch` facts in the body because they are immediately useful review context for attached brownfield work.
- **D-3516:** Keep exactly one lightweight Kiln provenance marker. The preferred marker is the existing `kiln-run: <run_id>` footer.
- **D-3517:** Do not expose `attached_repo_id` as a naked internal identifier in the PR body. If Phase 35 later gains a meaningful operator-facing link target, it may replace or supplement raw IDs, but raw internal IDs should not ship in the visible PR text.
- **D-3518:** Do not add a dedicated warning/preflight section to the PR body. Advisory findings from Phase 34 may appear only when they materially explain why the final shipped scope was narrowed or when they link to a concrete related prior draft, run, or PR.
- **D-3519:** Do not emit rich machine metadata blobs, JSON, YAML, or duplicate run-context blocks in the PR body.

### Owning proof contract
- **D-3520:** Keep `mix kiln.attach.prove` as the sole owning proof command for attached-repo draft-PR handoff.
- **D-3521:** Extend the existing owning command only with the minimum additional locked proof layer or layers needed to close `TRUST-04` and `UAT-06`.
- **D-3522:** Do not create a new Phase-35-specific proof command or force operators to orchestrate multiple direct test invocations themselves.
- **D-3523:** The owning command remains the source of truth. Phase artifacts may cite or summarize its delegated proof layers, but docs must not become the orchestration layer.
- **D-3524:** Keep the proof command narrow to the attached draft-PR handoff claim. Do not silently widen it into repo-wide gates like `mix precommit`, `just shift-left`, or broad `mix test`.

### the agent's Discretion
- Exact PR section headings and sentence wording, as long as the body remains compact, factual, and human-first.
- Exact formatting of verification bullet points, as long as the owning proof command and delegated proof layers remain visible.
- Exact body placement of branch/base facts and the provenance marker, as long as duplication stays low and review ergonomics stay high.
- Exact threshold for rendering `Out of scope`, as long as empty or low-value sections are omitted by default.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth
- `.planning/ROADMAP.md` — Phase 35 goal, dependency on Phase 34, and milestone ordering
- `.planning/REQUIREMENTS.md` — `TRUST-04` and `UAT-06` wording plus milestone traceability
- `.planning/PROJECT.md` — bounded-autonomy posture, brownfield trust-ramp goal, and default-forward product direction
- `.planning/STATE.md` — current milestone posture

### Prior phase constraints
- `.planning/phases/31-draft-pr-trust-ramp-and-attach-proof/31-CONTEXT.md` — draft-first trust posture, compact PR sections, and one-lightweight-marker rule
- `.planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md` — carry-forward request fields and reuse-vs-recheck boundary
- `.planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md` — warning vs blocked semantics and narrowing guidance boundary

### Implementation anchors
- `lib/kiln/attach/delivery.ex` — current branch/title/body generation and frozen draft PR snapshot seam
- `lib/mix/tasks/kiln.attach.prove.ex` — owning proof command and delegated proof-layer contract
- `lib/kiln/attach/intake.ex` — structured attached-request markdown/body generation and durable request fields
- `lib/kiln/specs/spec_draft.ex` — durable attached request draft fields
- `lib/kiln/specs/spec_revision.ex` — durable promoted attached request fields
- `lib/kiln/github/open_pr_worker.ex` — draft PR worker boundary and frozen PR attrs
- `lib/kiln_web/live/attach_entry_live.ex` — current attach-side warning and narrowing UX that Phase 35 must not duplicate into PR noise

### Testing anchors
- `test/integration/github_delivery_test.exs` — hermetic attached-repo branch, push, and draft PR delivery proof
- `test/kiln/attach/safety_gate_test.exs` — refusal-path and readiness boundary proof
- `test/kiln_web/live/attach_entry_live_test.exs` — focused attach truth-surface and warning/narrowing UX proof
- `test/mix/tasks/kiln.attach.prove_test.exs` — owning proof-command precedent and lock point

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Kiln.Attach.Delivery`: already owns branch/title/body freezing and is the correct place to tighten PR handoff content.
- `Mix.Tasks.Kiln.Attach.Prove`: already gives the repo one attached-repo proof command; Phase 35 should extend this seam rather than adding a sibling command.
- `SpecDraft` and `SpecRevision`: already persist `request_kind`, `change_summary`, `acceptance_criteria`, and `out_of_scope`, which are the right inputs for bounded PR framing.
- `AttachEntryLive` and Phase 34 preflight work: already own warning and narrowing UX, which means the PR body can stay compact instead of replaying preflight.

### Established Patterns
- Kiln prefers thin public boundaries, durable stored facts, and explicit proof seams over ad hoc UI or shell orchestration.
- The codebase already favors one owning proof command over scattered test commands when a milestone needs a product-facing verification path.
- Brownfield trust posture in Kiln is conservative and draft-first, but not approval-gated or reassurance-heavy.

### Integration Points
- PR body generation should pull directly from durable attached-request fields instead of reusing raw intake markdown.
- Verification copy should stay aligned with the delegated proof layers in `Mix.Tasks.Kiln.Attach.Prove`.
- Any new proof layer added for `TRUST-04` or `UAT-06` should flow through `mix kiln.attach.prove`, then be cited consistently in the PR body and phase verification artifacts.

</code_context>

<specifics>
## Specific Ideas

- The most coherent PR body shape is:
  - `Summary`
  - `Acceptance criteria`
  - conditional `Out of scope`
  - `Verification`
  - compact branch/base review facts
  - one `kiln-run:` provenance footer

- The most coherent proof posture is:
  - one obvious command
  - exact delegated proof-layer citations
  - no generic “trust us” verification prose
  - no stale run-artifact or metadata dumps

- The most coherent product posture is:
  - default-forward
  - compact
  - reviewable by a normal GitHub reviewer
  - explicit enough to be auditable without becoming a bot wall

- Ecosystem lessons carried forward:
  - strong PR automation tools keep the PR body human-scannable and let deeper evidence live in canonical proof surfaces
  - noisy template dumps and raw metadata blobs train reviewers to ignore the PR body
  - one obvious proof command is better DX than multiple shell snippets or phase-local wrapper commands

</specifics>

<deferred>
## Deferred Ideas

- Rich artifact-linked or run-linked verification references in the PR body
- A separate Phase-35-specific proof command
- Full attached request markdown dumps in the visible PR body
- Rich machine metadata sections or structured blobs in PR text
- Dedicated PR-body replay of Phase 34 warning or narrowing findings

</deferred>

---

*Phase: 35-draft-pr-handoff-and-owning-proof*
*Context gathered: 2026-04-24*
