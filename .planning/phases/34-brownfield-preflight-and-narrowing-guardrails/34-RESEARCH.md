# Phase 34: Brownfield preflight and narrowing guardrails - Research

**Researched:** 2026-04-24
**Domain:** Brownfield attach preflight, typed advisory findings, same-repo overlap heuristics, and narrowing UX
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas
- Deep semantic or LLM-based overlap prediction across request text, diffs, and file touch sets
- Cross-repo or multi-root collision analysis
- Approval-gate UX or human-in-the-loop acceptance screens
- Draft PR handoff polish, proof citations, and review packaging — Phase 35
- Broader GSD-wide interaction-default tuning beyond the brownfield attach path
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFE-01 | Before coding starts, Kiln detects and surfaces unsafe or conflicting brownfield conditions such as dirty repo state, unclear target/base branch, overlapping open PRs, or likely scope collisions. [VERIFIED: .planning/REQUIREMENTS.md] | Add a typed brownfield preflight report after `Kiln.Attach.SafetyGate.evaluate/3`, combining live repo facts, same-repo candidate reads, and GitHub PR overlap checks before `Runs.start_for_attached_request/3`. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [VERIFIED: gh pr list --help] |
| SAFE-02 | When brownfield preflight finds a non-fatal issue, Kiln provides explicit remediation or narrowing guidance so the operator can re-scope the run without guessing. [VERIFIED: .planning/REQUIREMENTS.md] | Render a dedicated narrowing state on `/attach` that shows evidence, next actions, a suggested narrower request, and an inspect path to the prior same-repo object that triggered the warning. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Run `just precommit` or `bash script/precommit.sh` when changes are complete; use `just shift-left` or `mix shift_left.verify` before `/gsd-plan-phase N --gaps`. [VERIFIED: CLAUDE.md]
- Use the existing `Req` client for HTTP work; do not introduce `:httpoison`, `:tesla`, or `:httpc`. [VERIFIED: CLAUDE.md]
- Keep LiveView templates wrapped in `<Layouts.app ...>` and pass `current_scope`; do not call `<.flash_group>` outside `layouts.ex`. [VERIFIED: CLAUDE.md]
- Use imported `<.icon>` and `<.input>` components where applicable; if custom classes replace defaults on `<.input>`, fully style the field. [VERIFIED: CLAUDE.md]
- Keep JS/CSS within `app.js` and `app.css`; do not add inline `<script>` tags in HEEx. [VERIFIED: CLAUDE.md]
- LiveViews should stay route-backed and server-authoritative; use `push_patch` / `push_navigate`, not deprecated redirect helpers. [VERIFIED: CLAUDE.md]
- Forms must use `to_form/2`, `<.form for={@form}>`, explicit DOM ids, and `@form[:field]`; do not access changesets directly in templates. [VERIFIED: CLAUDE.md]
- Prefer LiveView streams for large collections; do not use deprecated `phx-update=\"append\"` or `phx-update=\"prepend\"`. [VERIFIED: CLAUDE.md]
- Tests should use `Phoenix.LiveViewTest`, stable element ids, `has_element?/2`, and `start_supervised!/1`; avoid sleeping-based synchronization. [VERIFIED: CLAUDE.md]
- Preserve the existing single-module-per-file, Ecto preload, and safe-Elixir rules in the phase plan. [VERIFIED: CLAUDE.md]

## Summary

`Kiln.Attach.SafetyGate` currently owns only deterministic hard-stop checks and returns either `{:ok, ready}` or `{:blocked, blocked}`; it does not model warning or info findings. [VERIFIED: lib/kiln/attach/safety_gate.ex] `KilnWeb.AttachEntryLive` mirrors that binary posture with `:ready`, `:continuity`, and `:blocked` UI branches, then starts runs through `Runs.start_for_attached_request/3` after optional continuity refresh. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

