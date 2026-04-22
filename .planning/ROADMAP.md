# Roadmap: Kiln

**Updated:** 2026-04-22 — **Milestone v0.3.0** started (Phases **14–19**)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Milestones

- ✅ **v0.1.0** — Phases **1–9** + parking **999.1** — [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)
- ✅ **v0.2.0 — Operator dogfood** — Phases **10–13** — [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md)
- 🚧 **v0.3.0 — Scale → templates → operator intelligence** — Phases **14–19** — requirements: [REQUIREMENTS.md](REQUIREMENTS.md)

## Overview (v0.3.0)

Ship **A** (multi-run fairness, comparison, read-only replay), then **B** (template library + vetted onboarding specs), then **C** (cost hints, budget alerts, post-mortems, soft feedback) as **small** vertical slices so each phase stays reviewable. Phase directories are **not** reset; numbering continues from v0.2.0.

## Phases (v0.3.0)

- [x] **Phase 14: Fair parallel runs** — PARA-01 — fair scheduling / queueing when multiple runs are active; respects caps and idempotency. (completed 2026-04-22)
- [x] **Phase 15: Run comparison** — PARA-02 — side-by-side operator view for two runs. (completed 2026-04-22)
- [x] **Phase 16: Read-only run replay** — REPL-01 — timeline scrub over persisted audit/checkpoint data (MVP). (completed 2026-04-22)
- [x] **Phase 17: Template library & onboarding specs** — WFE-01, ONB-01 — `priv` (or agreed) template packs + UI to start from template. (completed 2026-04-22)
- [ ] **Phase 18: Cost hints & budget alerts** — COST-01, COST-02 — advisory + threshold notifications.
- [ ] **Phase 19: Post-mortems & soft feedback** — SELF-01, FEEDBACK-01 — merged-run artifact + non-blocking operator nudge with audit trail.

**Parking / decimals:** Use **999.x** only for ad-hoc backlog execution; no decimal insert planned for v0.3.0 launch.

## Phase details (summary)

### Phase 14: Fair parallel runs
**Goal:** Multiple concurrent runs make forward progress under load without starvation.  
**Requirements:** PARA-01  
**Success criteria (observable):**
1. With N concurrent runs (N within configured test limit), no run remains permanently `queued` while others advance solely due to unfair ordering.
2. Telemetry or metrics expose per-run wait time so regressions are visible in CI or integration tests.

### Phase 15: Run comparison
**Goal:** Operator can diff two runs at a glance.  
**Requirements:** PARA-02  
**Success criteria:**
1. From run board or detail, operator selects two runs and sees a comparison surface (states, costs, key artifacts).
2. LiveView tests cover the happy path with stable selectors.

### Phase 16: Read-only run replay
**Goal:** Incident-style review without mutating history.  
**Requirements:** REPL-01  
**Success criteria:**
1. Operator can step/scrub through a run’s persisted timeline derived from audit/checkpoints.
2. No mutation path claims to “change the past” — read-only MVP only.

### Phase 17: Template library & onboarding specs
**Goal:** Lower time-to-first-successful-run via curated templates.  
**Requirements:** WFE-01, ONB-01  
**Success criteria:**
1. At least three built-in templates ship with metadata (time/cost estimates, purpose).
2. One action creates a new spec or run pre-populated from a template.

### Phase 18: Cost hints & budget alerts
**Goal:** Operator sees spend risk before hard caps bite.  
**Requirements:** COST-01, COST-02  
**Success criteria:**
1. Advisory hint surfaces when policy + telemetry suggest a cheaper tier (wording non-prescriptive).
2. Threshold notifications fire at configured % of cap; tests use fakes/stubs.

### Phase 19: Post-mortems & soft feedback
**Goal:** Close the learning loop without human approval gates.  
**Requirements:** SELF-01, FEEDBACK-01  
**Success criteria:**
1. On merge, a structured post-mortem artifact is persisted and discoverable from the run.
2. Soft nudge writes `operator_feedback_received` audit event; does not pause the run unless existing blockers apply.

---

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

---
*Milestone v0.3.0 opened: 2026-04-22*
