# Phase 31: Draft PR trust ramp and attach proof - Research

**Researched:** 2026-04-24  
**Domain:** Attached-repo branch naming, push/PR orchestration, and proof layering on existing Kiln attach/GitHub seams  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Carry-forward constraints from earlier phases

- **D-3101:** Keep the Phase 29 and Phase 30 product boundary intact: attach remains a **single-repo** brownfield path, `/attach` remains the route-backed trust surface, and the operator should see a conservative draft PR inspection point rather than a new approval workflow.
- **D-3102:** Reuse the Phase 30 attach contract as the only input to branch / push / PR work: attached repo identity, managed `workspace_path`, `repo_slug`, `remote_url`, and `base_branch` come from `Kiln.Attach` persistence and preflight, not from reparsing operator input or re-discovering repo facts ad hoc.
- **D-3103:** Preserve bounded autonomy. Draft PR default is the trust ramp; it must **not** become a hidden human gate, pause screen, or alternate state machine.

### Branch naming contract

- **D-3104:** Use a Kiln-owned, deterministic, human-readable branch namespace: `kiln/attach/<intent-slug>-r<short_run_id>`.
- **D-3105:** The machine-stable suffix comes from immutable run identity and is the durable discriminator. The slug is descriptive only and must not be used as the durable key.
- **D-3106:** Persist or freeze the chosen branch name once per run so retries and partial push / PR failures reuse the same branch instead of inventing new names.
- **D-3107:** Sanitize and truncate branch names to a portable character set and validate with `git check-ref-format --branch` before creation.
- **D-3108:** Do not use human-first repo-native branch names like `feature/foo` for Phase 31. They blur ownership, increase collision risk, and weaken idempotent external-op behavior.

### Draft PR trust posture

- **D-3109:** First attached-repo delivery opens a **draft PR by default**. This is the conservative inspection point for brownfield work and the visible trust ramp for `TRUST-01` and `TRUST-03`.
- **D-3110:** Use a **medium factual PR template**, not a noisy reassurance wall and not a bare metadata dump.
- **D-3111:** PR titles should stay explicit and restrained: `draft: <scope>: <change>` or `draft: <imperative outcome> (<short id>)`, as long as they remain obviously draft and readable in GitHub lists.
- **D-3112:** PR bodies should be limited to compact sections such as `Why`, `What changed`, `Verification`, and `Kiln context`.
- **D-3113:** The first line should say plainly that Kiln opened this as a draft attached-repo PR. Do not claim merge-readiness, safety certainty, or “fully verified” confidence in the draft copy.
- **D-3114:** Include only frozen, durable facts in the PR body: branch, base branch, run/spec/check references when they are real and stable. Keep structured machine metadata internal; emit human prose plus a short fact block.
- **D-3115:** Include at most one lightweight machine-generated marker or footer for provenance. Avoid raw JSON, YAML, or opaque metadata blobs in the PR body.

### Proof contract for UAT-05

- **D-3116:** Add one owning repository-level proof command for attach delivery, following the existing `mix kiln.first_run.prove` pattern rather than scattering proof responsibility across multiple uncited test invocations.
- **D-3117:** The owning command should stay thin and delegate to a fixed set of lower-level proof layers rather than becoming a second custom test framework.
- **D-3118:** The proof contract must cover three things together:
  - one hermetic attach happy path through branch naming, push orchestration, and draft PR creation
  - the explicit refusal-path set that protects attached repos from unsafe delivery preconditions
  - one focused operator-surface proof that ready vs blocked attach states stay honest
- **D-3119:** LiveView proof is supportive, not primary. Browser-heavy proof is out of proportion for this phase because the safety and delivery semantics live mainly in the domain and worker boundaries.

### Claude's Discretion

- Exact slug source for `<intent-slug>` as long as it is stable enough for one run, human-readable, and never the durable identity.
- Exact PR section wording and formatting, as long as the tone stays plain, conservative, and factual.
- Exact proof command name and delegated test list, as long as one explicit owning command exists and the subordinate layers stay hermetic.

### Deferred Ideas (OUT OF SCOPE)

