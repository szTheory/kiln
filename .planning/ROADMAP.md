# Roadmap: Kiln

**Updated:** 2026-04-24 — **Active milestone: v0.6.0 Attach existing repo first**

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Milestones

- ✅ **v0.1.0** — Phases **1–9** + parking **999.1** — [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)
- ✅ **v0.2.0 — Operator dogfood** — Phases **10–13** — [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md) · [v0.2.0-REQUIREMENTS.md](milestones/v0.2.0-REQUIREMENTS.md)
- ✅ **v0.3.0 — Scale -> templates -> operator intelligence** — Phases **14–21** — [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) · [v0.3.0-REQUIREMENTS.md](milestones/v0.3.0-REQUIREMENTS.md) · [v0.3.0-MILESTONE-AUDIT.md](milestones/v0.3.0-MILESTONE-AUDIT.md)
- ✅ **v0.4.0 — Trust, docs & validation closure** — Phases **22–24** — [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md) · [v0.4.0-REQUIREMENTS.md](milestones/v0.4.0-REQUIREMENTS.md) · [v0.4.0-MILESTONE-AUDIT.md](milestones/v0.4.0-MILESTONE-AUDIT.md)
- ✅ **v0.5.0 — Local first success** — Phases **25–28** — [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md) · [v0.5.0-REQUIREMENTS.md](milestones/v0.5.0-REQUIREMENTS.md) · [v0.5.0-MILESTONE-AUDIT.md](milestones/v0.5.0-MILESTONE-AUDIT.md)

## Active milestone

### v0.6.0 — Attach existing repo first

**Status:** In progress
**Phases:** 29-31
**Total Plans:** 7

#### Overview

v0.6.0 turns the first believable local run into the first believable real-project workflow. Instead of expanding outward into remote control, CLI/API, or deploy automation, this milestone narrows on one higher-leverage job for the current solo-operator persona: point Kiln at one existing repository, let it work on a bounded branch, and inspect a conservative draft PR.

#### Phases

##### Phase 29: Attach entry surfaces

**Goal**: Make attach-to-existing a first-class first-use path instead of an implied advanced workflow hidden behind greenfield-only onboarding.
**Depends on**: Phase 28
**Plans**: 2 plans

Plans:

- [x] `29-01-PLAN.md` — add attach-vs-template branching to onboarding and start surfaces
- [x] `29-02-PLAN.md` — align operator copy and flow guidance around greenfield vs attach entry points

**Details:**
Phase 29 introduces the product-level choice that this milestone is about: operators should see, from onboarding onward, that Kiln can either start from a built-in template or attach to one existing repository. The phase keeps the current demo/template path intact while making the attach path honest, explicit, and clearly scoped to real-project work.

##### Phase 30: Attach workspace hydration and safety gates

**Goal**: Resolve one attached repository into a safe, usable writable workspace before any coding run mutates git state.
**Depends on**: Phase 29
**Plans**: 3/3 plans complete

Plans:

- [x] `30-01-PLAN.md` — accept and validate local-path or GitHub-URL attach sources
- [x] `30-02-PLAN.md` — hydrate or reuse one writable attached workspace with run-scoped metadata
- [x] `30-03-PLAN.md` — refuse dirty, detached, or missing-prerequisite repo states with explicit remediation

**Details:**
Phase 30 handles the brownfield mechanics that the current greenfield-first flow never needed. Kiln must be able to resolve one repository, confirm it is usable, materialize or reuse the right local workspace, and stop early when the repo is unsafe to touch. This phase deliberately excludes multi-root, fork, and clone-to-stack behavior.

##### Phase 31: Draft PR trust ramp and attach proof

**Goal**: Carry the attached repo through branch, push, and draft PR orchestration, then close the milestone with explicit automated proof coverage.
**Depends on**: Phase 30
**Plans**: 2 plans

Plans:

- [ ] `31-01-PLAN.md` — add run-scoped branch + draft PR orchestration for attached repos
- [ ] `31-02-PLAN.md` — add attach happy-path and refusal-case proof coverage and reconcile planning SSOT

**Details:**
Phase 31 turns the attach flow into the intended trust posture: Kiln still works autonomously, but first attached-repo runs land as conservative draft PRs rather than pretending real repositories should behave like built-in templates. The phase also adds the owning proof command and milestone verification coverage for both success and refusal paths.

#### Milestone summary

**Key decisions:**

- `v0.6.0` prioritizes attach-to-existing over remote ops, CLI/API work, deploy automation, or backlog cleanup.
- First attached-repo runs default to branch + draft PR without adding synchronous approval gates.
- The first attach milestone is single-repo only; fork, clone-to-stack, multi-root, and reference-repo behavior remain deferred.
- Attach enters through onboarding and template/start surfaces because that is where usefulness is judged first.

**Issues deferred:**

- `999.4` planning/validation debt cleanup remains backlog work unless the attach milestone proves blocked by it.
- Read-only external reference repos remain a separate follow-on capability.
- Remote operator control plane, deploy/publish flows, and deeper brownfield workspace shapes remain deferred beyond `v0.6.0`.

## Current posture

An active milestone is now open. The next planning loop should start at **Phase 29** and keep the milestone narrow enough to prove attached-repo usefulness before widening into adjacent roadmap themes.

