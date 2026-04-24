# Requirements: Kiln — Milestone v0.7.0

**Defined:** 2026-04-24  
**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

This milestone turns the first believable attach-to-existing flow into a believable ongoing brownfield workflow. After v0.6.0 proved Kiln can attach one repo and land a conservative draft PR, v0.7.0 narrows the next JTBD gap: a solo operator should be able to hand Kiln one bounded feature or bugfix request on that attached repo and receive a trustable draft PR without re-learning the attach path every run.

## v0.7.0 Requirements

### PR-sized attached-repo intake

- [ ] **WORK-01**: Operator can start an attached-repo run from one bounded feature or bugfix request with enough acceptance framing for Kiln to treat the work as one PR-sized unit instead of an open-ended continuation ask.

### Repeat-run continuity

- [ ] **CONT-01**: Repeat runs on the same attached repo reuse known repo/workspace context and prior trust/setup facts so the operator does not have to rediscover the attach flow each time.

### Brownfield guardrails

- [ ] **SAFE-01**: Before coding starts, Kiln detects and surfaces unsafe or conflicting brownfield conditions such as dirty repo state, unclear target/base branch, overlapping open PRs, or likely scope collisions.
- [ ] **SAFE-02**: When brownfield preflight finds a non-fatal issue, Kiln provides explicit remediation or narrowing guidance so the operator can re-scope the run without guessing.

### Draft PR handoff

- [ ] **TRUST-04**: Attached-repo runs produce a draft PR handoff that includes a scoped summary, proof or verification citations, and enough repo-fitting context for the operator to review the result as a normal feature or bugfix PR.

### Automated proof

- [ ] **UAT-06**: The repository contains one explicit automated proof path for PR-sized attached-repo continuation, including repeat-run continuity plus representative refusal or warning cases for brownfield preflight.

## vNext / Deferred

### Brownfield expansions

- **ATTACH-04**: Attach flow supports multi-root or monorepo-shaped workspaces.
- **FORK-01**: Operator can fork an upstream repo and continue work on the fork as a first-class Kiln flow.
- **PORT-01**: Kiln can clone intent from one stack into a new repo in another stack.
- **REF-01**: Read-only external reference repos can be attached as context alongside the working repo.

### Adjacent leverage

- **REMOTE-01**: Operator can check and nudge runs from a remote device or host.
- **ENABLE-01**: Repo readiness/setup UX expands into a broader attach-readiness enablement layer beyond the core PR-sized flow.
- **DELIVERY-01**: Kiln deploys or publishes successful outputs rather than stopping at merged PRs.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Remote operator control plane | Useful after the daily brownfield loop is solid, but not the most direct gap for the current solo-operator JTBD |
| Monorepo or multi-root attach | Higher workspace and safety complexity than needed for the next single-repo milestone |
| Fork-and-continue | Valuable brownfield extension, but secondary to making one attached repo feel repeatable |
| Clone-to-different-stack workflows | Separate migration-quality problem with different research and attribution needs |
| Broad external-reference-repo support | Helpful for pattern matching, but not required to prove repeat-run continuity on one repo |
| Bundling `999.4` planning debt cleanup into this milestone | Important cleanup, but lower leverage than making attached-repo work feel like a normal ongoing workflow |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WORK-01 | Phase 32 | Pending |
| CONT-01 | Phase 33 | Pending |
| SAFE-01 | Phase 34 | Pending |
| SAFE-02 | Phase 34 | Pending |
| TRUST-04 | Phase 35 | Pending |
| UAT-06 | Phase 35 | Pending |

**Coverage:** v0.7.0 requirements: **6** — mapped: **6** — unmapped: **0** — pending: **6**.

---
*Requirements opened: 2026-04-24 — `/gsd-new-milestone` v0.7.0*