Phase 33 already created the inputs that Phase 34 should reuse instead of replacing: `attached_repos` persists repo/workspace identity plus continuity timestamps, `Continuity` returns same-repo prior request/run context, `Runs` can list recent same-repo runs with spec preloads, and `github_delivery_snapshot` freezes branch/base facts per run. [VERIFIED: lib/kiln/attach/attached_repo.ex] [VERIFIED: lib/kiln/attach/continuity.ex] [VERIFIED: lib/kiln/runs.ex] [VERIFIED: lib/kiln/runs/run.ex] That means Phase 34 can stay inside `SAFE-01` and `SAFE-02` by adding one attach-side advisory preflight layer rather than widening persistence or delivery scope. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**Primary recommendation:** add a sibling `Kiln.Attach` brownfield preflight boundary that runs after `SafetyGate` succeeds, produces a typed report of `:fatal`, `:warning`, and `:info` findings, queries only same-repo candidates, and feeds a dedicated narrowing UI state on `/attach` before run start. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dirty repo / detached head / GitHub auth checks | API / Backend | Database / Storage | These checks already live in `Kiln.Attach.SafetyGate` and depend on live git and `gh` probes, not browser state. [VERIFIED: lib/kiln/attach/safety_gate.ex] |
| Same-repo overlap candidate collection | API / Backend | Database / Storage | Candidate objects come from `spec_drafts`, `spec_revisions`, `runs`, and `attached_repos` joins. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] [VERIFIED: lib/kiln/attach/continuity.ex] |
| Open PR lane conflict lookup | API / Backend | External GitHub CLI | The repo already depends on authenticated `gh` access, and `gh pr list` supports `--base`, `--head`, `--state`, and JSON output for repo-scoped overlap checks. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: gh pr list --help] |
| Typed preflight report assembly | API / Backend | — | Severity, evidence, and narrowing suggestions should be computed once on the server so `/attach` stays a projection. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| Narrowing / warning rendering | Frontend Server (SSR) | API / Backend | `AttachEntryLive` already owns state-driven rendering and request-form lifecycle, so it should render the report rather than recompute it. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | `~> 1.1.28` [VERIFIED: mix.exs] | Route-backed `/attach` flow and warning/narrowing UI. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] | Already installed and used for the attach surface; Phase 34 is a state extension, not a UI-stack change. [VERIFIED: mix.exs] [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |
| Ecto | repo current [VERIFIED: .planning/PROJECT.md] | Same-repo candidate reads over drafts, revisions, runs, and attached repos. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] | Existing relational ids already model the needed brownfield objects. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| GitHub CLI (`gh`) | `2.89.0` [VERIFIED: gh --version] | Live open-PR overlap checks and auth preconditions. [VERIFIED: gh pr list --help] | Already required by attach safety and present on this machine. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: gh auth status] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | bundled [VERIFIED: mix.exs] | Domain and context tests for typed findings and candidate selection. [VERIFIED: test/test_helper.exs] | Use for `Kiln.Attach` and `Kiln.Runs` query/report behavior. [VERIFIED: test/kiln/attach/safety_gate_test.exs] |
| Phoenix.LiveViewTest + LazyHTML | installed [VERIFIED: mix.exs] | UI proof for `/attach` blocked vs warning vs narrowing states with stable ids. [VERIFIED: test/kiln_web/live/attach_entry_live_test.exs] | Use for operator-facing narrowing guidance and start-path regressions. [VERIFIED: test/kiln_web/live/attach_entry_live_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Attach-side advisory preflight report | Add more fuzzy checks directly into `SafetyGate` | Reject; Phase context explicitly keeps `SafetyGate` deterministic and separate from heuristic overlap logic. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| Same-repo relational candidate reads | Persist a generic JSON preflight cache on `attached_repos` | Reject; mutable reality must be recomputed and durable truth should stay relational. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| Repo-scoped `gh pr list` query | Cross-repo or semantic LLM collision analysis | Reject for Phase 34; cross-repo and deep semantic overlap are explicitly deferred. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |

**Installation:**
```bash
# No new dependencies.
```
[VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

The current and recommended data flow is below. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [VERIFIED: lib/kiln/attach.ex]

```text
/attach request form
  -> AttachEntryLive.handle_event("submit_request")
    -> maybe_refresh_attached_repo/2 (continuity path only)
      -> Attach.refresh_attached_repo/2
        -> SafetyGate.evaluate/3
    -> BrownfieldPreflight.evaluate/3
      -> collect same-repo candidates
        -> Specs open drafts
        -> Specs promoted requests
        -> Runs recent same-repo runs
        -> run delivery snapshots
        -> gh pr list --repo slug --base base --state open
      -> emit typed findings
        -> fatal => refuse launch, show evidence + remediation
        -> warning => show narrowing state + suggested narrower request
        -> info => show context only
    -> Runs.preflight_attached_request_start/0
    -> Intake.create_draft/2
    -> Specs.promote_draft/2
    -> Runs.start_for_attached_request/3
```

### Recommended Project Structure

```text
lib/
├── kiln/
│   ├── attach.ex
│   ├── attach/
│   │   ├── safety_gate.ex
│   │   ├── continuity.ex
│   │   ├── delivery.ex
│   │   ├── brownfield_preflight.ex      # new advisory boundary [ASSUMED]
│   │   └── brownfield_finding.ex        # optional typed struct home [ASSUMED]
│   ├── runs.ex
│   └── specs.ex
└── kiln_web/live/
    └── attach_entry_live.ex

test/
├── kiln/
│   ├── attach/
│   │   ├── safety_gate_test.exs
│   │   ├── continuity_test.exs
│   │   └── brownfield_preflight_test.exs  # new [ASSUMED]
│   └── runs/
│       ├── attached_continuity_test.exs
│       └── attached_request_start_test.exs
└── kiln_web/live/
    └── attach_entry_live_test.exs
```

### Pattern 1: Hard Gate, Then Advisory Report

**What:** Keep `SafetyGate` unchanged as the hard-stop mutation boundary and introduce a second evaluator that only runs after hard safety succeeds. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**When to use:** Every attached-repo launch attempt after continuity refresh or fresh attach readiness. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

**Example:**
```elixir
# Source: lib/kiln_web/live/attach_entry_live.ex + recommended Phase 34 seam
with {:ok, socket, attached_repo} <- maybe_refresh_attached_repo(socket, attached_repo),
     :ok <- preflight_attached_request_start(),
     {:ok, report} <- Attach.evaluate_brownfield_preflight(attached_repo, params),
     :ok <- Attach.require_launchable(report),
     {:ok, draft} <- create_attached_request_draft(attached_repo.id, params),
     {:ok, promoted_request} <- promote_attached_request_draft(draft.id),
     {:ok, run} <- start_attached_request_run(promoted_request, attached_repo.id) do
  ...
end
```
[VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [ASSUMED]

### Pattern 2: Typed Findings, Not Score Blobs

**What:** Model findings as explicit structs or maps with `severity`, `code`, `title`, `why`, `next_action`, and `evidence`. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED]

**When to use:** Fatal same-lane ambiguity, warning overlap/narrowing guidance, and repo-context info rows. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**Example:**
```elixir
# Source: recommended Phase 34 finding shape
%{
  severity: :warning,
  code: :possible_overlap,
  title: "Recent same-repo work may overlap this request",
  why: "A recent draft PR targets the same repo and base branch with similar request text.",
  next_action: "Accept the narrower request or inspect the prior draft before starting a new run.",
  evidence: %{
    repo_slug: "owner/repo",
    base_branch: "main",
    prior_run_id: run.id,
    prior_branch: get_in(run.github_delivery_snapshot, ["attach", "branch"])
  }
}
```
[VERIFIED: lib/kiln/runs/run.ex] [ASSUMED]

### Pattern 3: Same-Repo Candidate Pool Only

**What:** Limit overlap candidates to one attached repo and one base-branch lane. Read open drafts and promoted requests from `Specs`, recent same-repo runs from `Runs`, and live PRs from GitHub. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] [VERIFIED: gh pr list --help]

**When to use:** Duplicate/overlap warnings and same-lane fatal checks. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**Example:**
```elixir
# Source: recommended Phase 34 query split
%{
  open_drafts: Specs.list_open_attached_drafts(attached_repo.id),
  promoted_requests: Specs.list_recent_promoted_attached_requests(attached_repo.id, limit: 5),
  recent_runs: Runs.list_recent_for_attached_repo(attached_repo.id, limit: 5),
  open_prs: GitHub.Cli.list_open_prs(repo_slug, base_branch: attached_repo.base_branch)
}
```
[VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] [ASSUMED]

### Pattern 4: Dedicated Narrowing State on `/attach`

**What:** Add a warning/narrowing presentation branch separate from the existing blocked UI. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**When to use:** The repo is safe to touch but the request is wide or likely collides with recent same-repo work. [VERIFIED: .planning/REQUIREMENTS.md]

**Example:**
```elixir
# Source: recommended Phase 34 LiveView state extension
socket
|> assign(:resolution_state, :narrowing)
|> assign(:brownfield_report, report)
|> assign(:request_form, request_form(suggested_params))
|> assign(:request_error, nil)
```
[VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [ASSUMED]

### Anti-Patterns to Avoid

- **Do not widen `SafetyGate` into heuristic scoring:** the phase context explicitly separates deterministic blockers from advisory findings. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
- **Do not compute overlap heuristics in LiveView:** the UI should render findings, not own candidate collection or scoring. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
- **Do not persist a cached preflight verdict on `attached_repos`:** mutable repo reality already gets recomputed on refresh and must stay fresh. [VERIFIED: lib/kiln/attach.ex] [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
- **Do not add cross-repo heuristics:** same-repo only is a locked scope boundary. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Open PR overlap detection | Custom GitHub REST wrapper just for this phase | Repo-scoped `gh pr list --json ... --base ... --state open` behind the existing GitHub CLI boundary. [VERIFIED: gh pr list --help] | `gh` is already an attach prerequisite and gives the exact branch/base filters needed. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: gh auth status] |
| Same-repo continuity corpus | New shadow table of “brownfield work objects” | Existing `spec_drafts`, `spec_revisions`, `runs`, and delivery snapshots. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] [VERIFIED: lib/kiln/runs/run.ex] | The repo already has explicit ids and lifetimes for these objects. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| Advisory outcome transport | Freeform strings or score-only blobs | Typed findings with severity/code/evidence/next action. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] | Planner and UI both need deterministic branching and testable evidence. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |
| Scope-collision intelligence | LLM semantic analysis across repos | Cheap, explainable same-repo normalization plus weighted overlaps. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED] | Phase 34 explicitly defers deep semantic analysis and cross-repo reasoning. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |

