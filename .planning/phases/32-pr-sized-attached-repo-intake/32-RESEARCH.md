# Phase 32: PR-sized attached-repo intake - Research

**Researched:** 2026-04-24  
**Domain:** Attached-repo request intake, bounded work framing, and brownfield run launch seams  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

No `32-CONTEXT.md` exists yet. Research scope is therefore derived from `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, the Phase 31 artifacts, and the user prompt. [VERIFIED: codebase grep]

### Locked Decisions

- Phase 32 is the first phase of `v0.7.0` and must satisfy `WORK-01`: the operator starts attached-repo work from one bounded feature or bugfix request with enough acceptance framing to treat it as one PR-sized unit. [VERIFIED: codebase grep]
- Phase 32 depends on Phase 31 and should build on the shipped attach-first baseline rather than replacing it. [VERIFIED: codebase grep]
- Research focus is explicitly limited to bounded attached-repo intake contract, operator framing, backend ownership seams, likely data-model or run-spec impacts, and proof shape. [VERIFIED: codebase grep]

### Claude's Discretion

- Choose the exact intake form shape, persistence pattern, and launcher seam as long as the result stays bounded, preserves the Phase 31 trust ramp, and gives later phases a stable contract to reuse. [VERIFIED: codebase grep]

### Deferred Ideas (OUT OF SCOPE)

- Repeat-run continuity belongs to Phase 33, not Phase 32. [VERIFIED: codebase grep]
- Brownfield preflight widening belongs to Phase 34, not Phase 32. [VERIFIED: codebase grep]
- Draft PR handoff tightening and milestone-owning proof belong to Phase 35, not Phase 32. [VERIFIED: codebase grep]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WORK-01 | Operator can start an attached-repo run from one bounded feature or bugfix request with enough acceptance framing for Kiln to treat the work as one PR-sized unit instead of an open-ended continuation ask. [VERIFIED: codebase grep] | Use the existing attach-ready state as the entry point, validate the request with an Ecto-backed structured form, persist mutable intake on `spec_drafts`, carry an immutable copy into the promoted spec/revision, and only then launch attached work through an attach-aware run seam. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
</phase_requirements>

## Summary

Phase 31 already shipped the brownfield substrate Phase 32 should reuse: `/attach` resolves one repo and can end in a truthful ready/blocked state, `attached_repos` persists repo/workspace/base-branch facts, and attached delivery already freezes branch plus draft-PR facts on `runs.github_delivery_snapshot`. [VERIFIED: codebase grep]

The actual Phase 32 gap is higher in the stack. `/attach` still stops at readiness, the inbox/spec pipeline still models drafts as generic `title` plus `body`, `file_follow_up_from_run/2` still creates a lazy follow-up placeholder instead of a bounded change contract, and the only shipped launcher is `Runs.start_for_promoted_template/3`. [VERIFIED: codebase grep] Today there is no attach-specific run launcher, and `runs` has no `spec_id`, `spec_revision_id`, or `attached_repo_id` relation to make a bounded request durable at execution time. [VERIFIED: codebase grep]

The most coherent Phase 32 plan is therefore: keep `/attach` as the brownfield trust surface, add a structured PR-sized request form after attach readiness, validate it with an `embedded_schema` changeset rendered through `to_form/2`, persist the mutable contract on `spec_drafts`, copy the immutable contract into the promoted spec side, and introduce an attach-aware start seam if Phase 32 is expected to truly close "start an attached-repo run" rather than merely "author a request". [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

**Primary recommendation:** Plan Phase 32 as a structured intake-and-launch phase over existing `Kiln.Attach`, `Kiln.Specs`, and `Kiln.Runs` seams; do not build a new brownfield subsystem, and do not treat a freeform continuation draft as sufficient intake. [VERIFIED: codebase grep]

## Project Constraints (from CLAUDE.md)

- Use Phoenix LiveView form conventions already enforced in the repo: assign forms with `to_form/2`, render them with `<.form for={@form}>`, and access fields through `@form[:field]`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]
- Keep `/attach` under `Layouts.app` and preserve the existing calm, explicit operator copy contract; attach remains a route-backed brownfield path, not a hidden variation of templates. [VERIFIED: codebase grep]
- Keep persistence and validation inside existing backend seams instead of ad hoc UI-only state. The repo consistently uses Ecto schemas/changesets plus public context APIs such as `Kiln.Attach`, `Kiln.Specs`, and `Kiln.Runs`. [VERIFIED: codebase grep]
- Do not add new HTTP clients or speculative dependencies for this phase. Existing repo guidance prefers current dependencies and specifically forbids swapping away from `Req` when HTTP is needed. [VERIFIED: codebase grep]
- Validation and security gates stay on by default because `.planning/config.json` enables Nyquist validation and security enforcement. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Attached repo resolution and ready-state truth | API / Backend | Database / Storage | `Kiln.Attach` plus `attached_repos` already own canonical repo identity, workspace path, and base-branch facts. [VERIFIED: codebase grep] |
| Operator-facing bounded request form | Frontend Server (SSR) | API / Backend | The LiveView should render and validate the form, but the contract itself belongs to backend changesets, not ephemeral assigns. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| Request-contract validation and normalization | API / Backend | — | Ecto embedded schemas are designed for mapping and validating external input before persistence. [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] |
| Mutable intake persistence before promotion | Database / Storage | API / Backend | `spec_drafts` already owns pre-promotion request state and source-specific draft metadata. [VERIFIED: codebase grep] |
| Immutable request snapshot after promotion | Database / Storage | API / Backend | `spec_revisions` is the append-only-ish spec body store and is the right lifetime boundary for promoted intake facts. [VERIFIED: codebase grep] |
| Attached brownfield run launch | API / Backend | Database / Storage | `Runs.start_for_promoted_template/3` is the existing start seam; Phase 32 needs an attach-aware sibling or a generalized launcher. [VERIFIED: codebase grep] |
| Branch / push / draft PR delivery | API / Backend | Database / Storage | Already owned by Phase 31 `Kiln.Attach.Delivery`, `PushWorker`, `OpenPRWorker`, and `runs.github_delivery_snapshot`; Phase 32 should not move it. [VERIFIED: codebase grep] |

## Standard Stack

Phase 32 does not need new Hex or npm packages. It should compose current attach, specs, runs, Ecto, and LiveView seams. [VERIFIED: codebase grep]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Kiln.Attach` + `Kiln.Attach.AttachedRepo` | repo-local | Canonical attached-repo identity, managed workspace facts, and ready-state lookup. [VERIFIED: codebase grep] | Phase 30 and 31 already made this the brownfield source of truth; Phase 32 should read repo facts here instead of trusting form params. [VERIFIED: codebase grep] |
| `Kiln.Specs.SpecDraft` + `Kiln.Specs.SpecRevision` | repo-local | Mutable pre-promotion request state and immutable promoted spec storage. [VERIFIED: codebase grep] | The existing inbox/promote flow already gives Phase 32 a draft-to-promoted lifecycle; extending it is cheaper and clearer than inventing a parallel intake table immediately. [VERIFIED: codebase grep] |
| `Ecto.Schema` / `Ecto.Changeset` | 3.13.5 from `mix.lock` [VERIFIED: codebase grep] | Structured validation for the bounded request contract. [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] | `embedded_schema` is explicitly documented for UI/input mapping and validation when the form shape is not itself the persisted DB row. [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] |
| `Phoenix.Component.to_form/2` + `<.form>` | 1.1.28 from `mix.lock` [VERIFIED: codebase grep] | LiveView form normalization and rendering for request intake. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] | The repo already uses `to_form/2`, and Phoenix docs explicitly recommend storing the form assign and using `@form[:field]`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| `Kiln.Runs` | repo-local | Run creation/start seam. [VERIFIED: codebase grep] | `Runs.start_for_promoted_template/3` is the existing launch pattern; attached work should gain a sibling seam instead of bypassing `Runs`. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `KilnWeb.AttachEntryLive` | repo-local | Existing attach trust surface at `/attach`. [VERIFIED: codebase grep] | Use as the operator entry point for the bounded request once attach reaches ready state. [VERIFIED: codebase grep] |
| `KilnWeb.InboxLive` | repo-local | Existing draft edit/promote/archive UI. [VERIFIED: codebase grep] | Reuse if Phase 32 wants an edit-later handoff after initial attach intake or wants follow-up drafts to share the same bounded contract. [VERIFIED: codebase grep] |
| `Kiln.Attach.Delivery` | repo-local | Existing Phase 31 delivery orchestration. [VERIFIED: codebase grep] | Use only as a downstream consumer of the attach context; do not duplicate it in Phase 32. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend `spec_drafts` and `spec_revisions` with attach-request structure | Create a brand-new `attached_work_requests` table in Phase 32 | A new table is cleaner long-term, but it duplicates an existing draft/promote lifecycle before the product has proven it needs a separate bounded context. [VERIFIED: codebase grep] |
| Validate intake with `embedded_schema` + changeset | Parse raw maps manually in LiveView events | Reject manual maps. The repo already centers validation in changesets, and Ecto documents embedded schemas specifically for validating external/UI input. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] |
| Add explicit run relations for core identity if launch is in scope | Hide `attached_repo_id` and spec identity in JSON maps | Reject JSON-only identity for core relations. The repo uses `github_delivery_snapshot` for derived delivery facts, not primary entity linkage, and foreign keys keep continuity/proof queries tractable. [VERIFIED: codebase grep] |

