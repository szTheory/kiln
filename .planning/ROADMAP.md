# Roadmap: Kiln

**Updated:** 2026-04-24 — **Milestone v0.5.0** (Phases **25–26** shipped; Phase **27** planned)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Milestones

- ✅ **v0.1.0** — Phases **1–9** + parking **999.1** — [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)
- ✅ **v0.2.0 — Operator dogfood** — Phases **10–13** — [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md) · [v0.2.0-REQUIREMENTS.md](milestones/v0.2.0-REQUIREMENTS.md)
- ✅ **v0.3.0 — Scale -> templates -> operator intelligence** — Phases **14–21** — [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) · [v0.3.0-REQUIREMENTS.md](milestones/v0.3.0-REQUIREMENTS.md) · [v0.3.0-MILESTONE-AUDIT.md](milestones/v0.3.0-MILESTONE-AUDIT.md)
- ✅ **v0.4.0 — Trust, docs & validation closure** — Phases **22–24** — [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md) · [v0.4.0-REQUIREMENTS.md](milestones/v0.4.0-REQUIREMENTS.md) · [v0.4.0-MILESTONE-AUDIT.md](milestones/v0.4.0-MILESTONE-AUDIT.md)
- 🚧 **v0.5.0 — Local first success** — Phases **25–27** — [REQUIREMENTS.md](REQUIREMENTS.md)

## Overview (v0.5.0)

Collapse the distance between "Kiln looks promising" and "Kiln completed one real local run for me." This milestone treats the first believable local success path as the highest-leverage product risk: readiness must be explicit, the recommended first live run must be obvious, and one automated proof path must show that the journey actually works. Phase 25 now establishes `/settings` as the canonical live-readiness remediation surface while preserving host Phoenix + Compose as the primary local trial path.

## Phases (v0.5.0)

- [x] **Phase 25: Local live readiness SSOT** — SETUP-01, SETUP-02, DOCS-09 — completed 2026-04-23
- [x] **Phase 26: First live template run** — LIVE-01, LIVE-02, LIVE-03 — completed 2026-04-24
- [ ] **Phase 27: Local first-run proof** — UAT-04

**Parking / decimals:** Keep using **999.x** only for ad-hoc backlog execution outside the integer milestone flow. **999.3** stays parked during v0.5.0.

## Phase details (v0.5.0)

### Phase 25: Local live readiness SSOT
**Status:** Shipped 2026-04-23 via `25-01-PLAN.md`, `25-02-PLAN.md`, and `25-03-PLAN.md`  
**Goal:** Make live readiness operational rather than informational so the operator can tell, from one surface, whether Kiln is ready for a real local run and what to fix next.  
**Requirements:** SETUP-01, SETUP-02, DOCS-09  
**Success criteria (observable):**
1. Operator-facing readiness now shows the local prerequisites that matter for a live run without exposing secrets, using `/settings` as the canonical checklist.
2. Missing prerequisites now produce direct remediation guidance and a recommended next action, and readiness-aware surfaces route recovery back to `/settings`.
3. README and planning docs now describe one canonical local trial path, with host Phoenix + Compose still primary and the devcontainer explicitly secondary.

### Phase 26: First live template run
**Status:** Shipped 2026-04-24 via `26-01-PLAN.md`, `26-02-PLAN.md`, and `26-03-PLAN.md`  
**Goal:** Turn the existing template/run surfaces into one trustworthy first live run path instead of making the operator guess where to start.  
**Requirements:** LIVE-01, LIVE-02, LIVE-03  
**Success criteria:**
1. One built-in template is clearly presented as the recommended first local live run.
2. Starting a live run performs a readiness preflight and routes the operator back to the missing prerequisite when blocked.
3. Once ready, the operator can launch a believable local live run and see enough detail to confirm Kiln is actually operating.

### Phase 27: Local first-run proof
**Goal:** Leave the milestone with one explicit, repeatable proof that the local operator journey works end to end.  
**Requirements:** UAT-04  
**Success criteria:**
1. The repository contains one automated proof path for setup-ready operator flow -> first live run.
2. The phase verification artifact cites the exact command used to prove the path.

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

**Plans:** 2/2 plans complete

Plans:

- [x] 999.2-01 — `Kiln.OperatorRuntime` + config (`KILN_OPERATOR_RUNTIME_MODE`)
- [x] 999.2-02 — `KilnWeb.OperatorChromeHook` (assigns + 5s refresh)
- [x] 999.2-03 — `Layouts.app` chrome + LiveView tests

### Phase 999.3: Immersive code graph visualization and Kiln-native microcopy (BACKLOG)

**Goal:** Explore a **web-native, highly intuitive code understanding surface** for Kiln that lets operators and builders visually inspect and navigate code, relationships, and system behavior without dropping into raw file trees first. Prefer **HTML/CSS/JS-native** approaches where possible (including D3-class graphing or other lightweight browser visualization), with richer rendering options only if they materially improve clarity. In parallel, raise the quality bar for **toast notifications and operator-facing UX microcopy** so status updates feel clear, persona-aware, and distinctly **Kiln-native** rather than generic programmer text.

**Requirements:** TBD (promote with `/gsd-review-backlog`).

**Plans:** 0 plans

Plans:

- [ ] TBD (promote with `/gsd-review-backlog` when ready)

---
*Milestone v0.5.0 updated: 2026-04-24 after Phase 26 closure*