**Key insight:** this phase should compose live git facts, GitHub lane facts, and same-repo historical facts; it should not invent a new brownfield intelligence subsystem. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: lib/kiln/attach/continuity.ex] [VERIFIED: lib/kiln/runs/run.ex]

## Common Pitfalls

### Pitfall 1: Turning Warnings into Silent Blocks

**What goes wrong:** Non-fatal overlaps get shoved into the existing blocked path, so the operator loses the chance to narrow and continue. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

**Why it happens:** The current UI only distinguishes ready, continuity, blocked, and error states. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

**How to avoid:** Add a dedicated narrowing/report state with explicit primary and secondary actions. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**Warning signs:** Findings with severity `:warning` still render inside `#attach-blocked` or reuse blocked microcopy. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

### Pitfall 2: Cross-Repo Leakage in Overlap Queries

**What goes wrong:** Drafts or runs from another repo influence the current repo’s advice. [VERIFIED: test/kiln/attach/continuity_test.exs]

**Why it happens:** Candidate queries ignore `attached_repo_id` or reuse continuity helpers too loosely. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex]

**How to avoid:** Keep `attached_repo_id` as the first filter in every overlap query and only add base-branch boosts after repo filtering. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED]

**Warning signs:** Tests pass with mixed fixtures unless the repo ids are different, or warnings reference the wrong repo slug. [VERIFIED: test/kiln/attach/continuity_test.exs]

