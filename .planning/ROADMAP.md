# Roadmap: Kiln

**Updated:** 2026-04-24 — **Active milestone v0.7.0**

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Milestones

- ✅ **v0.1.0** — Phases **1–9** + parking **999.1** — [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)
- ✅ **v0.2.0 — Operator dogfood** — Phases **10–13** — [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md) · [v0.2.0-REQUIREMENTS.md](milestones/v0.2.0-REQUIREMENTS.md)
- ✅ **v0.3.0 — Scale -> templates -> operator intelligence** — Phases **14–21** — [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) · [v0.3.0-REQUIREMENTS.md](milestones/v0.3.0-REQUIREMENTS.md) · [v0.3.0-MILESTONE-AUDIT.md](milestones/v0.3.0-MILESTONE-AUDIT.md)
- ✅ **v0.4.0 — Trust, docs & validation closure** — Phases **22–24** — [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md) · [v0.4.0-REQUIREMENTS.md](milestones/v0.4.0-REQUIREMENTS.md) · [v0.4.0-MILESTONE-AUDIT.md](milestones/v0.4.0-MILESTONE-AUDIT.md)
- ✅ **v0.5.0 — Local first success** — Phases **25–28** — [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md) · [v0.5.0-REQUIREMENTS.md](milestones/v0.5.0-REQUIREMENTS.md) · [v0.5.0-MILESTONE-AUDIT.md](milestones/v0.5.0-MILESTONE-AUDIT.md)
- ✅ **v0.6.0 — Attach existing repo first** — Phases **29–31** — [.planning/milestones/v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md) · [v0.6.0-REQUIREMENTS.md](milestones/v0.6.0-REQUIREMENTS.md) · [v0.6.0-MILESTONE-AUDIT.md](milestones/v0.6.0-MILESTONE-AUDIT.md)
- 🚧 **v0.7.0 — PR-sized brownfield execution** — Phases **32–35** — active milestone

## Current posture

`v0.7.0` is now open from the shipped `v0.6.0` baseline. The milestone focuses on turning attached-repo support into a normal ongoing workflow for the solo operator: one bounded feature or bugfix request on one existing repo should become one reviewable draft PR with clear proof and fewer rediscovery costs on repeat runs.

## Active milestone

### v0.7.0 — PR-sized brownfield execution

**Goal:** Make Kiln feel like a credible teammate on one attached repo by turning bounded brownfield work into a repeatable issue-to-draft-PR loop.

**Requirements in scope:** `WORK-01`, `CONT-01`, `SAFE-01`, `SAFE-02`, `TRUST-04`, `UAT-06`.

### Phase 32: PR-sized attached-repo intake

**Goal**: Reframe attached work as one bounded feature or bugfix request with explicit acceptance framing instead of an open-ended continuation ask.
**Depends on**: Phase 31
**Requirements**: `WORK-01`
**Plans**: 0 plans

Plans:

- [ ] TBD during `/gsd-plan-phase 32`

### Phase 33: Repeat-run continuity on attached repos

**Goal**: Make the second and third runs on one attached repo feel native by reusing workspace, repo, and trust context safely.
**Depends on**: Phase 32
**Requirements**: `CONT-01`
**Plans**: 0 plans

Plans:

- [ ] TBD during `/gsd-plan-phase 33`

### Phase 34: Brownfield preflight and narrowing guardrails

**Goal**: Detect likely repo-state conflicts or scope collisions before coding and give the operator concrete remediation or narrowing guidance.
**Depends on**: Phase 33
**Requirements**: `SAFE-01`, `SAFE-02`
**Plans**: 0 plans

Plans:

- [ ] TBD during `/gsd-plan-phase 34`

### Phase 35: Draft PR handoff and owning proof

**Goal**: Tighten the attached-repo draft PR output so the operator receives a reviewable handoff with scoped summary, proof, and milestone-owning verification coverage.
**Depends on**: Phase 34
**Requirements**: `TRUST-04`, `UAT-06`
**Plans**: 0 plans

Plans:

- [ ] TBD during `/gsd-plan-phase 35`

## Latest shipped milestone

**v0.6.0 — Attach existing repo first** shipped on 2026-04-24 with phases **29–31**. Archive: [.planning/milestones/v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md).

<details>
<summary>✅ v0.6.0 (Phases 29–31) — SHIPPED 2026-04-24</summary>

- [x] **Phase 29: Attach entry surfaces** — ATTACH-01 — completed 2026-04-24
- [x] **Phase 30: Attach workspace hydration and safety gates** — ATTACH-02, ATTACH-03, TRUST-02 — completed 2026-04-24
- [x] **Phase 31: Draft PR trust ramp and attach proof** — TRUST-01, TRUST-03, GIT-05, UAT-05 — completed 2026-04-24

**Scope summary:** first-class attach discovery on operator entry surfaces, single-repo attach resolution and managed hydration, conservative draft-PR-first delivery for attached repos, and one explicit owning proof command.

**Audit note:** closed with accepted tech debt. See [.planning/milestones/v0.6.0-MILESTONE-AUDIT.md](milestones/v0.6.0-MILESTONE-AUDIT.md).

</details>

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
*Active milestone: v0.7.0 on 2026-04-24; latest shipped milestone: v0.6.0*
