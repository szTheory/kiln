# Requirements: Kiln — Milestone v0.4.0

**Defined:** 2026-04-23  
**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

This milestone tightens **operator trust** after v0.3.0: honest **merge authority** documentation, **Nyquist / VALIDATION** closure (or explicit waivers) for phases that shipped `partial`, and one more **automated operator journey** from templates into a run.

Prior milestones remain validated; see `.planning/milestones/v0.3.0-REQUIREMENTS.md` for the closed v0.3.0 slice.

## v0.4.0 Requirements

### Documentation & process

- [x] **DOCS-08**: **`README.md`** and **`PROJECT.md`** include a single **merge authority** table: which commands must be green in **CI** before merge vs which are optional local smoke when Postgres/OTel/fixtures are absent; references **`12-01-SUMMARY.md`** Self-Check PARTIAL honestly (no “green locally” fiction). — **Complete 2026-04-23** (`22-VERIFICATION.md`).

### Planning hygiene (Nyquist)

- [ ] **NYQ-01**: For phases **14**, **16**, **17**, and **19**, each `*-VALIDATION.md` ends v0.4.0 with either **`nyquist_compliant: true`** (with cited evidence) **or** an explicit **`## Nyquist waiver`** subsection (reason, owner, review-by date). No silent `partial` without a waiver path.

### Automated acceptance

- [ ] **UAT-03**: **`Phoenix.LiveViewTest`** (or existing integration harness) covers **template pick → start run** (or equivalent “create run from template”) happy path using **stable DOM ids**; documents the command in the phase **VERIFICATION** artifact.

## Deferred (not in v0.4.0)

- **REPL-02** — Re-execution from checkpoint with modified spec (separate milestone).
- **WFE-02** — Workflow signing / supply-chain.
- **SELF-02 … SELF-07** — Subjective ratings, aggregates, LLM-judge, etc.

## Out of scope (unchanged product boundary)

| Area | Reason |
|------|--------|
| TEAM-*, SSO, multi-tenant | `PROJECT.md` — solo operator |
| Hosted cloud runtime | Local-first; no Kiln SaaS deploy in this slice |
| Chat-primary unblock | BLOCK-* contract |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCS-08 | Phase 22 | Complete |
| NYQ-01 | Phase 23 | Pending |
| UAT-03 | Phase 24 | Pending |

**Coverage:** v0.4.0 requirements: **3** — mapped: **3** — unmapped: **0** — complete: **1** — pending: **2**.

---
*Requirements opened: 2026-04-23 — `/gsd-new-milestone` v0.4.0*