### Pitfall 3: Treating Frozen Delivery Snapshot Data as Current Git Truth

**What goes wrong:** Old branch/base facts get mistaken for live repo state or live PR openness. [VERIFIED: lib/kiln/attach/delivery.ex] [VERIFIED: lib/kiln/runs/run.ex]

**Why it happens:** `github_delivery_snapshot` is intentionally frozen for delivery stability, not for live-status truth. [VERIFIED: lib/kiln/attach/delivery.ex]

**How to avoid:** Use snapshots to enrich evidence, but query git and GitHub again for live conditions that can drift. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: gh pr list --help]

**Warning signs:** A warning claims an “open PR” based only on stored snapshot data with no live GitHub query. [VERIFIED: lib/kiln/runs/run.ex] [ASSUMED]

### Pitfall 4: Letting the Heuristic Stack Grow Beyond Explainability

**What goes wrong:** The advisory layer becomes opaque and hard to tune, which erodes trust. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**Why it happens:** It is tempting to use semantic models or broad text scoring to reduce false negatives. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

**How to avoid:** Keep the first version bounded to normalized request text, repo/base-branch facts, same-repo work-object status, and live PR lane facts. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED]

**Warning signs:** Findings cannot show evidence beyond “confidence” or a hidden score. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]

## Code Examples

Verified patterns from local sources:

### Attach Refresh Before Continuity Launch
```elixir
# Source: lib/kiln_web/live/attach_entry_live.ex
with {:ok, socket, attached_repo} <- maybe_refresh_attached_repo(socket, attached_repo),
     :ok <- preflight_attached_request_start(),
     {:ok, draft} <- create_attached_request_draft(attached_repo.id, params),
     {:ok, promoted_request} <- promote_attached_request_draft(draft.id),
     {:ok, run} <- start_attached_request_run(promoted_request, attached_repo.id) do
  _ = mark_run_started(attached_repo.id)
  ...
end
```
[VERIFIED: lib/kiln_web/live/attach_entry_live.ex]

### Same-Repo Run Query with Spec Preloads
```elixir
# Source: lib/kiln/runs.ex
from(r in Run,
  where: r.attached_repo_id == ^attached_repo_id,
  order_by: [desc: r.inserted_at],
  left_join: revision in SpecRevision,
  on: revision.id == r.spec_revision_id,
  left_join: spec in Spec,
  on: spec.id == r.spec_id,
  preload: [spec_revision: revision, spec: spec],
  limit: ^limit
)
|> Repo.all()
```
[VERIFIED: lib/kiln/runs.ex]

### Continuity Selection Precedence
```elixir
# Source: lib/kiln/attach/continuity.ex
latest_open_draft(attached_repo_id) ||
  latest_promoted_request(attached_repo_id) ||
  latest_run_request(attached_repo_id)
```
[VERIFIED: lib/kiln/attach/continuity.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Binary attach readiness only (`ready` or `blocked`) [VERIFIED: lib/kiln/attach/safety_gate.ex] | Phase 34 should add typed `fatal` / `warning` / `info` advisory findings after hard safety passes. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED] | Planned for 2026-04-24 Phase 34. [VERIFIED: .planning/ROADMAP.md] | Enables `SAFE-01` and `SAFE-02` without weakening deterministic safety. [VERIFIED: .planning/REQUIREMENTS.md] |
| Continuity card only shows prior same-repo facts. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] | Continuity facts should become inputs to a separate brownfield advisory report, not the report itself. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] | After Phase 33 shipped on 2026-04-24. [VERIFIED: .planning/STATE.md] | Prevents continuity reuse from being mistaken for launch safety. [VERIFIED: .planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md] |
| Delivery snapshot freezes branch/base/head for later push/PR work. [VERIFIED: lib/kiln/attach/delivery.ex] | Phase 34 can reuse those frozen facts as evidence while still requerying live PR state. [VERIFIED: lib/kiln/attach/delivery.ex] [VERIFIED: gh pr list --help] | Phase 31 shipped on 2026-04-24. [VERIFIED: .planning/ROADMAP.md] | Same-lane collision detection becomes explainable without trusting stale PR state. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED] |

