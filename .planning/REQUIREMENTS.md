# Requirements: Kiln

**Defined:** 2026-04-23  
**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## v0.5.0 Requirements

This milestone optimizes for the first believable local success. Kiln already has templates, operator setup surfaces, demo/live signaling, and template -> run regression coverage. The missing step is a narrow, trustworthy path from local setup to one real live run without guesswork.

### Operator readiness

- [x] **SETUP-01**: Operator setup/readiness surface reports whether the local environment is ready for a live run, including Docker/runtime prerequisites and provider/config presence without exposing secret values. Shipped in Phase 25 via the shared readiness contract and canonical `/settings` surface.
- [x] **SETUP-02**: When the local environment is not ready, Kiln shows explicit remediation guidance and the recommended next action instead of making the operator infer the fix from scattered screens or logs. Shipped in Phase 25 by routing readiness-aware surfaces back to `/settings`.
- [x] **DOCS-09**: README and planning docs describe one canonical local trial flow, with host Phoenix + Compose as the primary path and the optional devcontainer clearly framed as secondary. Phase 25 now names `/settings` as the live-readiness remediation SSOT.

### First live run path

- [x] **LIVE-01**: Kiln identifies one built-in template as the recommended first local live run so a new operator knows which path to trust first. Shipped in Phase 26 via the `hello-kiln` first-run recommendation path.
- [x] **LIVE-02**: Starting a live run from the operator UI performs a readiness preflight and routes the operator back to the specific missing setup step when prerequisites are not met. Shipped in Phase 26 via the backend-authoritative start seam and `/settings` recovery routing.
- [x] **LIVE-03**: Once prerequisites are satisfied, an operator can launch one believable local live run from a built-in template and observe enough run detail to confirm Kiln is actually operating. Shipped in Phase 26 with `/runs/:id` as the proof-first arrival surface.

### Automated proof

- [ ] **UAT-04**: The repository contains one explicit automated proof path for setup-ready operator flow -> first live run, and the exact verification command is cited in the phase verification artifact.

## vNext / Deferred

### Future UX / exploration

- **UX-01**: Immersive code graph visualization and deeper Kiln-native microcopy polish (`999.3`) remain deferred until the first local success path is proven.
- **DOGFOOD-02**: Richer external-repo live dogfood flows remain deferred until the recommended first local live run is stable.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Promoting `999.3` code graph work into this milestone | Better comprehension is lower leverage than proving a fast local live success path |
| New hosted/cloud runtime paths | This milestone is explicitly local-first and keeps the existing local topology |
| New team/multi-user capabilities | Solo operator remains the product boundary for v1 |
| Broad template expansion | One recommended first live run is more valuable than adding many partly-supported templates |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SETUP-01 | Phase 25 (`25-01-PLAN.md`, `25-02-PLAN.md`) | Complete |
| SETUP-02 | Phase 25 (`25-01-PLAN.md`, `25-02-PLAN.md`) | Complete |
| DOCS-09 | Phase 25 (`25-03-PLAN.md`) | Complete |
| LIVE-01 | Phase 26 (`26-01-PLAN.md`, `26-03-PLAN.md`) | Complete |
| LIVE-02 | Phase 26 (`26-02-PLAN.md`, `26-03-PLAN.md`) | Complete |
| LIVE-03 | Phase 26 (`26-01-PLAN.md`, `26-02-PLAN.md`, `26-03-PLAN.md`) | Complete |
| UAT-04 | Phase 27 | Pending |

**Coverage:**
- v0.5.0 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-23*
*Last updated: 2026-04-24 after Phase 26 closure*
