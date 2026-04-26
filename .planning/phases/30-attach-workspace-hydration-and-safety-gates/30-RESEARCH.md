# Phase 30: Attach workspace hydration and safety gates - Research

**Researched:** 2026-04-24
**Domain:** Single-repo attach source resolution, writable workspace hydration, and pre-run refusal gates
**Confidence:** HIGH

<user_constraints>
## Locked Product Constraints

- Phase 30 owns `ATTACH-02`, `ATTACH-03`, and `TRUST-02`; it must not pull branch push / draft PR orchestration forward from Phase 31.
- The attach milestone is still single-repo only. Multi-root, fork-and-continue, clone-to-stack, and reference-repo behavior remain deferred.
- `/attach` already exists as the route-backed brownfield entry surface from Phase 29 and should become the place where source submission, validation feedback, and safe-next-step guidance live.
- Accepted sources for this phase are a local repo path, an existing local clone, and a GitHub URL.
- The outcome of Phase 30 is a safe, reusable writable workspace plus enough repo metadata for Phase 31 to create a run-scoped branch and draft PR.
- Dirty worktrees, detached HEADs, and missing GitHub push/PR prerequisites must be refused before Kiln mutates git state, with explicit remediation guidance rather than ambiguous failure.

## Scope Boundaries

- Do not implement multi-root workspaces, forks, clone-to-different-stack, or autonomy-policy tuning here.
- Do not create, push, or open PRs in this phase.
- Do not bypass trust gates by silently stashing, auto-cleaning, or working directly on unsafe operator state.
</user_constraints>

<codebase_findings>
## Current Codebase Reality

### Attach entry surface exists but is informational only

- `lib/kiln_web/live/attach_entry_live.ex` is a static orientation page with no form, no source parsing, and no persisted attach metadata.
- `test/kiln_web/live/attach_entry_live_test.exs` currently proves only the Phase 29 copy contract.

### Git / GitHub delivery seams already exist

- `lib/kiln/git.ex` already wraps `git ls-remote` and `git push` in a typed boundary.
- `lib/kiln/github/cli.ex` already wraps `gh pr create` and check-run polling and classifies `gh` auth / permission failures.
- `lib/kiln/github/push_worker.ex` already enforces that a `workspace_dir` must live under `:github_workspace_root` when configured. That is the strongest existing signal for how attached workspaces should be rooted and validated.

### No attach-repo metadata model exists yet

- `lib/kiln/runs/run.ex` tracks `github_delivery_snapshot`, but there is no schema for attached repository identity, resolved source, workspace path, default branch, or base branch.
- Nothing in `lib/kiln/runs.ex` or the current LiveViews can carry attach repo metadata from the UI into later run orchestration.

### Existing workspace handling is sandbox-centric, not repo-centric

- `lib/kiln/sandboxes/hydrator.ex` materializes CAS artifacts into an ephemeral workspace directory, but it does not model a persistent operator-owned repo workspace.
- The repo has `:github_workspace_root` in tests, but no first-class attach workspace root config yet for runtime use.

### Readiness and remediation patterns already exist

- `lib/kiln/operator_setup.ex` and the onboarding/templates surfaces already use explicit checklist-driven remediation language for missing `gh` auth, Docker, and provider setup.
- Phase 30 should reuse that "blocked, explorable, exact next action" posture instead of inventing a new failure UX.
</codebase_findings>

<recommended_architecture>
## Recommended Phase 30 Shape

### 1. Introduce an attach domain boundary, not ad hoc LiveView logic

Create a dedicated attach context for:

- source normalization and parsing
- repo identity resolution
- workspace root policy
- safety preflight evaluation
- attach session / metadata persistence

This keeps `AttachEntryLive` thin and makes Phase 31 reuse straightforward.

### 2. Separate "resolve source" from "hydrate workspace" from "refuse unsafe state"

The roadmap already decomposes the phase into three plans, and the codebase supports that split:

- `30-01`: parse and resolve one attach source into canonical repo identity
- `30-02`: create or reuse the writable workspace and persist run-scoped metadata
- `30-03`: apply safety gates against the resolved workspace before any later coding run

Trying to merge these into one plan would blur ownership and make verification weak.