**Installation:**
```bash
# No new dependencies recommended for Phase 32.
mix deps.get
```

**Version verification:** `mix.lock` currently pins `ecto 3.13.5`, `ecto_sql 3.13.5`, `phoenix 1.8.5`, and `phoenix_live_view 1.1.28`. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Operator opens /attach
    |
    v
AttachEntryLive resolves repo source and reaches ready/blocked state
    |
    +--> blocked -> remediation copy only (stop)
    |
    v
Ready attached repo exposes bounded request form
    |-- work kind: feature | bugfix
    |-- concise change title / summary
    |-- acceptance bullets / done-when framing
    |-- constraints or out-of-scope notes
    v
Attach intake changeset (embedded_schema)
    |
    +--> invalid -> LiveView re-renders exact errors
    |
    v
Specs context persists mutable attach draft
    |
    v
Draft promotion creates immutable spec/revision snapshot
    |
    v
Attach-aware Runs launcher freezes attached_repo + spec identity for execution
    |
    v
Later phases reuse:
  Phase 33 continuity
  Phase 34 preflight guardrails
  Phase 35 draft PR handoff
```

### Recommended Project Structure

```text
lib/
├── kiln/
│   ├── attach/
│   │   ├── intake.ex            # New attach-request orchestration boundary
│   │   ├── intake_request.ex    # New embedded_schema/form contract
│   │   ├── attached_repo.ex     # Existing durable repo identity
│   │   └── delivery.ex          # Existing Phase 31 downstream delivery seam
│   ├── specs/
│   │   ├── spec_draft.ex        # Extend for mutable attach-intake metadata
│   │   └── spec_revision.ex     # Extend for immutable promoted intake snapshot
│   └── runs.ex                  # Add attach-aware create/start seam if launch is in scope
└── kiln_web/live/
    └── attach_entry_live.ex     # Extend ready state into bounded request intake

