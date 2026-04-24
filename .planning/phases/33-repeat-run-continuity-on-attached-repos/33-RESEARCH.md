# Phase 33: Repeat-run continuity on attached repos - Research

**Researched:** 2026-04-24  
**Domain:** Attached-repo continuity, repeat-run reuse, and route-backed brownfield resume flows  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Continuity is anchored to a durable attached repo plus an existing durable work object, not browser state or transcript memory.
- `/attach` stays the primary brownfield entry surface; continuity should be route-backed and server-authoritative.
- URL params may select continuity targets, but all meaningful state must reload from server-owned ids.
- Continuity reuses durable identity and immutable artifacts, then re-runs mutable readiness checks before launch.
- Carry-forward is same-repo only, visible to the operator, and always escapable via a blank-start path.
- Phase 33 should not introduce a generic continuity-state table; it should reuse `attached_repos`, `spec_drafts`, `spec_revisions`, and `runs`.
- Low-impact continuity choices should default coherently; interruption is reserved for ambiguity or material risk.

### Deferred Scope

- Cross-repo or multi-root continuity
- Transcript-first resume semantics
- Broader repo-state conflict detection and narrowing guidance
- Draft-PR handoff tightening
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONT-01 | Repeat runs on the same attached repo reuse known repo/workspace context and prior trust/setup facts so the operator does not have to rediscover the attach flow each time. | Add a repo-centric continuity read model, route-backed continuity selection on `/attach`, and repeat-run launch wiring that reuses durable repo/request/run identity while re-running hydration, safety, and operator preflight before launch. |
</phase_requirements>

## Summary

Phase 32 established the durable primitives that Phase 33 needs: attached repos persist stable repo/workspace identity, attached request drafts and promoted revisions persist bounded authorial intent, and runs now carry explicit `attached_repo_id`, `spec_id`, and `spec_revision_id` relations. The remaining gap is continuity assembly and presentation. Right now `/attach` still behaves like a first-run surface: it resolves one source, hydrates one workspace, persists one repo row, and only then shows a bounded request form. Nothing in the route, UI, or domain layer helps the second or third run start from “the repo Kiln already knows.” [VERIFIED: codebase read]

The strongest Phase 33 shape is a three-part contract. First, add a narrow continuity read model that can answer: “what is the best continuity target for this attached repo, what request should prefill, and what factual context should the operator see?” Second, make `/attach` continuity route-backed with `handle_params/3` and explicit ids so the operator can land directly on one known attached repo and inspect a compact continuity card. Third, keep launches safe by reusing durable identity but re-running hydration, safety gate, and operator preflight before starting the next run; continuity should reduce rediscovery, not bypass mutable checks. [VERIFIED: codebase read]

**Primary recommendation:** split Phase 33 into three plans: (1) attach-context continuity read models and metadata, (2) `/attach` recent-repo and continuity-card UX with route params and visible carry-forward, and (3) repeat-run launch/preflight orchestration that turns a selected continuity target into a safe next run without trusting stale ready state. [VERIFIED: codebase read]

## Project Constraints

- Reuse existing contexts and persistence seams; do not add a new continuity system-of-record.
- Keep LiveView thin: route params select ids, contexts reload facts, and forms stay `to_form/2`-driven.
- Keep mutable brownfield checks in the existing attach and run-start boundaries instead of caching “ready” across runs.
- Preserve the single-repo boundary introduced in Phases 29-32.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Recent attached repo selection | API / Backend | Frontend Server (SSR) | The list and selected repo facts should come from `attached_repos` plus joined brownfield context, not browser memory. |
| Carry-forward precedence | API / Backend | Database / Storage | Draft/revision/run ordering is a domain rule that should live in one query boundary. |
| Continuity card rendering | Frontend Server (SSR) | API / Backend | `/attach` should render the card, but it should consume already-shaped continuity facts. |
| Repeat-run readiness refresh | API / Backend | Database / Storage | Hydration, safety gate, and start preflight are mutable checks with existing backend owners. |
| Continuity usage metadata | Database / Storage | API / Backend | `last_selected_at` and `last_run_started_at` belong on `attached_repos` and help deterministic “recent repos” ordering. |

## Standard Stack

No new Hex or JS packages are recommended for Phase 33. Reuse Phoenix LiveView, Ecto joins/preloads, the existing `Kiln.Attach` boundary, `Kiln.Specs`, and `Kiln.Runs`.

## Existing-Code Findings

### What already exists