- Multi-root or monorepo attach behavior
- Fork-and-continue flows
- Clone-to-stack flows
- Human approval gates or synchronous PR approval UI
- Rich bot PR dashboards or heavy metadata sections in draft PR bodies
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRUST-01 | First attached-repo runs default to creating a branch and opening a draft PR against the attached repo's upstream rather than behaving like the existing greenfield-first path. [VERIFIED: codebase grep] | Use a run-scoped attach delivery orchestrator that freezes one branch name, enqueues `Kiln.GitHub.PushWorker`, and then enqueues `Kiln.GitHub.OpenPRWorker` with `"draft" => true`. [VERIFIED: codebase grep] |
| TRUST-03 | Attached-repo execution preserves bounded autonomy: no synchronous approval gate is introduced, but the operator gets a conservative inspection point through the draft PR before merge. [VERIFIED: codebase grep] | Keep delivery asynchronous and worker-driven; the draft PR is the output, not a pause state. `gh pr create --draft` and GitHub draft semantics satisfy the inspection posture without introducing a new state machine. [CITED: https://cli.github.com/manual/gh_pr_create] [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests] |
| GIT-05 | Attached-repo runs can push the run-scoped branch and open a draft PR through the existing git/gh integration using repo metadata captured by the attach flow. [VERIFIED: codebase grep] | Read `workspace_path`, `repo_slug`, `remote_url`, and `base_branch` from `Kiln.Attach`/Phase 30 persistence and route the side effects through the existing `Kiln.Git`, `Kiln.GitHub.PushWorker`, and `Kiln.GitHub.OpenPRWorker` seams. [VERIFIED: codebase grep] |
| UAT-05 | The repository contains one explicit automated proof path for attach existing repo happy path and refusal cases, and the owning verification command is cited in the milestone artifacts. [VERIFIED: codebase grep] | Follow the `Mix.Tasks.Kiln.FirstRun.Prove` shape: one thin owning Mix task that delegates to one hermetic attach delivery test layer, existing refusal coverage, and one focused LiveView test layer. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 31 should be implemented as a thin attach-delivery orchestration layer over existing persisted attach facts and existing GitHub workers, not as a new transport stack. Phase 30 already gives Kiln a durable `attached_repos` row with `workspace_path`, `repo_slug`, `remote_url`, `default_branch`, and `base_branch`, and a typed `SafetyGate` that marks attached repos `:ready` or `:blocked`. `PushWorker` and `OpenPRWorker` already provide the durable external-operation pattern this phase needs. [VERIFIED: codebase grep]

The main missing contract is per-run delivery identity. The attached repo row is keyed by repo identity and workspace reuse, while `runs.github_delivery_snapshot` is already the repo’s per-run storage for GitHub delivery facts. Phase 31 should freeze branch identity once per run, persist it on the run snapshot, create or switch the local branch inside the managed workspace, push via CAS-guarded `PushWorker`, then open a draft PR with frozen title/body/base/head attributes through `OpenPRWorker`. [VERIFIED: codebase grep]

The proof shape should stay layered and thin. One owning Mix task should delegate to a hermetic attach happy-path suite, existing refusal-path coverage from `SafetyGate`, and one focused LiveView proof that `/attach` still distinguishes honest ready vs blocked states. That satisfies `UAT-05` without turning Phase 31 into a browser-heavy test phase. [VERIFIED: codebase grep]

**Primary recommendation:** Freeze branch and PR identity per run in `runs.github_delivery_snapshot`, orchestrate delivery through `Kiln.Attach` + existing GitHub workers, and add one thin `mix kiln.attach.prove`-style command that delegates to hermetic happy-path, refusal, and focused LiveView proof layers. [VERIFIED: codebase grep]

## Project Constraints (from CLAUDE.md)

- Use existing dependencies and seams; do not introduce new HTTP clients or GitHub libraries for this phase. `Req` is the approved HTTP client, but Phase 31 can stay on the existing `git`/`gh` CLI boundaries. [VERIFIED: codebase grep]
- Keep bounded-autonomy and external-side-effect idempotency intact; external git/GitHub effects should continue to flow through `external_operations`-backed workers instead of ad hoc shell calls from UI code. [VERIFIED: codebase grep]
- Keep Phoenix/LiveView tests focused on stable element ids and outcomes rather than raw HTML text dumps; Phase 31’s operator proof should extend the existing `/attach` test style. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Attach repo identity lookup | API / Backend | Database / Storage | `Kiln.Attach` and `attached_repos` already own persisted repo/workspace metadata. [VERIFIED: codebase grep] |
| Ready vs blocked trust surface | Frontend Server (SSR) | API / Backend | `/attach` renders the state, but `SafetyGate` owns the truth of readiness and refusal typing. [VERIFIED: codebase grep] |
| Branch-name derivation and freezing | API / Backend | Database / Storage | The name must be deterministic per run and durable across retries, which fits a backend command plus run snapshot persistence. [VERIFIED: codebase grep] |
| Local branch creation/switch | API / Backend | — | This is a workspace-side git mutation against the managed repo path. [VERIFIED: codebase grep] |
| Remote push CAS enforcement | API / Backend | Database / Storage | `PushWorker` already owns `external_operations` intent recording and `git ls-remote` CAS behavior. [VERIFIED: codebase grep] |
| Draft PR creation | API / Backend | Database / Storage | `OpenPRWorker` already owns frozen PR attrs and durable completion semantics. [VERIFIED: codebase grep] |
| Proof command orchestration | API / Backend | — | The repo already uses Mix tasks as thin owners for proof stacks. [VERIFIED: codebase grep] |

## Standard Stack

No new Hex packages are recommended for Phase 31. Reuse the existing attach, git, and GitHub seams plus the installed `git` and `gh` CLIs. [VERIFIED: codebase grep]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Kiln.Attach` + `Kiln.Attach.AttachedRepo` | repo-local | Public boundary for attached-repo lookup and persisted workspace/base-branch metadata. [VERIFIED: codebase grep] | Phase 30 already made this the durable attach contract; Phase 31 should consume it rather than rediscover repo facts. [VERIFIED: codebase grep] |
| `Kiln.GitHub.PushWorker` | repo-local | Durable `git push` with root allowlist and CAS precondition. [VERIFIED: codebase grep] | It already records `external_operations` intents, reuses idempotency keys, and classifies terminal push failures. [VERIFIED: codebase grep] |
| `Kiln.GitHub.OpenPRWorker` | repo-local | Durable `gh pr create` with frozen attrs and duplicate suppression. [VERIFIED: codebase grep] | It already persists frozen PR attrs and treats auth/permission failures as semantic terminal cancels. [VERIFIED: codebase grep] |
| `runs.github_delivery_snapshot` | repo-local | Per-run frozen delivery facts and downstream GitHub status state. [VERIFIED: codebase grep] | It is already the run-scoped GitHub delivery store; it is the right place to freeze branch and PR identity for retries. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Kiln.Git` | repo-local | Typed git helper boundary for `ls-remote`, push-intent payloads, and push-failure classification. [VERIFIED: codebase grep] | Use for CAS inputs, failure typing, and any new attach-delivery git helper added in this phase. [VERIFIED: codebase grep] |
| `Kiln.GitHub.Cli` | repo-local | Typed `gh` boundary for PR creation and error classification. [VERIFIED: codebase grep] | Use for final PR creation and any attach-proof stubs around CLI behavior. [VERIFIED: codebase grep] |
| `git` CLI | 2.41.0 installed | Validate branch refs, create/switch the local work branch, and push. [VERIFIED: codebase grep] [VERIFIED: git --version] | Use for branch-name validation with `git check-ref-format --branch` and local workspace mutation. `git check-ref-format` explicitly validates whether a branch name is acceptable. [CITED: https://git-scm.com/docs/git-check-ref-format] |
| `gh` CLI | 2.89.0 installed | Create the draft PR. [VERIFIED: gh --version] | Use with explicit `--title`, `--body`, `--base`, `--head`, and `--draft`; the manual documents these flags and warns that `gh pr create` may otherwise prompt or push. [CITED: https://cli.github.com/manual/gh_pr_create] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Freeze branch/PR identity on `runs.github_delivery_snapshot` | Write per-run branch fields onto `attached_repos` | Reject this for Phase 31. `attached_repos` is keyed by stable repo identity and workspace reuse, while `github_delivery_snapshot` is already run-scoped delivery state. Mixing per-run branch data into `attached_repos` would blur lifetimes. [VERIFIED: codebase grep] |
| Explicit push first, then `gh pr create --head ... --base ...` | Let `gh pr create` decide where to push or whether to fork | Reject this for Phase 31. The `gh` manual says `gh pr create` may prompt for push/fork behavior unless `--head` is provided, which conflicts with bounded, explicit orchestration. [CITED: https://cli.github.com/manual/gh_pr_create] |
| Reuse Phase 30 refusal coverage | Recheck repo safety ad hoc during PR copy/UI code | Reject this for Phase 31. The repo already has a typed `SafetyGate` boundary and `/attach` truth surface; duplicating those checks in UI copy or PR assembly would drift. [VERIFIED: codebase grep] |

**Installation:**
```bash
# No new Hex deps or npm packages recommended for Phase 31.
# External commands already present on this machine:
git --version
gh --version
```

**Version verification:** `git --version` returned `git version 2.41.0`, `gh --version` returned `gh version 2.89.0 (2026-03-26)`, and `mix --version` reported Erlang/OTP 28 on this machine. [VERIFIED: git --version] [VERIFIED: gh --version] [VERIFIED: mix --version]

## Architecture Patterns

### System Architecture Diagram

```text
Attached repo already marked ready by Phase 30
    |
    v
Kiln.Attach fetches attached repo row
    |
    v
Attach delivery orchestrator
    |-- derive + sanitize + validate branch name
    |-- freeze branch/base/title/body on run snapshot
    |-- create or switch local branch in managed workspace
    v
Kiln.GitHub.PushWorker
    |-- fetch_or_record_intent("...:git_push")
    |-- git ls-remote CAS check
    |-- git push origin refs/heads/<branch>
    v
Kiln.GitHub.OpenPRWorker
    |-- fetch_or_record_intent("...:gh_pr_create")
    |-- gh pr create --base <base> --head <branch> --draft
    v
runs.github_delivery_snapshot updated with branch + PR facts
    |
    v
Focused proof command delegates:
  happy-path integration -> refusal coverage -> attach LiveView proof
```

### Recommended Project Structure

```text
lib/
├── kiln/
│   ├── attach/
│   │   ├── delivery.ex         # New thin attach-specific orchestration boundary
│   │   ├── attached_repo.ex    # Existing durable repo/workspace identity
│   │   ├── safety_gate.ex      # Existing refusal contract reused unchanged
│   │   └── workspace_manager.ex
│   ├── git.ex                  # Existing git helper boundary; small helper additions fit here
│   └── github/
│       ├── push_worker.ex      # Existing durable push worker
│       └── open_pr_worker.ex   # Existing durable PR worker
└── mix/tasks/
    └── kiln.attach.prove.ex    # New thin owning proof command

test/
├── integration/
│   └── attach_delivery_test.exs
├── kiln/
│   ├── attach/
│   │   └── delivery_test.exs
│   └── github/
│       ├── push_worker_test.exs
│       └── open_pr_worker_test.exs
└── mix/tasks/
    └── kiln.attach.prove_test.exs
```

### Pattern 1: Freeze per-run delivery identity before external side effects

**What:** Read the repo/workspace/base-branch facts from `Kiln.Attach`, derive one canonical branch name, then write branch/base/title/body metadata to `runs.github_delivery_snapshot` before enqueueing push/PR work. [VERIFIED: codebase grep]

**When to use:** Any attached-repo run that is about to mutate git state or create a PR. [VERIFIED: codebase grep]

**Why:** `attached_repos` is durable repo identity, while `github_delivery_snapshot` is already the run-scoped delivery surface. Freezing once prevents retry drift and keeps `PushWorker`/`OpenPRWorker` payloads reproducible. [VERIFIED: codebase grep]

**Example:**
```elixir
# Source: local codebase + Phase 31 context
delivery = %{
  "attach" => %{
    "attached_repo_id" => attached_repo.id,
    "branch" => branch_name,
    "base_branch" => attached_repo.base_branch,
    "workspace_path" => attached_repo.workspace_path,
    "repo_slug" => attached_repo.repo_slug,
    "frozen" => true
  }
}

{:ok, _run} = Kiln.Runs.promote_github_snapshot(run.id, delivery)
```
[VERIFIED: codebase grep]

### Pattern 2: Keep push and PR as separate durable operations

**What:** Create/switch the local branch first, then call `PushWorker`, then call `OpenPRWorker` with explicit `head`, `base`, and `draft`. [VERIFIED: codebase grep]

**When to use:** The standard attached-repo happy path. [VERIFIED: codebase grep]

**Why:** `PushWorker` already owns CAS and retry behavior, and `OpenPRWorker` already owns frozen PR attrs and duplicate suppression. The `gh` CLI manual also documents that `gh pr create` may otherwise prompt or push unless `--head` is given. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create]

**Example:**
```elixir
# Source: local codebase
push_args = %{
  "idempotency_key" => "run:#{run.id}:stage:#{stage.id}:git_push",
  "run_id" => run.id,
  "stage_id" => stage.id,
  "workspace_dir" => attached_repo.workspace_path,
  "remote" => "origin",
  "refspec" => "refs/heads/#{branch_name}",
  "expected_remote_sha" => expected_sha,
  "local_commit_sha" => local_sha
}

pr_args = %{
  "idempotency_key" => "run:#{run.id}:stage:#{stage.id}:gh_pr_create",
  "run_id" => run.id,
  "stage_id" => stage.id,
  "title" => title,
  "body" => body,
  "base" => attached_repo.base_branch,
  "head" => branch_name,
  "draft" => true,
  "reviewers" => []
}
```
[VERIFIED: codebase grep]

### Pattern 3: Treat proof as one owner over smaller layers

**What:** Implement one Mix task that re-enables and delegates to a fixed attach-proof stack, mirroring `mix kiln.first_run.prove`. [VERIFIED: codebase grep]

**When to use:** `UAT-05` and milestone verification citation. [VERIFIED: codebase grep]

**Example:**
```elixir
# Source: local codebase pattern from Mix.Tasks.Kiln.FirstRun.Prove
def run(_args) do
  run_cmd(["env", "MIX_ENV=test", "mix", "test", "test/integration/attach_delivery_test.exs"])
  run_cmd(["env", "MIX_ENV=test", "mix", "test", "test/kiln/attach/safety_gate_test.exs"])
  run_cmd(["env", "MIX_ENV=test", "mix", "test", "test/kiln_web/live/attach_entry_live_test.exs"])
end
```
[VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Per-attempt branch minting:** If retries can derive a fresh branch name, push and PR idempotency become meaningless. Freeze once per run. [VERIFIED: codebase grep]
- **Using `attached_repos` for per-run branch state:** That row is for durable repo identity/workspace reuse, not transient run delivery facts. [VERIFIED: codebase grep]
- **Letting `gh pr create` push or fork implicitly:** The CLI may prompt or push unless `--head` is explicit. Keep push orchestration separate and deterministic. [CITED: https://cli.github.com/manual/gh_pr_create]
- **Rechecking safety with bespoke logic:** Dirty worktrees, detached HEADs, missing GitHub auth, and missing GitHub remote topology are already Phase 30 refusal cases and must remain the canonical guardrail set. [VERIFIED: codebase grep]
- **PR copy that overclaims confidence:** GitHub draft PRs are explicitly for work-in-progress and are not mergeable until ready for review. Keep copy factual. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Push retry/idempotency | Ad hoc `System.cmd("git", ...)` push flow in new attach code | `Kiln.GitHub.PushWorker` + `Kiln.Git` CAS helpers | The worker already has `external_operations`, root allowlisting, terminal failure classes, and replay suppression. [VERIFIED: codebase grep] |
| Draft PR creation | Custom GitHub REST client or UI-side shell-out | `Kiln.GitHub.OpenPRWorker` + `Kiln.GitHub.Cli.create_pr/2` | The worker already freezes PR attrs and handles auth/permission failures as typed cancels. [VERIFIED: codebase grep] |
| Branch-name validation | Hand-written regex only | `git check-ref-format --branch` after sanitization | Git documents `git check-ref-format --branch` as the branch-name validity check and notes branch-name rules are stricter than general refs in some cases. [CITED: https://git-scm.com/docs/git-check-ref-format] |
| Attach refusal logic | Duplicate dirty/detached/auth/remote checks inside delivery code | `Kiln.Attach.SafetyGate` + existing `/attach` contract | The refusal set is already typed, tested, and operator-visible from Phase 30. [VERIFIED: codebase grep] |

**Key insight:** Phase 31 is a composition phase. The codebase already contains the durable worker, run snapshot, and refusal primitives; the missing value is frozen per-run delivery identity plus a thin orchestration boundary. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Branch identity drifts across retries

**What goes wrong:** A retry after local branch creation, push failure, or PR failure generates a second branch name and opens a second PR candidate. [VERIFIED: codebase grep]

**Why it happens:** The slug is human-readable but not durable, and the current workers only dedupe exact payloads and exact idempotency keys. [VERIFIED: codebase grep]

**How to avoid:** Freeze the chosen branch name once per run before enqueueing either worker, and reuse that frozen branch for every later attempt. [VERIFIED: codebase grep]

**Warning signs:** Different `head` branches appear in repeated `gh_pr_create` intents for the same run, or the same run snapshot lacks a single canonical branch field. [VERIFIED: codebase grep]

### Pitfall 2: `gh pr create` becomes an implicit push/fork step

**What goes wrong:** PR creation prompts, pushes, or tries to fork, which breaks non-interactive orchestration. [CITED: https://cli.github.com/manual/gh_pr_create]

**Why it happens:** The `gh` manual says `gh pr create` may ask where to push and offer forking behavior when the branch is not fully pushed, unless `--head` is used. [CITED: https://cli.github.com/manual/gh_pr_create]

**How to avoid:** Push first through `PushWorker`, then call `OpenPRWorker` with explicit `--head`, `--base`, `--title`, `--body`, and `--draft`. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create]

**Warning signs:** Tests need to stub interactive behavior, or production logs show `gh` prompting/failing before PR creation. [CITED: https://cli.github.com/manual/gh_pr_create]

### Pitfall 3: Phase 30 refusal coverage regresses silently

**What goes wrong:** Happy-path delivery tests pass, but dirty worktrees, detached HEADs, or missing GitHub prerequisites stop being covered as part of the milestone proof. [VERIFIED: codebase grep]

**Why it happens:** The proof focus shifts to branch/push/PR work and drops the refusal cases that made attached repos safe in the first place. [VERIFIED: codebase grep]

**How to avoid:** Keep `test/kiln/attach/safety_gate_test.exs` in the owning proof command and cite it as part of the milestone proof stack. [VERIFIED: codebase grep]

**Warning signs:** The new proof task only runs happy-path integration and LiveView tests, or milestone docs stop citing refusal coverage. [VERIFIED: codebase grep]

### Pitfall 4: Per-run state is stored on the wrong entity

**What goes wrong:** Branch or PR facts overwrite durable attach metadata and bleed across later runs on the same attached repo. [VERIFIED: codebase grep]

**Why it happens:** `attached_repos` and `runs.github_delivery_snapshot` both look like possible homes for delivery state, but they have different lifetimes. [VERIFIED: codebase grep]

**How to avoid:** Keep repo/workspace identity on `attached_repos` and run-scoped delivery state on `runs.github_delivery_snapshot`. [VERIFIED: codebase grep]

**Warning signs:** A second run on the same attached repo sees stale branch names or PR numbers from the first run before it has created anything. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from existing repo seams and official docs:

### Branch-name validation shell shape
```bash
git check-ref-format --branch "kiln/attach/${intent_slug}-r${short_run_id}"
```
Source: Git documents `git check-ref-format --branch` as the validity check for branch names. [CITED: https://git-scm.com/docs/git-check-ref-format]

### Draft PR CLI shape
```bash
gh pr create \
  --title "$TITLE" \
  --body "$BODY" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH_NAME" \
  --draft
```
Source: `gh pr create` documents `--title`, `--body`, `--base`, `--head`, and `--draft`, and notes that `--head` skips implicit fork/push behavior. [CITED: https://cli.github.com/manual/gh_pr_create]

### Existing frozen PR attr map shape
```elixir
%{
  "title" => title,
  "body" => body,
  "base" => base_branch,
  "head" => branch_name,
  "draft" => true,
  "reviewers" => []
}
```
Source: `Kiln.GitHub.OpenPRWorker.parse_args/1` and `Kiln.GitHub.Cli.create_pr/2` already expect this frozen attribute shape. [VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Greenfield-first delivery assumes repo state owned by the run | Attached-repo delivery reuses one managed workspace plus typed trust gates before git mutation | Phase 30, 2026-04-24 [VERIFIED: codebase grep] | Phase 31 can focus on branch/push/PR orchestration instead of source resolution or safety gating. [VERIFIED: codebase grep] |
| Interactive `gh pr create` behavior may choose push/fork/base implicitly | Explicit `--base`, `--head`, `--title`, `--body`, and `--draft` arguments | Current `gh` manual, checked 2026-04-24 [CITED: https://cli.github.com/manual/gh_pr_create] | Better fit for bounded, replay-safe orchestration. [CITED: https://cli.github.com/manual/gh_pr_create] |
| Human review is requested immediately on ordinary PRs | Draft PRs are explicitly work-in-progress and not mergeable until marked ready | Current GitHub Docs, checked 2026-04-24 [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests] | Matches Phase 31’s trust ramp without inventing a separate approval system. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests] |

**Deprecated/outdated:**
- Interactive or implicit PR creation flows for attached repos are out of posture for this phase because they hide push/fork choices and weaken deterministic retries. [CITED: https://cli.github.com/manual/gh_pr_create]
- Storing attach delivery identity only in mutable UI state is out of posture because the repo already has durable run snapshot storage and durable worker idempotency semantics. [VERIFIED: codebase grep]

## Likely Plan Slices

1. **`31-01-PLAN.md` — add run-scoped branch + draft PR orchestration for attached repos**  
   Use `Kiln.Attach` as the single input boundary, freeze delivery identity on the run snapshot, validate branch names with `git check-ref-format --branch`, create/switch the local branch inside the managed workspace, then reuse `PushWorker` and `OpenPRWorker` with explicit frozen payloads. [VERIFIED: codebase grep] [CITED: https://git-scm.com/docs/git-check-ref-format] [CITED: https://cli.github.com/manual/gh_pr_create]

2. **`31-02-PLAN.md` — add attach happy-path and refusal-case proof coverage and reconcile planning SSOT**  
   Add one thin owning Mix task, one hermetic attach delivery happy-path suite, keep `SafetyGate` refusal coverage inside that proof stack, add a focused `/attach` LiveView proof, and cite the owning command in milestone artifacts. [VERIFIED: codebase grep]

## Assumptions Log

All material claims in this research were verified in the current codebase, from installed tool versions, or from official Git/GitHub documentation. No user-confirmation assumptions remain. [VERIFIED: codebase grep] [VERIFIED: git --version] [VERIFIED: gh --version] [CITED: https://git-scm.com/docs/git-check-ref-format] [CITED: https://cli.github.com/manual/gh_pr_create] [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests]

## Open Questions (RESOLVED)

1. **What exact source should produce `<intent-slug>`?**  
Decision: derive the preferred human label from the run-owned intent text first, then fall back in order to any stable workflow/spec summary already frozen on the run, then to the attached repo slug, and finally to the constant `attach-update` when no clean text exists. The slug remains descriptive-only; the durable discriminator is still the immutable run-derived suffix per D-3105. [VERIFIED: codebase grep]  
Planning impact: `31-01-PLAN.md` should implement a pure helper that accepts the preferred human label plus fallback inputs, normalizes the winning label, and always pairs it with the immutable run suffix. [VERIFIED: codebase grep]

2. **Where should local branch creation live?**  
Decision: keep orchestration in `Kiln.Attach.Delivery` and add only a narrow branch-create/switch helper on `Kiln.Git` for the shell interaction itself. `Kiln.Attach.Delivery` remains the owner of delivery sequencing and frozen payload assembly; `Kiln.Git` remains the owner of typed git command execution. [VERIFIED: codebase grep]  
Planning impact: `31-01-PLAN.md` should place branch-freezing and sequencing in `lib/kiln/attach/delivery.ex`, while `lib/kiln/git.ex` only gains the minimal helper surface needed to validate and create/switch the local branch inside the managed workspace. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `git` | Branch validation, local branch creation, push | ✓ | 2.41.0 | None for this phase. [VERIFIED: git --version] |
| `gh` | Draft PR creation | ✓ | 2.89.0 (2026-03-26) | None for this phase; the repo’s PR boundary is already `gh`-based. [VERIFIED: gh --version] [VERIFIED: codebase grep] |
| `mix` | Owning proof command | ✓ | OTP 28 runtime present | None. [VERIFIED: mix --version] |
| `docker` | Not required for core Phase 31 proof stack, but available for broader project gates | ✓ | 29.3.1 | Proof task can stay hermetic and avoid Docker dependency. [VERIFIED: docker --version] |

**Missing dependencies with no fallback:**
- None found on this machine. [VERIFIED: git --version] [VERIFIED: gh --version] [VERIFIED: mix --version]

**Missing dependencies with fallback:**
- None found on this machine. [VERIFIED: git --version] [VERIFIED: gh --version] [VERIFIED: mix --version]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix LiveViewTest. [VERIFIED: codebase grep] |
| Config file | none — repo uses normal Mix/ExUnit conventions from app code and test paths. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/integration/attach_delivery_test.exs --max-failures=1` after implementation. [VERIFIED: codebase grep] |
| Full suite command | `mix kiln.attach.prove` after implementation. [VERIFIED: codebase grep] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRUST-01 | Attached repo run freezes one branch name, pushes it, and opens a draft PR. [VERIFIED: codebase grep] | integration | `mix test test/integration/attach_delivery_test.exs --max-failures=1` | ❌ Wave 0 |
| TRUST-03 | Draft PR remains an output trust ramp, not a new pause state, and uses factual copy. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests] | unit/integration | `mix test test/kiln/attach/delivery_test.exs --max-failures=1` | ❌ Wave 0 |
| GIT-05 | Existing worker seams are reused with frozen payloads and explicit `head`/`base`. [VERIFIED: codebase grep] | unit | `mix test test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs --max-failures=1` | ✅ |
| UAT-05 | One owning proof command delegates happy path, refusal cases, and focused LiveView proof. [VERIFIED: codebase grep] | unit + mixed | `mix test test/mix/tasks/kiln.attach.prove_test.exs --max-failures=1` | ❌ Wave 0 |
| TRUST-02 carry-forward | Dirty worktree, detached HEAD, missing GitHub auth, and missing GitHub remote topology stay covered in the owning proof path. [VERIFIED: codebase grep] | unit | `mix test test/kiln/attach/safety_gate_test.exs --max-failures=1` | ✅ |
| Honest attach surface | `/attach` still renders ready vs blocked states honestly. [VERIFIED: codebase grep] | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs --max-failures=1` | ✅ |

### Sampling Rate

- **Per task commit:** `mix test <touched-files> --max-failures=1` and, for the proof-task work, `mix test test/mix/tasks/kiln.attach.prove_test.exs --max-failures=1`. [VERIFIED: codebase grep]
- **Per wave merge:** `mix kiln.attach.prove`. [VERIFIED: codebase grep]
- **Phase gate:** `mix kiln.attach.prove` green before `/gsd-verify-work`. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] `test/integration/attach_delivery_test.exs` — hermetic happy path covering frozen branch naming, push orchestration, and draft PR creation. [VERIFIED: codebase grep]
- [ ] `test/kiln/attach/delivery_test.exs` — focused delivery-orchestrator unit coverage for branch freezing and payload assembly. [VERIFIED: codebase grep]
- [ ] `test/mix/tasks/kiln.attach.prove_test.exs` — thin owning proof-command contract. [VERIFIED: codebase grep]
- [ ] `lib/mix/tasks/kiln.attach.prove.ex` — owning proof command to cite in milestone artifacts. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Operator auth is out of scope for v1; Phase 31 consumes existing `gh auth status` readiness rather than building auth flows. [VERIFIED: codebase grep] |
| V3 Session Management | no | No new user session surface is introduced. [VERIFIED: codebase grep] |
| V4 Access Control | yes | `PushWorker` already enforces `workspace_dir` confinement under `:github_workspace_root`; Phase 31 should keep all branch mutations inside the managed attach workspace root. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Sanitize/truncate branch names, validate with `git check-ref-format --branch`, and only emit frozen factual PR fields from trusted attach/run state. [CITED: https://git-scm.com/docs/git-check-ref-format] [VERIFIED: codebase grep] |
| V6 Cryptography | no | No new cryptographic primitive is introduced; reuse existing UUID/run-id and worker idempotency patterns only. [VERIFIED: codebase grep] |

### Known Threat Patterns for attach delivery

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Branch-name injection or invalid refs | Tampering | Sanitize to a narrow portable character set, truncate, then validate with `git check-ref-format --branch` before local branch creation. [CITED: https://git-scm.com/docs/git-check-ref-format] |
| Workspace escape during git mutation | Elevation of privilege | Reuse the managed workspace root and `PushWorker.validate_workspace_dir/1` root allowlist. [VERIFIED: codebase grep] |
| Duplicate external side effects on retry | Tampering | Keep `git_push` and `gh_pr_create` inside `external_operations`-backed workers with frozen payloads and idempotency keys. [VERIFIED: codebase grep] |
| Premature mutation of unsafe repo state | Tampering | Preserve Phase 30 `SafetyGate` refusal coverage in the proof stack and do not bypass it in delivery code. [VERIFIED: codebase grep] |
| Overstated trust in bot-generated output | Repudiation | Use factual draft PR copy and rely on GitHub draft semantics rather than readiness claims. [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests] |

## Sources

### Primary (HIGH confidence)

- Local codebase grep/read of:
  - `lib/kiln/attach.ex`
  - `lib/kiln/attach/attached_repo.ex`
  - `lib/kiln/attach/workspace_manager.ex`
  - `lib/kiln/attach/safety_gate.ex`
  - `lib/kiln/git.ex`
  - `lib/kiln/github/cli.ex`
  - `lib/kiln/github/push_worker.ex`
  - `lib/kiln/github/open_pr_worker.ex`
  - `lib/kiln/runs/run.ex`
  - `lib/kiln/runs.ex`
  - `lib/mix/tasks/kiln.first_run.prove.ex`
  - `test/integration/github_delivery_test.exs`
  - `test/integration/attach_workspace_hydration_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln/github/push_worker_test.exs`
  - `test/kiln/github/open_pr_worker_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs`
  - `test/mix/tasks/kiln.first_run.prove_test.exs`
- Phase planning artifacts:
  - `.planning/PROJECT.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
  - `.planning/phases/31-draft-pr-trust-ramp-and-attach-proof/31-CONTEXT.md`
  - `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-RESEARCH.md`
  - `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-02-SUMMARY.md`
  - `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-03-PLAN.md`
  - `.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md`
- Git manual: <https://git-scm.com/docs/git-check-ref-format>
- GitHub CLI manual: <https://cli.github.com/manual/gh_pr_create>
- GitHub Docs, About pull requests: <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests>

### Secondary (MEDIUM confidence)

- None. The phase recommendations did not require non-official ecosystem sources. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)

- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 31 can reuse existing repo seams and installed `git`/`gh` tools; no new dependency choice is required. [VERIFIED: codebase grep] [VERIFIED: git --version] [VERIFIED: gh --version]
- Architecture: HIGH - The required lifetimes and seams are explicit in `attached_repos`, `runs.github_delivery_snapshot`, `PushWorker`, and `OpenPRWorker`. [VERIFIED: codebase grep]
- Pitfalls: HIGH - The main risks are direct consequences of current worker idempotency rules, Phase 30 refusal boundaries, and official `gh`/Git draft-PR and branch-name behavior. [VERIFIED: codebase grep] [CITED: https://cli.github.com/manual/gh_pr_create] [CITED: https://git-scm.com/docs/git-check-ref-format] [CITED: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests]

**Research date:** 2026-04-24  
**Valid until:** 2026-05-24