test/
├── kiln/
│   └── attach/
│       └── intake_test.exs
├── integration/
│   └── attached_repo_intake_test.exs
└── kiln_web/live/
    └── attach_entry_live_test.exs
```

### Pattern 1: Mutable draft, immutable promoted snapshot

**What:** Keep operator edits and retries on a mutable attach-request draft, then copy the frozen contract into the promoted spec side when the operator commits to starting work. [VERIFIED: codebase grep]

**When to use:** Any path where the operator may refine scope before launch but later phases need an immutable statement of "what this run was supposed to do". [VERIFIED: codebase grep]

**Why:** `spec_drafts` already owns mutable intake state, while `spec_revisions` already owns append-only-ish promoted content. Matching lifetimes keeps later continuity logic clear. [VERIFIED: codebase grep]

**Example:**
```elixir
# Source: adapted from Ecto embedded-schema docs and local Specs patterns
defmodule Kiln.Attach.IntakeRequest do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :work_kind, Ecto.Enum, values: [:feature, :bugfix]
    field :title, :string
    field :change_summary, :string
    field :acceptance_criteria, {:array, :string}, default: []
    field :out_of_scope, {:array, :string}, default: []
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:work_kind, :title, :change_summary, :acceptance_criteria, :out_of_scope])
    |> validate_required([:work_kind, :title, :change_summary])
    |> validate_length(:acceptance_criteria, min: 1)
  end
