# Phase 31: Draft PR trust ramp and attach proof - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Carry the already-safe attached repository from Phase 30 through run-scoped branch creation, push, and draft PR orchestration, then close the milestone with one explicit automated proof path for both attach success and refusal coverage.

This phase is about the **trust ramp and delivery contract** for attached repos. It is **not** about new attach source types, multi-root workspaces, fork flows, clone-to-stack behavior, or adding synchronous approval gates. Phase 30 already owns source resolution, managed workspace hydration, and refusal of unsafe repo states before git mutation begins.

</domain>

<decisions>
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

### the agent's Discretion

- Exact slug source for `<intent-slug>` as long as it is stable enough for one run, human-readable, and never the durable identity.
- Exact PR section wording and formatting, as long as the tone stays plain, conservative, and factual.
- Exact proof command name and delegated test list, as long as one explicit owning command exists and the subordinate layers stay hermetic.

</decisions>

<specifics>
## Specific Ideas

- The most coherent branch pattern is:
  - `kiln/attach/fix-login-timeout-r8f3c2d1`
  - explicit Kiln ownership
  - readable intent for the operator
  - immutable short run suffix for retries and duplicate suppression

- The most coherent PR contract is:
  - draft title that scans cleanly in GitHub
  - short factual body
  - no bot-wall prose
  - no raw machine dump
  - one lightweight provenance marker

- The most coherent proof shape is:
  - one `mix kiln.attach.prove`-style command
  - hermetic integration/domain coverage for branch + push + draft PR behavior
  - focused LiveView proof for the operator-facing trust surface

- Ecosystem lessons to carry forward:
  - successful PR bots like Dependabot and Renovate keep branch ownership explicit and machine-stable while still remaining readable
  - users distrust bots that overwrite human conventions, oversell confidence, or hide important facts in excessive template prose
  - Phoenix and ExUnit favor layered proof with focused LiveView tests over making browser tests the system of record

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth

- `.planning/PROJECT.md` — v0.6.0 milestone framing, bounded-autonomy posture, and attached-repo trust-ramp decisions
- `.planning/REQUIREMENTS.md` — `TRUST-01`, `TRUST-03`, `GIT-05`, and `UAT-05`
- `.planning/ROADMAP.md` — Phase 31 goal, plan split, and milestone boundary
- `.planning/STATE.md` — current milestone posture and phase sequencing

### Prior phase constraints

- `.planning/phases/29-attach-entry-surfaces/29-CONTEXT.md` — attach as a first-class route-backed brownfield path, single-repo framing, and honest product copy
- `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-RESEARCH.md` — attach workspace, persistence, and safety-gate shape that Phase 31 must build on
- `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-02-SUMMARY.md` — durable attached-repo metadata and managed workspace reuse contract
- `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-03-PLAN.md` — typed refusal and preflight boundary; confirms Phase 31 owns branch / push / draft PR orchestration

### Brownfield intent

- `.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md` — original attach trust-ramp intent, PR-per-unit-of-work direction, and safe brownfield defaults

### Implementation anchors

- `lib/kiln/attach.ex` — public attach boundary and attached-repo persistence
- `lib/kiln/attach/attached_repo.ex` — durable attached-repo metadata shape
- `lib/kiln/attach/workspace_manager.ex` — managed workspace and deterministic attach identity patterns
- `lib/kiln/attach/safety_gate.ex` — ready vs blocked contract from Phase 30
- `lib/kiln/git.ex` — git transport and push classification boundary
- `lib/kiln/github/cli.ex` — `gh` transport for PR creation and error classification
- `lib/kiln/github/push_worker.ex` — durable push worker and idempotent external-op shape
- `lib/kiln/github/open_pr_worker.ex` — durable PR worker and frozen PR attrs shape
- `lib/kiln_web/live/attach_entry_live.ex` — operator-facing attach trust surface
- `lib/mix/tasks/kiln.first_run.prove.ex` — repository-level proof-command precedent

### Testing anchors

- `test/kiln_web/live/attach_entry_live_test.exs` — ready vs blocked attach UI contract
- `test/integration/attach_workspace_hydration_test.exs` — existing attach hydration proof
- `test/integration/github_delivery_test.exs` — idempotent GitHub delivery worker behavior
- `test/kiln/github/push_worker_test.exs`
- `test/kiln/github/open_pr_worker_test.exs`
- `test/mix/tasks/kiln.first_run.prove_test.exs` — thin owning proof-command precedent

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Kiln.Attach` already exposes the narrow boundary Phase 31 should depend on instead of coupling directly to schema internals.
- `Kiln.Attach.AttachedRepo` already persists the repo identity, workspace path, and base branch facts needed for branch and PR orchestration.
- `Kiln.GitHub.PushWorker` and `Kiln.GitHub.OpenPRWorker` already model external side effects as durable, idempotent workers with frozen payloads.
- `Mix.Tasks.Kiln.FirstRun.Prove` is the repository’s current model for one owning proof command over smaller proof layers.

### Established Patterns

- Machine-stable identifiers are already preferred over mutable labels: `workspace_key`, `source_fingerprint`, and run/stage idempotency keys all follow this shape.
- Attach UX already uses honest ready vs blocked semantics; Phase 31 should extend that posture into branch and PR delivery rather than replacing it with optimistic success copy.
- The codebase prefers thin public boundaries, durable worker payloads, and typed failure classification over ad hoc command execution inside UI code.

### Integration Points

- Branch naming and delivery should hang off persisted attached-repo facts from `Kiln.Attach`.
- Push and draft PR orchestration should reuse the existing git / GitHub worker seams rather than inventing a parallel attach-only transport path.
- The proof command should compose integration/domain and focused LiveView tests in the same spirit as `mix kiln.first_run.prove`.

</code_context>

<deferred>
## Deferred Ideas

- Multi-root or monorepo attach behavior
- Fork-and-continue flows
- Clone-to-stack flows
- Human approval gates or synchronous PR approval UI
- Rich bot PR dashboards or heavy metadata sections in draft PR bodies

</deferred>

---

*Phase: 31-draft-pr-trust-ramp-and-attach-proof*
*Context gathered: 2026-04-24*