**Deprecated/outdated:**
- Treating attach safety as a single binary verdict is insufficient for this milestone because `SAFE-02` requires explicit non-fatal narrowing guidance. [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new sibling module such as `Kiln.Attach.BrownfieldPreflight` is the cleanest home for advisory findings. [ASSUMED] | Architecture Patterns | Low; the planner can rename the module if another boundary fits better. |
| A2 | The initial overlap heuristic should use explainable normalization plus weighted same-repo signals rather than semantic/LLM analysis. [ASSUMED] | Don't Hand-Roll / Common Pitfalls | Medium; poor weighting could create noisy warnings or miss real overlaps. |
| A3 | A first-pass request-breadth warning can be driven by simple lexical and structural heuristics well enough to support narrowing UX. [ASSUMED] | Architecture Patterns / Open Questions | Medium; false positives could frustrate operators, false negatives could let wide requests through. |

## Open Questions (RESOLVED)

1. **How live must “open PR overlap” be?**
   - Decision: live GitHub PR lookup is the default `SAFE-01` path after hard safety passes, using repo-scoped `gh pr list`. [VERIFIED: gh pr list --help]
   - Resolution: if the live PR lookup fails after hard safety succeeds, Phase 34 should emit a typed non-fatal degradation finding instead of silently skipping overlap detection or hard-failing launch. Use `:info` when the failure only removes extra context, and escalate to `:warning` only when the missing live PR data materially lowers confidence in a same-lane decision. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [ASSUMED]
   - Planning impact: plan actions and verification should include an explicit degraded-lookup branch with evidence visible to the operator. [ASSUMED]

2. **How aggressive should the request-breadth heuristic be?**
   - Decision: breadth detection stays conservative, warning-only, and evidence-backed in Phase 34. It must not autonomously refuse launch by itself. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
   - Resolution: trigger the breadth warning only on obvious structural signals in the bounded request fields, such as multiple unrelated acceptance lanes, broad change summaries, or out-of-scope notes that imply several PR-sized concerns. [ASSUMED]
   - Planning impact: brownfield preflight should emit at most one suggested narrower request, preserve manual editing, and keep final start authority in the existing attach/run seams. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git` | repo-state probes and local branch/base checks | ✓ [VERIFIED: git --version] | `2.41.0` [VERIFIED: git --version] | — |
| `gh` | auth readiness and live PR overlap queries | ✓ [VERIFIED: gh auth status] | `2.89.0` [VERIFIED: gh --version] | Local snapshot-only warning mode if live query is intentionally degraded. [ASSUMED] |
| `docker` | broader shift-left / integration workflows after implementation | ✓ [VERIFIED: docker --version] | `29.3.1` [VERIFIED: docker --version] | `SHIFT_LEFT_SKIP_INTEGRATION=1` for planning-only checks. [VERIFIED: CLAUDE.md] |
| `mix` | tests and precommit verification | ✓ [VERIFIED: mix --version stderr] | `1.19.5` / OTP `28` [VERIFIED: mix --version stderr] | — |
| `just` | convenience wrapper for precommit / shift-left | ✗ [VERIFIED: just --version] | — | Use `bash script/precommit.sh` and `mix shift_left.verify`. [VERIFIED: CLAUDE.md] |

**Missing dependencies with no fallback:**
- None. [VERIFIED: git --version] [VERIFIED: gh auth status] [VERIFIED: docker --version]

**Missing dependencies with fallback:**
- `just` is not installed locally, but the repo documents shell-script and `mix` fallbacks for the same workflows. [VERIFIED: CLAUDE.md] [VERIFIED: just --version]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest + LazyHTML [VERIFIED: mix.exs] |
| Config file | `test/test_helper.exs` [VERIFIED: rg --files] |
| Quick run command | `mix test test/kiln/attach/brownfield_preflight_test.exs test/kiln_web/live/attach_entry_live_test.exs -x` [ASSUMED] |
| Full suite command | `bash script/precommit.sh` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SAFE-01 | Fatal same-lane or repo-state conflicts block launch with typed evidence. [VERIFIED: .planning/REQUIREMENTS.md] | unit + LiveView | `mix test test/kiln/attach/brownfield_preflight_test.exs test/kiln_web/live/attach_entry_live_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| SAFE-01 | Same-repo open PR overlap is detected and surfaced before coding starts. [VERIFIED: .planning/REQUIREMENTS.md] | unit | `mix test test/kiln/attach/brownfield_preflight_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| SAFE-02 | Non-fatal breadth/overlap findings render narrowing guidance and suggested request actions. [VERIFIED: .planning/REQUIREMENTS.md] | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs -x` [VERIFIED: test/kiln_web/live/attach_entry_live_test.exs] | ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/kiln/attach/brownfield_preflight_test.exs test/kiln_web/live/attach_entry_live_test.exs -x` [ASSUMED]
- **Per wave merge:** `bash script/precommit.sh` [VERIFIED: CLAUDE.md]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: .planning/config.json]

### Wave 0 Gaps

- [ ] `test/kiln/attach/brownfield_preflight_test.exs` — typed findings, same-lane fatal, overlap warning, and narrowing suggestion coverage. [ASSUMED]
- [ ] Extend `test/kiln_web/live/attach_entry_live_test.exs` — dedicated narrowing panel, evidence rendering, accept-suggestion CTA, and manual-edit fallback. [VERIFIED: test/kiln_web/live/attach_entry_live_test.exs] [ASSUMED]
- [ ] Add or extend `test/kiln/runs/attached_request_start_test.exs` only if the launch path gains a new typed refusal tuple beyond the current blocked/error cases. [VERIFIED: test/kiln/runs/attached_request_start_test.exs] [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: .planning/PROJECT.md] | Solo local operator flow; Phase 34 relies on machine-local `gh` auth state only. [VERIFIED: lib/kiln/attach/safety_gate.ex] |
| V3 Session Management | no [VERIFIED: .planning/PROJECT.md] | No app-login/session system is introduced by this phase. [VERIFIED: .planning/PROJECT.md] |
| V4 Access Control | yes [VERIFIED: .planning/config.json] | Keep repo selection same-repo and server-authoritative; do not trust browser params beyond ids. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |
| V5 Input Validation | yes [VERIFIED: .planning/config.json] | Continue using request changesets and explicit query filters on `attached_repo_id`, `draft_id`, and `run_id`. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] |
| V6 Cryptography | no [VERIFIED: .planning/PROJECT.md] | Phase 34 adds no crypto responsibilities. [VERIFIED: .planning/PROJECT.md] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-repo data leakage through overly broad overlap queries | Information Disclosure | Filter every query by `attached_repo_id` first and keep repo ids server-owned. [VERIFIED: lib/kiln/specs.ex] [VERIFIED: lib/kiln/runs.ex] |
| Unsafe mutation from stale repo state | Tampering | Continue rerunning hydration and `SafetyGate` before launch instead of caching readiness. [VERIFIED: lib/kiln/attach.ex] [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] |
| Misleading operator guidance from opaque heuristics | Spoofing / Repudiation | Emit typed codes plus evidence and next actions; avoid score-only UX. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md] |
| Command-injection risk in repo/branch probes | Tampering | Keep git and GitHub calls behind existing controlled argv-based runners; do not interpolate shell strings from request text. [VERIFIED: lib/kiln/attach/safety_gate.ex] [VERIFIED: lib/kiln/attach/delivery.ex] |

## Sources

### Primary (HIGH confidence)

- `CLAUDE.md` - project-specific workflow, LiveView, testing, and verification constraints. [VERIFIED: CLAUDE.md]
- `.planning/ROADMAP.md` - Phase 34 goal and milestone ordering. [VERIFIED: .planning/ROADMAP.md]
- `.planning/REQUIREMENTS.md` - `SAFE-01`, `SAFE-02`, `TRUST-04`, and `UAT-06` scope boundaries. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/STATE.md` - current milestone posture and readiness to plan Phase 34. [VERIFIED: .planning/STATE.md]
- `.planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md` - locked decisions for advisory findings, same-repo heuristics, and narrowing UX. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
- `.planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md` - continuity contract that Phase 34 must preserve. [VERIFIED: .planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md]
- `lib/kiln/attach.ex` - attach public seams and refresh behavior. [VERIFIED: lib/kiln/attach.ex]
- `lib/kiln/attach/safety_gate.ex` - current deterministic hard-stop gate and typed blocked maps. [VERIFIED: lib/kiln/attach/safety_gate.ex]
- `lib/kiln/attach/continuity.ex` - same-repo continuity corpus and precedence logic. [VERIFIED: lib/kiln/attach/continuity.ex]
- `lib/kiln/attach/delivery.ex` - frozen delivery snapshot facts for branch/base evidence. [VERIFIED: lib/kiln/attach/delivery.ex]
- `lib/kiln/runs.ex` and `lib/kiln/runs/run.ex` - same-repo run queries and stored delivery snapshot shape. [VERIFIED: lib/kiln/runs.ex] [VERIFIED: lib/kiln/runs/run.ex]
- `lib/kiln_web/live/attach_entry_live.ex` - current `/attach` state machine and run-start flow. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex]
- `test/kiln/attach/safety_gate_test.exs`, `test/kiln/attach/continuity_test.exs`, `test/kiln/runs/attached_continuity_test.exs`, `test/kiln/runs/attached_request_start_test.exs`, `test/kiln_web/live/attach_entry_live_test.exs` - existing proof patterns and same-repo guardrails. [VERIFIED: codebase grep]
- `gh pr list --help` and `gh auth status` - live GitHub CLI capability and local auth availability. [VERIFIED: gh pr list --help] [VERIFIED: gh auth status]

### Secondary (MEDIUM confidence)

- None. [VERIFIED: research session]

### Tertiary (LOW confidence)

- Heuristic weighting and breadth-threshold recommendations in this document are implementation hypotheses, not codebase-verified facts. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 34 reuses installed dependencies and existing attach boundaries. [VERIFIED: mix.exs] [VERIFIED: lib/kiln/attach.ex]
- Architecture: HIGH - The phase context is explicit about boundary split, same-repo scope, and typed findings. [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
- Pitfalls: HIGH - Current code and tests already show the binary-state limitations and same-repo query patterns this phase must preserve. [VERIFIED: lib/kiln_web/live/attach_entry_live.ex] [VERIFIED: test/kiln/attach/continuity_test.exs]

**Research date:** 2026-04-24
**Valid until:** 2026-05-24