end
```
Source: [Ecto embedded_schema docs](https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html) and local `SpecDraft` changeset patterns. [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] [VERIFIED: codebase grep]

### Pattern 2: LiveView form stays changeset-backed from validate to submit

**What:** Keep the attach request form in one `@form` assign backed by a changeset and re-render validation failures in place. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

**When to use:** The attach-ready state on `/attach`, or any follow-up draft editor that collects structured brownfield scope. [VERIFIED: codebase grep]

**Example:**
```elixir
# Source: adapted from Phoenix.Component form docs
def handle_event("validate_request", %{"attach_request" => params}, socket) do
  form =
    %Kiln.Attach.IntakeRequest{}
    |> Kiln.Attach.IntakeRequest.changeset(params)
    |> to_form(action: :validate, as: :attach_request)

  {:noreply, assign(socket, :form, form)}
end
```
Source: [Phoenix.Component to_form docs](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html). [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

### Pattern 3: Core relations stay explicit; snapshots hold derived display facts

**What:** Persist `attached_repo_id` and spec identity as first-class relations if Phase 32 includes run launch, and reserve JSON snapshots for frozen derived facts or operator-facing summaries. [VERIFIED: codebase grep]

**When to use:** Any run-start path that must survive retries, support continuity, or feed later brownfield phases without reparsing UI data. [VERIFIED: codebase grep]

**Why:** The codebase already uses `runs.github_delivery_snapshot` for downstream delivery facts, while durable primary entities such as attached repos, drafts, specs, revisions, and post-mortems use real schemas and foreign keys. [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Freeform continuation ask as the only contract:** a plain title/body pair does not force scope, acceptance, or out-of-scope framing, so later phases inherit ambiguity. [VERIFIED: codebase grep]
- **UI-only attach context:** hidden inputs for repo slug, remote URL, base branch, or workspace path would duplicate persisted `attached_repos` facts and drift from the actual attach source of truth. [VERIFIED: codebase grep]
- **JSON-only core identity on runs:** hiding attach repo or spec identity inside snapshots makes continuity, joins, and proof queries harder than necessary. [VERIFIED: codebase grep]
- **Reopening Phase 31 delivery logic:** branch naming, push, and draft-PR orchestration already ship behind `Kiln.Attach.Delivery`; Phase 32 should feed that seam, not replace it. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Structured request validation | Manual param parsing in LiveView | `embedded_schema` + `Ecto.Changeset` + `to_form/2` | Ecto documents embedded schemas for validating UI/external input, and Phoenix forms already normalize around changesets/forms. [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html] |
| Pre-launch brownfield request persistence | New attach-only persistence subsystem in Phase 32 | Extend `spec_drafts` and `spec_revisions` | The repo already has draft edit/promote flows, source-specific draft metadata, and a spec lifecycle. [VERIFIED: codebase grep] |
| Repo identity capture | Hidden form fields for branch/remote/workspace | `Kiln.Attach.get_attached_repo/1` and stored attach facts | Attached repo metadata is already durable and should remain programmatically owned. [VERIFIED: codebase grep] |
| Attached work launch | Ad hoc shell-out from LiveView or a launcher outside `Runs` | Attach-aware seam under `Kiln.Runs` | `Runs.start_for_promoted_template/3` is the existing start authority; attached work should follow the same control pattern. [VERIFIED: codebase grep] |

**Key insight:** The codebase already has almost every primitive Phase 32 needs except the intake contract itself. The leverage is in choosing the right lifetime boundaries, not in adding more brownfield infrastructure. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Accepting an unbounded request because the body is non-empty

**What goes wrong:** The operator can submit a vague continuation ask, and the planner later has to guess what "done" means. [VERIFIED: codebase grep]

**Why it happens:** Current draft creation only requires `title`, `body`, and `source`, so nothing enforces work kind, acceptance bullets, or scope fences. [VERIFIED: codebase grep]

**How to avoid:** Validate a dedicated bounded-request contract with required fields such as work kind, concise summary, and at least one acceptance bullet before promotion or run start. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html]

**Warning signs:** A draft can be promoted or launched even though it reads like "continue from here" or has no explicit done-when language. [VERIFIED: codebase grep]

### Pitfall 2: Losing attached repo linkage after promotion

**What goes wrong:** The request is bounded at draft time, but later phases cannot reliably recover which attached repo it belonged to. [VERIFIED: codebase grep]

**Why it happens:** `spec_drafts` can carry source-specific metadata today, but promoted specs/revisions and runs do not currently preserve attach linkage. [VERIFIED: codebase grep]

**How to avoid:** Carry `attached_repo_id` through the full lifecycle that Phase 32 owns, not just the LiveView submit path. [VERIFIED: codebase grep]

**Warning signs:** The launch seam requires the UI to repost attach facts that already exist in `attached_repos`. [VERIFIED: codebase grep]

### Pitfall 3: Treating `github_delivery_snapshot` as a generic brownfield state bucket

**What goes wrong:** Core intake identity and delivery facts mix together, which blurs what is mutable, what is derived, and what belongs to later phases. [VERIFIED: codebase grep]

**Why it happens:** `runs.github_delivery_snapshot` already exists and is tempting to extend indiscriminately. [VERIFIED: codebase grep]

**How to avoid:** Keep core request identity in first-class schemas/relations and reserve snapshots for frozen derived facts or handoff copy. [VERIFIED: codebase grep]

**Warning signs:** Planner tasks start referencing JSON paths for entity identity instead of schemas or foreign keys. [VERIFIED: codebase grep]

### Pitfall 4: Reusing the template launcher without attaching brownfield context

**What goes wrong:** The operator can start a run, but the run knows nothing durable about the attached repo or the bounded request it came from. [VERIFIED: codebase grep]

**Why it happens:** `Runs.start_for_promoted_template/3` loads a workflow and starts it, but it does not carry spec identity into `runs`, and there is no attach-aware equivalent today. [VERIFIED: codebase grep]

**How to avoid:** Either introduce `Runs.start_for_attached_request/…` or generalize the start seam around an explicit launch contract that includes attached-repo and promoted-request identity. [VERIFIED: codebase grep]

**Warning signs:** The launch code can run with only a workflow id plus ad hoc params from the UI. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources and local seams:

### Changeset-backed LiveView form

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html
def mount(_params, _session, socket) do
  changeset = Kiln.Attach.IntakeRequest.changeset(%Kiln.Attach.IntakeRequest{}, %{})
  {:ok, assign(socket, :form, to_form(changeset, as: :attach_request))}
end
```
[CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

### Embedded schema for UI-only validation before persistence

```elixir
# Source: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html
defmodule Kiln.Attach.IntakeRequest do
  use Ecto.Schema

  embedded_schema do
    field :title, :string
    field :change_summary, :string
  end
end
```
[CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html]

### Persisting attach-specific metadata on the existing draft seam

```elixir
# Source: local SpecDraft usage pattern
Specs.create_draft(%{
  title: attrs.title,
  body: rendered_markdown,
  source: :freeform,
  operator_summary: "Attached repo request: #{attrs.work_kind}",
  attached_repo_id: attached_repo.id,
  intake_contract: %{
    "work_kind" => Atom.to_string(attrs.work_kind),
    "acceptance_criteria" => attrs.acceptance_criteria,
    "out_of_scope" => attrs.out_of_scope
  }
})
```
This example reflects the recommended Phase 32 direction, not an existing field set. `Specs.create_draft/1` and `SpecDraft.changeset/2` are the verified local persistence seam; the exact new field names still need implementation. [VERIFIED: codebase grep] [ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/attach` only resolves and readies the repo | Phase 32 should continue from ready state into bounded request authoring. [VERIFIED: codebase grep] | v0.7.0 opened on 2026-04-24. [VERIFIED: codebase grep] | Brownfield work becomes request-driven instead of attach-driven. [VERIFIED: codebase grep] |
| Generic draft `title/body/source` | Attach work needs a typed request contract with acceptance framing. [VERIFIED: codebase grep] | Phase 32 target, not yet shipped. [VERIFIED: codebase grep] | Planner and operator both get one PR-sized unit instead of an open-ended ask. [VERIFIED: codebase grep] |
| Template-only launch seam | `WORK-01` likely requires an attach-aware launcher or generalized run-start contract. [VERIFIED: codebase grep] [ASSUMED] | Phase 32 target. [VERIFIED: codebase grep] | Prevents "attached run" from being just a UI illusion over template-first infrastructure. [VERIFIED: codebase grep] |

**Deprecated/outdated:**

- Treating attached continuation as a vague follow-up request is outdated for `v0.7.0` because milestone scope explicitly changed from "first believable attach" to "one bounded issue-to-draft-PR loop" on 2026-04-24. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 32 includes an actual attached-run launch seam, not only durable intake authoring. [RESOLVED] | Summary, Common Pitfalls, State of the Art | Resolved from `WORK-01` wording and the milestone sequence: Phase 33 depends on Phase 32 and focuses on repeat-run continuity, which presumes a first-class start path already exists. |
| A2 | The simplest durable shape is to extend `spec_drafts`/`spec_revisions` before creating a separate attach-request context. [ASSUMED] | Summary, Standard Stack, Don't Hand-Roll | A later dedicated brownfield-intake context might be cleaner if more requirements surface immediately. |
| A3 | Because launch is in scope, `runs` should gain explicit relations for attach/spec identity instead of another JSON snapshot. [RESOLVED] | Summary, Architecture Patterns | Resolved by existing repo conventions: primary entity linkage lives in schemas/foreign keys, while JSON snapshots hold derived delivery facts. |
| A4 | The existing shipped workflow remains the effective launcher workflow for attached work until a brownfield-specific workflow is introduced. [RESOLVED] | Open Questions | Resolved pragmatically for Phase 32 because no alternate brownfield workflow artifact exists in roadmap, requirements, or code. |

## Open Questions (RESOLVED)

1. **Does `WORK-01` require true run start in Phase 32, or only a durable bounded request ready for later launch?**
   - Resolution: `WORK-01` is treated literally. Phase 32 must include the attach-aware run start seam, not only request authoring.
   - Why: the requirement says the operator can "start an attached-repo run", and Phase 33 is scoped to repeat-run continuity rather than first-run launch creation. [VERIFIED: codebase grep]

2. **Where should the immutable promoted contract live?**
   - Resolution: the canonical immutable contract should live on `spec_revisions` as structured fields, while the rendered markdown body remains the human-readable view of the same bounded request.
   - Why: `spec_revisions` is already the promoted intent store, and `runs.github_delivery_snapshot` is explicitly downstream delivery state rather than source intent. [VERIFIED: codebase grep]

3. **Should the follow-up flow and first attach intake share the same contract immediately?**
   - Resolution: Phase 32 only needs to establish the attach-ready intake path, but it should name and store the contract in a way that Phase 33 can reuse without another schema reset.
   - Why: upgrading the merged-run follow-up path now would widen scope beyond `WORK-01`, while leaving the contract shape incompatible would create avoidable churn next phase. [VERIFIED: codebase grep]

4. **Which workflow should the new attach-aware launcher use?**
   - Resolution: use the existing shipped workflow selection path under `Kiln.Runs` for Phase 32; a brownfield-specific workflow selector is not part of current milestone scope.
   - Why: no alternate workflow artifact exists in the current planning set, and Phase 32's goal is to close intake/start semantics rather than introduce a second workflow family. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Test and validation commands for this phase | ✓ [VERIFIED: mix --version] | `Mix 1.19.5 / OTP 28` [VERIFIED: mix --version] | — |
| `git` | Existing attach workspace and downstream delivery chain | ✓ [VERIFIED: git --version] | `2.41.0` [VERIFIED: git --version] | — |
| `gh` | Existing attached-repo brownfield chain and later proof layers | ✓ [VERIFIED: gh --version] | `2.89.0` [VERIFIED: gh --version] | Later phases can stub CLI behavior in tests, but there is no real operator fallback for live PR creation. [VERIFIED: codebase grep] |

**Missing dependencies with no fallback:**

- None for research/planning on this machine. [VERIFIED: git --version] [VERIFIED: gh --version] [VERIFIED: mix --version]

**Missing dependencies with fallback:**

- None identified. [VERIFIED: git --version] [VERIFIED: gh --version] [VERIFIED: mix --version]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest + LazyHTML. [VERIFIED: codebase grep] |
| Config file | `.check.exs` plus project `mix test` aliases and existing LiveView test tree. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/kiln/attach/intake_test.exs test/kiln_web/live/attach_entry_live_test.exs` [ASSUMED] |
| Full suite command | `bash script/precommit.sh` per project instructions. [VERIFIED: codebase grep] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WORK-01 | Ready attached repo refuses open-ended request submission and requires explicit bounded framing. [VERIFIED: codebase grep] | unit + LiveView | `mix test test/kiln/attach/intake_test.exs test/kiln_web/live/attach_entry_live_test.exs` [ASSUMED] | ❌ Wave 0 |
| WORK-01 | Attach request can be persisted, promoted, and, if Phase 32 owns launch, started with durable attach/spec identity. [ASSUMED] | integration | `mix test test/integration/attached_repo_intake_test.exs` [ASSUMED] | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/kiln/attach/intake_test.exs test/kiln_web/live/attach_entry_live_test.exs` [ASSUMED]
- **Per wave merge:** `bash script/precommit.sh` [VERIFIED: codebase grep]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] `test/kiln/attach/intake_test.exs` — covers request-contract validation, normalization, and refusal of vague/open-ended asks. [ASSUMED]
- [ ] `test/integration/attached_repo_intake_test.exs` — covers draft persistence, promotion, and launch handoff if Phase 32 includes actual run start. [ASSUMED]
- [ ] `test/kiln_web/live/attach_entry_live_test.exs` — expand from ready/blocked proof into bounded-request form rendering, validation, and success flow. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: codebase grep] | Current local operator flow has no Phase 32 auth change. [VERIFIED: codebase grep] |
| V3 Session Management | no [VERIFIED: codebase grep] | No session-management change is implied by the current scope. [VERIFIED: codebase grep] |
| V4 Access Control | no [VERIFIED: codebase grep] | Phase 32 is about request validation and brownfield identity continuity, not role expansion. [VERIFIED: codebase grep] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | Use changeset validation on bounded request fields and always resolve repo identity from persisted `attached_repos`, not client-supplied facts. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] |
| V6 Cryptography | no [VERIFIED: codebase grep] | No new cryptographic requirement is introduced by request intake itself. [VERIFIED: codebase grep] |

### Known Threat Patterns for attached brownfield intake

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Scope escalation through vague operator input | Tampering | Require typed work kind plus explicit acceptance bullets before promotion or launch. [VERIFIED: codebase grep] |
| Cross-repo confusion by reposting stale hidden repo fields | Tampering | Lookup attached repo by durable id on the server and read branch/workspace/base facts from `attached_repos`. [VERIFIED: codebase grep] |
| Oversized or malformed request payloads | Denial of Service | Enforce changeset length/required-field validation and keep the form changeset-backed. [ASSUMED] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] |
| Rendering untrusted markdown/body without a stable contract | Injection | Keep operator-visible summaries explicit and use LiveView/HEEx rendering conventions rather than raw script injection. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- Local codebase reads and greps across `lib/kiln/attach.ex`, `lib/kiln/attach/attached_repo.ex`, `lib/kiln/attach/delivery.ex`, `lib/kiln/specs.ex`, `lib/kiln/specs/spec_draft.ex`, `lib/kiln/specs/spec_revision.ex`, `lib/kiln/runs.ex`, `lib/kiln/runs/run.ex`, `lib/kiln_web/live/attach_entry_live.ex`, `lib/kiln_web/live/inbox_live.ex`, `lib/kiln_web/live/run_detail_live.ex`, and related tests. [VERIFIED: codebase grep]
- Ecto embedded schema and validation docs: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html]
- Ecto schema docs for `embedded_schema` and `embeds_one`: https://hexdocs.pm/ecto/Ecto.Schema.html [CITED: https://hexdocs.pm/ecto/Ecto.Schema.html]
- Phoenix LiveView `Phoenix.Component` docs for `to_form/2` and `<.form>`: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]

### Secondary (MEDIUM confidence)

- None. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)

- Assumptions listed in `## Assumptions Log`. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - existing repo seams are clear, and Ecto/Phoenix docs confirm the form-validation recommendation. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto/3.13.5/data-mapping-and-validation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html]
- Architecture: MEDIUM - the attach/spec/run gaps are verified, but exact Phase 32 scope around launcher work still needs user confirmation. [VERIFIED: codebase grep] [ASSUMED]
- Pitfalls: MEDIUM - the failure modes follow directly from current schema and UI gaps, but some mitigations depend on the final decision about launcher scope. [VERIFIED: codebase grep] [ASSUMED]

**Research date:** 2026-04-24  
**Valid until:** 2026-05-24
