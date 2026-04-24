# Phase 35: Draft PR handoff and owning proof - Research

**Researched:** 2026-04-24
**Domain:** Attached-repo draft PR body generation and owning proof-path closure [VERIFIED: codebase grep]
**Confidence:** HIGH [VERIFIED: codebase grep]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-3501:** Preserve the Phase 31 trust posture: attached-repo delivery stays draft-first, factual, compact, and human-reviewable rather than bot-noisy or approval-gated. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3502:** Preserve the Phase 33 and Phase 34 boundary split: the PR handoff packages the final scoped result and proof surface; it does not replay broad continuity state or dump advisory preflight logs into the PR body. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3503:** Carry forward the user preference to shift low-impact defaults left inside GSD and Kiln where possible. Interruptions should remain reserved for materially outcome-changing trust, scope, or safety choices. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3504:** The PR `Verification` section must cite the owning proof command `MIX_ENV=test mix kiln.attach.prove`. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3505:** The PR `Verification` section must also cite the exact locked proof layers that the owning command runs, rather than relying on generic assurance prose alone. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3506:** Phase 35 should keep the cited proof layers explicit and reviewable. The current locked set is:
  - `test/integration/github_delivery_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs` [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3507:** Do not use generic claims like “workspace was marked ready before delivery” as the only verification language. Evidence must be concrete enough that a reviewer can rerun or inspect it without reverse-engineering intent. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3508:** Do not introduce artifact-linked or run-linked proof citations as the primary PR-body proof mechanism in this phase. Richer run/check URLs can be a future capability, but they are not required for the Phase 35 handoff contract. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3509:** The draft PR body should render a compact human-first `Summary` section derived from the bounded attached request, not a generic attached-repo update placeholder. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3510:** The PR body should render `Acceptance criteria` from the stored attached request so the reviewer can see the bounded done-definition without inferring it from the diff. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3511:** The PR body should render `Out of scope` only when the stored list is non-empty and materially clarifies the lane boundary. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3512:** Do not paste the full attached request markdown body or a raw metadata dump into the PR. The visible PR body must stay reviewable as a normal feature or bugfix handoff. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3513:** Keep `Out of scope` conditional. Never render empty or boilerplate boundary sections just to satisfy template shape. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3514:** Keep the PR human-first and compact: include the scoped request framing, verification citations, and the repo facts a reviewer actually uses. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3515:** Include `branch` and `base branch` facts in the body because they are immediately useful review context for attached brownfield work. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3516:** Keep exactly one lightweight Kiln provenance marker. The preferred marker is the existing `kiln-run: <run_id>` footer. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3517:** Do not expose `attached_repo_id` as a naked internal identifier in the PR body. If Phase 35 later gains a meaningful operator-facing link target, it may replace or supplement raw IDs, but raw internal IDs should not ship in the visible PR text. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3518:** Do not add a dedicated warning/preflight section to the PR body. Advisory findings from Phase 34 may appear only when they materially explain why the final shipped scope was narrowed or when they link to a concrete related prior draft, run, or PR. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3519:** Do not emit rich machine metadata blobs, JSON, YAML, or duplicate run-context blocks in the PR body. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3520:** Keep `mix kiln.attach.prove` as the sole owning proof command for attached-repo draft-PR handoff. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3521:** Extend the existing owning command only with the minimum additional locked proof layer or layers needed to close `TRUST-04` and `UAT-06`. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3522:** Do not create a new Phase-35-specific proof command or force operators to orchestrate multiple direct test invocations themselves. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3523:** The owning command remains the source of truth. Phase artifacts may cite or summarize its delegated proof layers, but docs must not become the orchestration layer. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **D-3524:** Keep the proof command narrow to the attached draft-PR handoff claim. Do not silently widen it into repo-wide gates like `mix precommit`, `just shift-left`, or broad `mix test`. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

### Claude's Discretion
- Exact PR section headings and sentence wording, as long as the body remains compact, factual, and human-first. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Exact formatting of verification bullet points, as long as the owning proof command and delegated proof layers remain visible. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Exact body placement of branch/base facts and the provenance marker, as long as duplication stays low and review ergonomics stay high. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Exact threshold for rendering `Out of scope`, as long as empty or low-value sections are omitted by default. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- Rich artifact-linked or run-linked verification references in the PR body. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- A separate Phase-35-specific proof command. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Full attached request markdown dumps in the visible PR body. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Rich machine metadata sections or structured blobs in PR text. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Dedicated PR-body replay of Phase 34 warning or narrowing findings. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUST-04 [VERIFIED: .planning/REQUIREMENTS.md] | Attached-repo runs produce a draft PR handoff that includes a scoped summary, proof or verification citations, and enough repo-fitting context for the operator to review the result as a normal feature or bugfix PR. [VERIFIED: .planning/REQUIREMENTS.md] | Render the PR body in `Kiln.Attach.Delivery` from durable attached-request fields on `SpecRevision` plus frozen branch/base/run facts already stored in `github_delivery_snapshot`. [VERIFIED: codebase grep] |
| UAT-06 [VERIFIED: .planning/REQUIREMENTS.md] | The repository contains one explicit automated proof path for PR-sized attached-repo continuation, including repeat-run continuity plus representative refusal or warning cases for brownfield preflight. [VERIFIED: .planning/REQUIREMENTS.md] | Keep `mix kiln.attach.prove` as the sole command, then lock its delegated list to include the minimum extra layer(s) needed for PR-body contract coverage and milestone wording closure. [ASSUMED] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Use existing Phoenix/LiveView patterns and keep LiveViews wrapped in `<Layouts.app ...>`. [VERIFIED: CLAUDE.md]
- Use existing `Req` for HTTP; do not introduce `httpoison`, `tesla`, or `:httpc`. [VERIFIED: CLAUDE.md]
- Keep forms on `/attach` driven by `to_form/2` plus `<.input>` and stable DOM ids for tests. [VERIFIED: CLAUDE.md]
- Prefer focused ExUnit and LiveView tests with `has_element?/2` and related helpers over raw HTML string assertions for UI behavior. [VERIFIED: CLAUDE.md]
- Run `just precommit` or `bash script/precommit.sh` after code changes, but Phase 35 must not redefine those broad repo gates as the owning proof path. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

## Summary

Phase 35 should stay entirely inside two existing seams: `Kiln.Attach.Delivery` for draft PR title/body freezing, and `Mix.Tasks.Kiln.Attach.Prove` for milestone-owning proof orchestration. The current implementation still generates a generic Phase 31 PR body from attached-repo facts only, including placeholder verification copy and a visible `attached_repo_id`, so the main implementation work is to swap that body builder to use durable attached-request fields already persisted on `SpecRevision` and copied from `SpecDraft`. [VERIFIED: codebase grep]

The data model already supports the desired body shape. `Kiln.Attach.Intake` stores `request_kind`, `change_summary`, `acceptance_criteria`, and `out_of_scope` on `spec_drafts`; `Specs.promote_draft/1` copies those fields onto `spec_revisions`; `Runs.create_for_attached_request/2` links the run to the promoted request; and `Kiln.Attach.Delivery` already freezes branch/base/title/body into `runs.github_delivery_snapshot`. That means Phase 35 does not need new persistence or a second GitHub transport. [VERIFIED: codebase grep]

The planning-sensitive gap is proof ownership. `mix kiln.attach.prove` currently delegates only three files: attach delivery happy path, safety-gate refusal coverage, and `/attach` LiveView coverage. That already covers draft delivery plus refusal and warning UI, but it does not yet lock the new PR-body contract, and the milestone wording explicitly calls out repeat-run continuity plus brownfield preflight warning/refusal coverage. The minimum safe plan is to keep the same owning command and add only the smallest extra delegated layer set needed to make those claims literally true and reviewable. [VERIFIED: codebase grep] [ASSUMED]

**Primary recommendation:** Update `Kiln.Attach.Delivery` to build a compact `Summary` / `Acceptance criteria` / conditional `Out of scope` / `Verification` / branch-facts handoff from `SpecRevision`, then extend `mix kiln.attach.prove` with the minimum extra delegated test files needed to lock that contract without widening scope. [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Draft PR body assembly from attached request fields [VERIFIED: codebase grep] | API / Backend [VERIFIED: codebase grep] | Database / Storage [VERIFIED: codebase grep] | `Kiln.Attach.Delivery` builds the frozen PR payload, but the authoritative request facts already live on `spec_revisions`. [VERIFIED: codebase grep] |
| Frozen branch/base/title/body snapshot persistence [VERIFIED: codebase grep] | Database / Storage [VERIFIED: codebase grep] | API / Backend [VERIFIED: codebase grep] | `Runs.promote_github_snapshot/2` persists the delivery snapshot that workers and continuity code reuse. [VERIFIED: codebase grep] |
| Owning proof-command orchestration [VERIFIED: codebase grep] | API / Backend [VERIFIED: codebase grep] | — | `Mix.Tasks.Kiln.Attach.Prove` is a backend CLI boundary that delegates fixed test layers in order. [VERIFIED: codebase grep] |
| Reviewer-visible continuity/preflight proof citation selection [VERIFIED: codebase grep] | API / Backend [VERIFIED: codebase grep] | Database / Storage [VERIFIED: codebase grep] | The PR body should cite locked proof layers, not replay UI state, while continuity and preflight evidence remains backed by existing repo/request/run records and tests. [VERIFIED: codebase grep] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Kiln.Attach.Delivery` [VERIFIED: codebase grep] | repo-local [VERIFIED: codebase grep] | Freeze branch, title, body, and worker args for attached-repo delivery. [VERIFIED: codebase grep] | It is already the only place that owns branch/title/body freezing, so Phase 35 should tighten this seam instead of inventing another formatter. [VERIFIED: codebase grep] |
| `Mix.Tasks.Kiln.Attach.Prove` [VERIFIED: codebase grep] | repo-local [VERIFIED: codebase grep] | Repository-level owning proof command for attached-repo handoff. [VERIFIED: codebase grep] | Phase 35 context explicitly locks this as the sole proof command. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| GitHub CLI `gh pr create` [CITED: https://cli.github.com/manual/gh_pr_create] | `2.89.0` local (`2026-03-26`) [VERIFIED: command output] | Create draft PRs with explicit `--title`, `--body` or `--body-file`, `--base`, and `--head`. [CITED: https://cli.github.com/manual/gh_pr_create] | Kiln already wraps this CLI in `Kiln.GitHub.Cli.create_pr/2`, including body-file fallback for long bodies, so no transport change is needed. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Kiln.Specs.SpecRevision` [VERIFIED: codebase grep] | repo-local [VERIFIED: codebase grep] | Durable source for `request_kind`, `change_summary`, `acceptance_criteria`, and `out_of_scope`. [VERIFIED: codebase grep] | Use it as the PR-body source of truth after draft promotion. [VERIFIED: codebase grep] |
| `test/kiln/attach/delivery_test.exs` [VERIFIED: codebase grep] | repo-local [VERIFIED: codebase grep] | Fast seam test for frozen PR body shape and snapshot fields. [VERIFIED: codebase grep] | Use it to lock body sections and metadata omissions without paying the full integration-test cost. [ASSUMED] |
| `test/kiln/attach/continuity_test.exs` and `test/kiln/attach/brownfield_preflight_test.exs` [VERIFIED: codebase grep] | repo-local [VERIFIED: codebase grep] | Existing same-repo continuity and typed warning/refusal coverage. [VERIFIED: codebase grep] | Reuse them if `mix kiln.attach.prove` needs explicit delegated layers for `UAT-06`. [ASSUMED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Building the PR body from `SpecRevision` fields [VERIFIED: codebase grep] | Re-parse `spec_draft.body` or paste full intake markdown [VERIFIED: codebase grep] | This would duplicate markdown parsing, violate the compact human-first body constraint, and reintroduce raw request dumps. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| Extending `mix kiln.attach.prove` [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | Adding a new `mix kiln.attach.phase35.prove` task [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | A second command contradicts locked decisions D-3520 through D-3522 and would fracture milestone proof ownership. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| Keeping preflight and continuity evidence in delegated proof layers [VERIFIED: codebase grep] | Dumping warning or continuity context into the PR body [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | That widens scope, creates reviewer noise, and breaks the Phase 33/34 boundary split. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |

**Installation:**
```bash
# No new dependencies required for Phase 35.
```

**Version verification:** No new Hex or npm packages are needed for Phase 35. The only external transport in scope is `gh`, and this workspace has `gh version 2.89.0 (2026-03-26)` available locally. [VERIFIED: command output]

## Architecture Patterns

### System Architecture Diagram

```text
Attached request draft
  -> Specs.promote_draft/1 copies bounded fields to SpecRevision
  -> Runs.create_for_attached_request/2 links run + attached_repo + spec_revision
  -> Kiln.Attach.Delivery.prepare/4 loads run + attached_repo
  -> Delivery body builder reads SpecRevision fields + frozen branch/base/run facts
  -> Runs.promote_github_snapshot/2 persists frozen attach/pr snapshot
  -> PushWorker / OpenPRWorker consume frozen args
  -> GitHub CLI `gh pr create --draft ...`
  -> Reviewer sees compact PR body with scoped summary + verification citations
  -> `mix kiln.attach.prove` delegates locked proof layers for the same contract
```

### Recommended Project Structure
```text
lib/
├── kiln/attach/delivery.ex              # Frozen draft PR title/body generation and worker args
├── kiln/specs/spec_revision.ex          # Durable bounded attached-request fields
├── kiln/github/cli.ex                   # `gh pr create` transport wrapper
└── mix/tasks/kiln.attach.prove.ex       # Sole owning proof command

test/
├── kiln/attach/delivery_test.exs        # Fast body-contract seam test
├── kiln/attach/continuity_test.exs      # Same-repo continuity facts
├── kiln/attach/brownfield_preflight_test.exs  # Warning/fatal report contract
├── kiln_web/live/attach_entry_live_test.exs   # `/attach` truth-surface coverage
└── mix/tasks/kiln.attach.prove_test.exs # Locked delegated proof list
```

### Pattern 1: Render From Durable Structured Fields
**What:** Build PR sections from `SpecRevision.request_kind`, `change_summary`, `acceptance_criteria`, and `out_of_scope` rather than from markdown re-parsing or attach UI state. [VERIFIED: codebase grep]
**When to use:** Any reviewer-facing attached-repo handoff text that must stay stable across retries and worker replays. [VERIFIED: codebase grep]
**Example:**
```elixir
# Source: lib/kiln/specs.ex + lib/kiln/attach/delivery.ex
with %SpecRevision{} = revision <- run.spec_revision do
  sections = [
    summary_section(revision),
    acceptance_section(revision.acceptance_criteria),
    out_of_scope_section(revision.out_of_scope),
    verification_section(run.id),
    branch_facts_section(branch, base_branch)
  ]

  Enum.reject(sections, &is_nil/1)
  |> Enum.join("\n\n")
end
```

### Pattern 2: Keep One Owning Proof Command With Explicit Delegation
**What:** Preserve `mix kiln.attach.prove` as the only operator-facing proof entry point and make its delegated file list the canonical proof contract. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
**When to use:** Milestone ownership, PR verification copy, and phase verification artifacts. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
**Example:**
```elixir
# Source: lib/mix/tasks/kiln.attach.prove.ex
@proof_layers [
  ["env", "MIX_ENV=test", "mix", "test", "test/integration/github_delivery_test.exs"],
  ["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/safety_gate_test.exs"],
  ["env", "MIX_ENV=test", "mix", "test", "test/kiln_web/live/attach_entry_live_test.exs"]
]
```

### Anti-Patterns to Avoid
- **Generic verification prose:** The current body says only that the workspace was ready and the PR is draft-first, which is too vague for Phase 35. [VERIFIED: codebase grep]
- **Internal-id leakage:** The current body emits `Attached repo: <id>`, but D-3517 explicitly forbids shipping raw `attached_repo_id` in visible PR text. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- **Proof-doc drift:** If the PR body cites layers that `mix kiln.attach.prove` does not actually run, reviewer trust will drift immediately. [ASSUMED]
- **Preflight log replay in the PR body:** Phase 34 warnings belong in warning coverage and narrow explanatory cases only, not as a new boilerplate PR section. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reviewer summary for attached work [VERIFIED: codebase grep] | Ad hoc markdown parsing or full-request dumps [VERIFIED: codebase grep] | `SpecRevision` structured fields plus a small formatter in `Kiln.Attach.Delivery` [VERIFIED: codebase grep] | The structured fields already exist and survive draft promotion cleanly. [VERIFIED: codebase grep] |
| Proof ownership [VERIFIED: codebase grep] | A second Phase-35-only Mix task [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | `mix kiln.attach.prove` with an updated locked delegated list [VERIFIED: codebase grep] | One command is easier to cite, rerun, and audit. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| GitHub PR transport [VERIFIED: codebase grep] | Custom REST wrapper or shell-string concatenation [VERIFIED: codebase grep] | Existing `Kiln.GitHub.Cli.create_pr/2` argv wrapper over `gh pr create` [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create] | The wrapper already handles draft mode, explicit base/head/title/body, and long-body fallback without shell interpolation. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create] |

**Key insight:** Phase 35 is a contract-tightening phase, not an infrastructure phase. The codebase already has the persistence, delivery seam, and proof-task seam needed to ship it. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Reading The Wrong Source Of Truth
**What goes wrong:** The planner may try to build the PR body from `attached_repo` facts only, because the current `draft_pr_body/4` function only accepts repo/run/branch inputs. [VERIFIED: codebase grep]
**Why it happens:** `Kiln.Attach.Delivery` currently does not load `SpecRevision`, even though the run already links to it. [VERIFIED: codebase grep]
**How to avoid:** Load the run with the promoted request context or fetch the `SpecRevision` inside the delivery seam before formatting the body. [ASSUMED]
**Warning signs:** The resulting PR body cannot render `Acceptance criteria`, cannot conditionally omit `Out of scope`, or falls back to generic attached-repo language. [VERIFIED: codebase grep]

### Pitfall 2: Owning Proof Command No Longer Matches Milestone Claims
**What goes wrong:** `TRUST-04` or `UAT-06` gets claimed in docs and PR copy, but `mix kiln.attach.prove` still runs the old three-file list. [VERIFIED: codebase grep]
**Why it happens:** The proof task is hard-coded, and its test currently locks exactly three delegated invocations in order. [VERIFIED: codebase grep]
**How to avoid:** Treat `test/mix/tasks/kiln.attach.prove_test.exs` as a lock file for the milestone claim and update it in the same plan that changes the delegated list. [ASSUMED]
**Warning signs:** New continuity, brownfield-preflight, or PR-body tests exist, but `mix help kiln.attach.prove` and `kiln.attach.prove_test.exs` still mention only the original three layers. [VERIFIED: codebase grep]

### Pitfall 3: Reviewer Noise From Boundary Violations
**What goes wrong:** The PR body becomes a bot wall by replaying continuity context, warning panels, internal ids, or raw metadata. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
**Why it happens:** Phases 33 and 34 already produce continuity and warning surfaces, so it is tempting to paste them into the final handoff. [VERIFIED: .planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md] [VERIFIED: .planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md]
**How to avoid:** Keep the PR body limited to scoped request framing, explicit verification citations, branch/base facts, and one provenance footer. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
**Warning signs:** The body includes `attached_repo_id`, warning codes, JSON blobs, or more than one provenance marker. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

## Code Examples

Verified patterns from official and repo sources:

### `gh pr create` Supports The Exact Draft PR Contract Kiln Already Uses
```text
# Source: https://cli.github.com/manual/gh_pr_create
gh pr create --title "..." --body "..." --base main --head kiln/attach/... --draft
gh pr create --body-file body.md
```

### Thin Proof Command Delegation
```elixir
# Source: lib/mix/tasks/kiln.attach.prove.ex
def run(_args) do
  Enum.each(@proof_layers, &run_cmd/1)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 31 PR body uses `Why`, `What changed`, `Verification`, and `Kiln context` with placeholder verification copy plus raw attached-repo id. [VERIFIED: codebase grep] | Phase 35 context locks a compact `Summary`, `Acceptance criteria`, conditional `Out of scope`, explicit `Verification`, branch/base facts, and one `kiln-run:` footer. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | 2026-04-24 planning context for Phase 35. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | Reviewers get a repo-fitting handoff instead of a generic bot placeholder. [ASSUMED] |
| `mix kiln.attach.prove` currently delegates three layers: delivery happy path, safety gate, and `/attach` LiveView. [VERIFIED: codebase grep] | Phase 35 requires the same owning command to remain authoritative while covering continuity and representative brownfield warning/refusal claims precisely enough for `UAT-06`. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | 2026-04-24 milestone definition. [VERIFIED: .planning/REQUIREMENTS.md] | The delegated list must become the literal milestone proof surface, not just a carry-over from Phase 31. [ASSUMED] |

**Deprecated/outdated:**
- Generic lines like "Attach workspace was marked ready before delivery." as standalone PR verification evidence. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Visible `Attached repo: <id>` in reviewer-facing PR text. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Extending `test/kiln/attach/delivery_test.exs` is the cheapest place to lock the new PR-body contract. | Standard Stack / Validation Architecture | The plan may choose a slower integration-only proof shape than necessary. |
| A2 | `mix kiln.attach.prove` should add only the smallest extra delegated layer set needed to make continuity/preflight/body-contract claims literal. | Summary / Phase Requirements | The plan could under-cover `UAT-06` or over-expand the proof command. |
| A3 | Loading `SpecRevision` inside the delivery seam is the cleanest implementation route. | Common Pitfalls / Pattern 1 | The existing run preload path may already expose the needed fields in a cleaner way. |
| A4 | Reviewer trust will drift immediately if PR citations and delegated proof layers diverge. | Anti-Patterns / Common Pitfalls | The implementation could still work technically, but the product contract would become misleading. |

## Open Questions

1. **Has Phase 34 already landed its final proof file split before Phase 35 planning starts?**
   - What we know: `STATE.md` still shows Phase 34 as executing, while the repo already contains `test/kiln/attach/brownfield_preflight_test.exs` and `/attach` warning coverage. [VERIFIED: .planning/STATE.md] [VERIFIED: codebase grep]
   - What's unclear: whether the planner should rely on current filenames as stable, or re-check after Phase 34 closes. [ASSUMED]
   - Recommendation: Reconfirm the delegated proof filenames immediately before locking the Phase 35 plan so the PR citations and proof task stay aligned. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` [VERIFIED: command output] | Real draft PR creation path in `Kiln.GitHub.Cli` [VERIFIED: codebase grep] | ✓ [VERIFIED: command output] | `2.89.0` (`2026-03-26`) [VERIFIED: command output] | Worker and CLI tests can stub the runner, but real delivery still depends on `gh`. [VERIFIED: codebase grep] |
| `git` [VERIFIED: command output] | Branch validation, local branch creation, and push behavior [VERIFIED: codebase grep] | ✓ [VERIFIED: command output] | `2.41.0` [VERIFIED: command output] | No practical fallback for real delivery. [VERIFIED: codebase grep] |
| PostgreSQL on `:5432` [VERIFIED: command output] | DataCase / integration tests touching runs, specs, and attached repos [VERIFIED: codebase grep] | ✓ [VERIFIED: command output] | accepting connections [VERIFIED: command output] | None for repo-backed test execution. [VERIFIED: codebase grep] |
| Docker [VERIFIED: command output] | Broader shift-left flow from `AGENTS.md`, not the owning Phase 35 proof path [VERIFIED: AGENTS.md] | ✓ [VERIFIED: command output] | `29.3.1` [VERIFIED: command output] | Phase 35 proof should stay narrow and not require Docker-only gates. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |

**Missing dependencies with no fallback:**
- None discovered in this workspace for planning the phase. [VERIFIED: command output]

**Missing dependencies with fallback:**
- `just` is not installed locally, but `bash script/precommit.sh` remains the documented equivalent for final local verification after code changes. [VERIFIED: command output] [VERIFIED: AGENTS.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with LiveViewTest and Oban/DataCase support. [VERIFIED: codebase grep] |
| Config file | `mix.exs` plus standard `test/` support paths. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/kiln/attach/brownfield_preflight_test.exs test/kiln/attach/continuity_test.exs test/mix/tasks/kiln.attach.prove_test.exs` [ASSUMED] |
| Full suite command | `MIX_ENV=test mix kiln.attach.prove` [VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRUST-04 [VERIFIED: .planning/REQUIREMENTS.md] | Frozen draft PR body shows scoped summary, acceptance criteria, conditional boundary section, verification citations, branch/base facts, and omits raw `attached_repo_id`. [ASSUMED] | unit/integration [ASSUMED] | `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/integration/github_delivery_test.exs` [ASSUMED] | `test/kiln/attach/delivery_test.exs` ✅ [VERIFIED: codebase grep] |
| UAT-06 [VERIFIED: .planning/REQUIREMENTS.md] | One owning proof path covers attached delivery, continuity, and representative brownfield refusal or warning coverage. [VERIFIED: .planning/REQUIREMENTS.md] | task + unit/live [VERIFIED: codebase grep] | `MIX_ENV=test mix kiln.attach.prove` [VERIFIED: codebase grep] | `test/mix/tasks/kiln.attach.prove_test.exs` ✅ [VERIFIED: codebase grep] |

### Sampling Rate
- **Per task commit:** `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/mix/tasks/kiln.attach.prove_test.exs` [ASSUMED]
- **Per wave merge:** `MIX_ENV=test mix kiln.attach.prove` [VERIFIED: codebase grep]
- **Phase gate:** `MIX_ENV=test mix kiln.attach.prove` green, then broader repo gates remain optional follow-on verification rather than phase-owned proof. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] [VERIFIED: AGENTS.md]

### Wave 0 Gaps
- [ ] Update `test/kiln/attach/delivery_test.exs` to assert the final PR-body contract, including omission of raw `attached_repo_id`. [ASSUMED]
- [ ] Update `test/mix/tasks/kiln.attach.prove_test.exs` whenever the delegated layer list changes so the owning command stays authoritative. [VERIFIED: codebase grep]
- [ ] Reconcile `mix kiln.attach.prove` with `UAT-06` wording by delegating explicit continuity and brownfield-preflight coverage if the existing three-file list is judged insufficient after Phase 34 closes. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: codebase grep] | No auth feature change is in scope for this phase. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| V3 Session Management | no [VERIFIED: codebase grep] | No session behavior changes are in scope. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| V4 Access Control | yes [VERIFIED: codebase grep] | Keep same-repo request/run linkage checks such as `Runs.validate_attached_request/3` so PR handoff data cannot leak across attached repos. [VERIFIED: codebase grep] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | Reuse `Kiln.Attach.IntakeRequest` and Ecto validation for stored request fields; do not accept raw PR body blobs from the UI. [VERIFIED: codebase grep] |
| V6 Cryptography | no [VERIFIED: codebase grep] | No new cryptographic behavior is introduced by this phase. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |

### Known Threat Patterns for attached draft-PR handoff

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Internal metadata leakage into public reviewer text [VERIFIED: codebase grep] | Information Disclosure | Build the visible PR body from curated fields and omit raw `attached_repo_id`, JSON, and warning blobs. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] |
| Misleading verification claims [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] | Repudiation | Cite the exact owning command and delegated test files that actually run. [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md] [VERIFIED: codebase grep] |
| CLI argument/body injection risk [VERIFIED: codebase grep] | Tampering | Keep using `System.cmd`-style argv construction in `Kiln.GitHub.Cli` and `--body-file` fallback instead of shell string interpolation. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create] |

## Sources

### Primary (HIGH confidence)
- `lib/kiln/attach/delivery.ex` - current PR title/body generation, frozen snapshot shape, and visible placeholder verification/internal-id leakage. [VERIFIED: codebase grep]
- `lib/mix/tasks/kiln.attach.prove.ex` and `test/mix/tasks/kiln.attach.prove_test.exs` - owning proof command and locked delegated list. [VERIFIED: codebase grep]
- `lib/kiln/attach/intake.ex`, `lib/kiln/specs/spec_draft.ex`, `lib/kiln/specs/spec_revision.ex`, `lib/kiln/specs.ex`, `lib/kiln/runs.ex` - durable attached-request field flow from intake to promoted revision to run linkage. [VERIFIED: codebase grep]
- `test/kiln/attach/delivery_test.exs`, `test/kiln/attach/brownfield_preflight_test.exs`, `test/kiln/attach/continuity_test.exs`, `test/kiln_web/live/attach_entry_live_test.exs`, `test/integration/github_delivery_test.exs` - current proof surface and coverage seams. [VERIFIED: codebase grep]
- `https://cli.github.com/manual/gh_pr_create` - official `gh pr create` flags for `--draft`, `--title`, `--body`, and `--body-file`. [CITED: https://cli.github.com/manual/gh_pr_create]

### Secondary (MEDIUM confidence)
- `https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request?tool=cli` - GitHub Docs confirmation that draft PRs and explicit base/head/title/body creation are standard CLI flows. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request?tool=cli]

### Tertiary (LOW confidence)
- None. [VERIFIED: research session]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - The phase reuses existing repo seams and an official GitHub CLI path already present in code. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create]
- Architecture: HIGH - The data flow from intake to promoted revision to run to frozen snapshot is explicit in code and matches the locked context decisions. [VERIFIED: codebase grep] [VERIFIED: .planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md]
- Pitfalls: HIGH - The current placeholder PR body and locked proof task make the likely failure modes directly observable. [VERIFIED: codebase grep]

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 for repo-internal seams; re-check immediately if Phase 34 changes proof filenames before planning. [VERIFIED: .planning/STATE.md] [ASSUMED]