## Latest shipped milestone

**v0.5.0 — Local first success** shipped on 2026-04-24 with phases **25–28**. Archive: [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md).

<details>
<summary>✅ v0.4.0 (Phases 22–24) — SHIPPED 2026-04-23</summary>

- [x] **Phase 22: Merge authority & operator docs** — DOCS-08 — completed 2026-04-23
- [x] **Phase 23: Nyquist / VALIDATION closure** — NYQ-01 — completed 2026-04-23
- [x] **Phase 24: Template -> run UAT smoke** — UAT-03 — completed 2026-04-23

**Scope summary:** honest merge-authority documentation, explicit Nyquist posture for carried-over partial validations, and one focused operator template-to-run regression.

</details>

<details>
<summary>✅ v0.3.0 (Phases 14–21) — SHIPPED 2026-04-23</summary>

- [x] **Phase 14: Fair parallel runs** — PARA-01 — completed 2026-04-22
- [x] **Phase 15: Run comparison** — PARA-02 — completed 2026-04-22
- [x] **Phase 16: Read-only run replay** — REPL-01 — completed 2026-04-22
- [x] **Phase 17: Template library & onboarding specs** — WFE-01, ONB-01 — completed 2026-04-22
- [x] **Phase 18: Cost hints & budget alerts** — COST-01, COST-02 — completed 2026-04-22
- [x] **Phase 19: Post-mortems & soft feedback** — SELF-01, FEEDBACK-01 — completed 2026-04-22
- [x] **Phase 20: Phase 19 verification & planning SSOT** — completed 2026-04-23
- [x] **Phase 21: Containerized local operator DX** — LOCAL — completed 2026-04-23

**Forensic detail:** [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md).

</details>

## Parking slot (reference — shipped)

**999.1 — Docs & landing site** — shipped 2026-04-22; artifacts under [.planning/phases/999.1-docs-landing-site/](phases/999.1-docs-landing-site/).

## Backlog

### Phase 999.2: Operator demo vs live mode and provider readiness UX (shipped 2026-04-22)

**Goal:** Global **demo** (fixtures / stub providers / no paid API calls) vs **live** (runtime env / secret refs per **SEC-01**) mode is obvious in the operator shell (e.g. `Layouts` strip or chip). In **live** mode, unreachable or misconfigured providers show **calm** inline status and links to **`/providers`** — never silent failure. In **demo** mode, copy states that outcomes are **mock or seed-driven**. One surface for **config presence** (which providers are configured — names only, never key values) to improve local and production bring-up. Composes with existing **`ProviderHealthLive`** (`/providers`) and `ModelRegistry` health snapshots.

**Requirements:** TBD (promote with `/gsd-review-backlog`).

**Canonical refs (seed):** `CLAUDE.md` (SEC-01), `lib/kiln_web/live/provider_health_live.ex`, `.cursor/plans/GB dogfood note backlog-6d919cbd.plan.md` (intent note; do not treat as executable spec).

**Plans:** 3/3 plans complete

Plans:

- [x] 999.2-01 — `Kiln.OperatorRuntime` + config (`KILN_OPERATOR_RUNTIME_MODE`)
- [x] 999.2-02 — `KilnWeb.OperatorChromeHook` (assigns + 5s refresh)
- [x] 999.2-03 — `Layouts.app` chrome + LiveView tests

### Phase 999.4: Planning state and validation debt cleanup (BACKLOG)

**Goal:** Clean up the non-blocking artifact debt left after v0.5.0 closure so planning routing is trustworthy again, historical verification artifacts no longer imply stale failures, and the remaining orphan worktree residue is either incorporated deliberately or removed cleanly.

**Requirements:** TBD (promote with `/gsd-review-backlog`).

**Canonical refs (seed):** `.planning/milestones/v0.5.0-MILESTONE-AUDIT.md`, `.planning/STATE.md`, `.planning/phases/26-first-live-template-run/26-VERIFICATION.md`, `.planning/phases/26-first-live-template-run/deferred-items.md`, `.planning/phases/27-local-first-run-proof/27-VALIDATION.md`, `.planning/todos/pending/2026-04-24-review-orphan-phase-03-worktree-residue.md`.

**Plans:** 0 plans

Plans:

- [ ] TBD (promote with `/gsd-review-backlog` when ready)

### Phase 999.3: Immersive code graph visualization and Kiln-native microcopy (BACKLOG)

**Goal:** Explore a **web-native, highly intuitive code understanding surface** for Kiln that lets operators and builders visually inspect and navigate code, relationships, and system behavior without dropping into raw file trees first. Prefer **HTML/CSS/JS-native** approaches where possible (including D3-class graphing or other lightweight browser visualization), with richer rendering options only if they materially improve clarity. In parallel, raise the quality bar for **toast notifications and operator-facing UX microcopy** so status updates feel clear, persona-aware, and distinctly **Kiln-native** rather than generic programmer text.

**Requirements:** TBD (promote with `/gsd-review-backlog`).

**Plans:** 0 plans

Plans:

- [ ] TBD (promote with `/gsd-review-backlog` when ready)

---
*Milestone v0.6.0 opened: 2026-04-24*