### 3. Prefer a persistent attach workspace root under Kiln control

The safest match for the milestone is:

- one Kiln-managed root for attached workspaces
- one stable workspace per attached repo identity
- one future run-scoped branch inside that workspace in Phase 31

This matches the seed's persistent attach mental model and lines up with `PushWorker`'s existing root-constrained `workspace_dir` rule.

### 4. Canonical repo identity should be stable across source types

The attach resolver should converge local-path and GitHub-URL inputs into one metadata shape, including:

- source kind
- canonical repo root path
- repo slug / owner-name when known
- origin / upstream remote URLs
- default branch or current base branch
- workspace key / fingerprint

That shared shape is what Plan 30-02 can persist and Plan 31 can consume.

### 5. Refusal gates should be typed and actionable

The likely first-pass refusal categories are:

- dirty worktree
- detached HEAD
- missing GitHub CLI auth
- missing writable remote / unsupported remote topology
- source path missing or not a git repo
- GitHub URL not reachable / not resolvable to one repo

Each needs a stable code, exact operator copy, and a concrete remediation command or next step.
</recommended_architecture>

<verification_notes>
## Verification Implications

- Phase 30 needs both unit-style attach domain tests and LiveView tests for `/attach` because the phase introduces real submission state, refusal rendering, and next-step transitions.
- Local-path resolution and dirty/detached refusal behavior should be tested using temporary repos created inside tests.
- GitHub URL parsing and `gh` prerequisite failure should be tested with injected runners rather than live network calls.
- Because the phase is pre-run safety-critical, verification should prefer deterministic command boundaries and typed errors over browser-only proof.
</verification_notes>

<canonical_refs>
## Canonical References

### Milestone truth

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md`

### Prior attach phase

- `.planning/phases/29-attach-entry-surfaces/29-CONTEXT.md`
- `.planning/phases/29-attach-entry-surfaces/29-RESEARCH.md`
- `.planning/phases/29-attach-entry-surfaces/29-VERIFICATION.md`

### Existing implementation seams

- `lib/kiln_web/live/attach_entry_live.ex`
- `lib/kiln_web/live/onboarding_live.ex`
- `lib/kiln_web/live/templates_live.ex`
- `lib/kiln/git.ex`
- `lib/kiln/github/cli.ex`
- `lib/kiln/github/push_worker.ex`
- `lib/kiln/github/open_pr_worker.ex`
- `lib/kiln/operator_setup.ex`
- `lib/kiln/runs.ex`
- `lib/kiln/runs/run.ex`
- `config/config.exs`
- `config/runtime.exs`

### Test anchors

- `test/kiln_web/live/attach_entry_live_test.exs`
- `test/kiln/github/push_worker_test.exs`
- `test/kiln/github/open_pr_worker_test.exs`
- `test/integration/github_delivery_test.exs`
</canonical_refs>

<recommended_decomposition>
## Suggested Plan Decomposition

### `30-01-PLAN.md` — accept and validate local-path or GitHub-URL attach sources

- Turn `/attach` into a real attach source form using `to_form/2` and stable ids.
- Add an attach resolver boundary that accepts local paths and GitHub URLs, normalizes them, resolves repo roots, and returns typed validation errors.
- Persist enough attach session state to move from "informational attach page" to "resolved source ready for workspace hydration."

### `30-02-PLAN.md` — hydrate or reuse one writable attached workspace with run-scoped metadata

- Add a Kiln-managed attach workspace root and deterministic workspace keying.
- Clone or reuse a writable workspace from the resolved source, then persist repo metadata needed for future branch / PR work.
- Keep the workspace single-repo only and rooted under a known safe path.

### `30-03-PLAN.md` — refuse dirty, detached, or missing-prerequisite repo states with explicit remediation

- Evaluate the hydrated workspace for dirty state, detached HEAD, and GitHub readiness before any later execution path can proceed.
- Surface stable refusal states on `/attach` with exact remediation commands and links.
- Reuse existing readiness/remediation language patterns from operator setup instead of ad hoc error text.
</recommended_decomposition>

---
*Phase: 30-attach-workspace-hydration-and-safety-gates*
*Research completed: 2026-04-24*
