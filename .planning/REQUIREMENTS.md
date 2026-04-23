# Requirements: Kiln — Milestone v0.3.0

**Defined:** 2026-04-22  
**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

Scope is **ordered A → B → C** in **bite-sized** phases (continuing roadmap numbering after Phase 13). Prior v1 bundle remains validated; see `.planning/milestones/v0.2.0-REQUIREMENTS.md` for the closed v0.1.0/v0.2.0 baseline.

## v0.3.0 Requirements

### A — Execution & scale (first)

- [x] **PARA-01**: Operator can run **multiple runs concurrently** with **fair-share scheduling** (no single run starves others under load); caps and `RunDirector` / queue semantics stay consistent with ORCH-06/07.
- [x] **PARA-02**: Operator can open a **run comparison** view for two runs (metadata, stage outcomes, artifact/diff pointers, cost summary) without leaving the dashboard.
- [x] **REPL-01**: Operator can **scrub a read-only timeline** of a run (audit + stage checkpoints) for post-incident understanding — **MVP**: query existing append-only data; no branching alternate realities in this milestone.

### B — Templates & workflow ecosystem (second)

- [x] **WFE-01**: Kiln ships a **versioned template library** (workflow + spec pairs under `priv/` or equivalent) and the operator can **instantiate** a new spec/run from a template in one action.
- [x] **ONB-01**: At least **three vetted templates** ship with estimated cost/time notes (per SEED-003 intent); “Hello Kiln”-class happy path included.

### C — Cost, operations & learning loop (third)

- [x] **COST-01**: **Cost optimization hints** — advisory text when a cheaper model tier is likely safe given recent stage outcomes (never overrides scenario oracle or caps).
- [x] **COST-02**: **Budget alerts** at configured thresholds (e.g. 50% / 80% / 100% of per-run cap) surfaced in UI + existing notification path where applicable.
- [ ] **SELF-01**: Every **merged** run emits a **structured post-mortem** artifact (tokens/$ by stage/role, retries, `requested_model` vs `actual_model_used`, scenario verdict trail, block reasons).
- [ ] **FEEDBACK-01**: Operator can send a **one-line soft nudge** during a run; persisted as **`operator_feedback_received`** audit event; **non-blocking** (does not add approval gates; UAT-02 unchanged).

## Deferred (same IDs, not in v0.3.0)

- **REPL-02** — Hypothetical re-execution from checkpoint with modified spec (heavy; needs its own milestone slice).
- **WFE-02** — Workflow signing / supply-chain — deferred.
- **SELF-02** … **SELF-07** — Subjective ratings, aggregates, LLM-judge, bake-offs, external signals, Kiln-on-Kiln loop — defer past v0.3.0 except where listed above.

## Out of scope (unchanged product boundary)

| Area | Reason |
|------|--------|
| TEAM-*, SSO, multi-tenant | `PROJECT.md` — solo operator until self-use is proven |
| SEED-002 remote control plane | Auth + exposure; not part of v0.3.0 unless explicitly rescoped |
| Chat-primary unblock | BLOCK-* contract remains |

## Traceability

| Requirement | Phase | Status |
|---------------|-------|--------|
| PARA-01 | Phase 14 | Complete |
| PARA-02 | Phase 15 | Complete |
| REPL-01 | Phase 16 | Complete |
| WFE-01 | Phase 17 | Complete |
| ONB-01 | Phase 17 | Complete |
| COST-01 | Phase 18 | Complete |
| COST-02 | Phase 18 | Complete |
| SELF-01 | Phase 20 | Pending |
| FEEDBACK-01 | Phase 20 | Pending |

**Coverage:** v0.3.0 requirements: **9** — mapped: **9** — unmapped: **0** — complete: **7** — pending: **2** (gap closure tracked in Phase 20 per `.planning/v0.3.0-MILESTONE-AUDIT.md`).

---
*Requirements defined: 2026-04-22 — `/gsd-new-milestone` v0.3.0*
