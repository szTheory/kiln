# Roadmap: Kiln

**Updated:** 2026-04-23 — **Post v0.3.0 close** (next: **`/gsd-new-milestone`**)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Milestones

- ✅ **v0.1.0** — Phases **1–9** + parking **999.1** — [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)
- ✅ **v0.2.0 — Operator dogfood** — Phases **10–13** — [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md)
- ✅ **v0.3.0 — Scale → templates → operator intelligence** — Phases **14–21** (shipped 2026-04-23) — [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) · [v0.3.0-REQUIREMENTS.md](milestones/v0.3.0-REQUIREMENTS.md)
- 📋 **Next** — Run **`/gsd-new-milestone`** to open the next version (fresh `REQUIREMENTS.md` + roadmap scope).

## Phases

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

**Forensic detail:** [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) (full pre-close roadmap copy).

</details>

### Next milestone

_No integer phases opened._ Planning starts with **`/gsd-new-milestone`**.

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

---
*Living roadmap post v0.3.0 close: 2026-04-23*