- `Kiln.Attach.AttachedRepo` persists durable repo identity and workspace facts, but it has no explicit continuity usage metadata yet. [VERIFIED: `lib/kiln/attach/attached_repo.ex`]
- `Kiln.Attach` can fetch one attached repo by id or workspace key, but it does not expose list/recent/detail continuity queries. [VERIFIED: `lib/kiln/attach.ex`]
- `Kiln.Specs` persists mutable `spec_drafts` and immutable `spec_revisions`, and promotion already copies attached-request fields onto revisions. [VERIFIED: `lib/kiln/specs.ex`]
- `Kiln.Runs` persists explicit links to attached repo, spec, and revision, but it does not yet offer continuity-friendly history queries or continuity-aware start helpers. [VERIFIED: `lib/kiln/runs.ex`]
- `KilnWeb.AttachEntryLive` has no `handle_params/3`, no continuity selector, no recent repos list, and no ability to restore prior same-repo request context from URL-backed ids. [VERIFIED: `lib/kiln_web/live/attach_entry_live.ex`]

### Why this matters

- The route layer cannot currently say “show me repo X with its best continuity target.”
- The operator must rediscover the repo source even after Kiln already owns a durable attached repo row.
- The current ready-state flow risks conflating “known repo” with “freshly checked repo”; continuity needs those concepts separated.

## Recommended Patterns

### Pattern 1: Repo-centric continuity read model with same-repo precedence

**What:** Add one backend query surface that, given an attached repo id, returns repo facts, recent work objects, a chosen continuity target, and one prefill payload following the explicit precedence from the phase context.

**Why:** The precedence rules should not be reimplemented in LiveView or split across ad hoc Repo queries.

**Use when:** `/attach` needs to render one selected repo, one continuity card, one “carried forward from” fact block, and one prefilled request form.

### Pattern 2: Route-backed continuity on `/attach`

**What:** Use `/attach` query params plus `handle_params/3` and `push_patch/2` to select recent repo ids and optional draft/run ids.

**Why:** This preserves the single-surface product shape while making continuity deep-linkable, server-authoritative, and testable.

**Use when:** The operator chooses a recent attached repo, clicks “continue,” or explicitly starts blank.

### Pattern 3: Reuse durable identity, re-check mutable reality

**What:** Reuse repo identity, workspace path, request snapshots, and run links, but always re-run workspace hydration, attach safety gate, and operator/provider start preflight before the next run begins.

**Why:** Continuity should remove rediscovery cost without creating stale brownfield trust.

**Use when:** Starting a run from a continuity-selected repo or prefilled prior request.

## Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repo-centric continuity anchored on `attached_repos` + existing work objects | Resume the “last chat/session” | Reject. The codebase persists repo, draft, revision, and run identity explicitly; transcript-driven continuity would be weaker and harder to reason about. |
| Route params on `/attach` | Browser-local recents or hidden LiveView assigns | Reject. That would weaken shareability, reload behavior, and server authority. |
| Add `last_selected_at` / `last_run_started_at` to `attached_repos` | Reuse `updated_at` for “recent” ordering | Reject. `updated_at` is already overloaded by persistence updates and does not cleanly represent continuity usage. |
| Re-run hydration + safety + preflight at launch time | Trust a persisted ready state from the previous run | Reject. Readiness is mutable and explicitly non-durable per the phase context. |

## Recommended Project Structure

```text
lib/
├── kiln/
│   ├── attach.ex
│   ├── attach/
│   │   ├── attached_repo.ex
│   │   ├── continuity.ex        # New continuity read model / selection logic
│   │   └── workspace_manager.ex
│   ├── runs.ex
│   └── specs.ex
└── kiln_web/live/
    └── attach_entry_live.ex

test/
├── kiln/
│   ├── attach/
│   │   └── continuity_test.exs
│   └── runs/
│       └── attached_continuity_test.exs
└── kiln_web/live/
    └── attach_entry_live_test.exs
```

## Plan Split Recommendation

### Plan 33-01

- Add continuity metadata and read models over attached repos, drafts, revisions, and runs.
- Return recent repos, selected continuity targets, and carry-forward payloads through one backend boundary.

### Plan 33-02

- Make `/attach` continuity route-backed.
- Add recent attached repos, continuity card, explicit carry-forward visibility, and start-blank behavior.

### Plan 33-03

- Rewire repeat-run submit/start through continuity-aware selection and fresh readiness checks.
- Record continuity usage timestamps and prove same-repo repeat-run behavior through focused tests.

## Risks To Control

- Showing stale readiness as if it were still valid
- Prefilling from the wrong repo or wrong work object
- Re-implementing continuity precedence in LiveView instead of a domain query
- Letting “recent repo” ordering drift by overloading `updated_at`
- Quietly widening into Phase 34 preflight analysis or Phase 35 PR handoff work

## Conclusion

Phase 33 is not a schema-reset phase. The repo already has the right durable lifetimes; it needs a continuity read model, a route-backed `/attach` continuity UX, and a repeat-run start path that reuses durable context while re-checking mutable reality. That is enough to satisfy `CONT-01` cleanly without bleeding into guardrails or PR handoff work.
