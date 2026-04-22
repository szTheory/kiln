# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.2.0 — Operator dogfood

**Shipped:** 2026-04-22  
**Phases:** 4 (10–13) | **Plans:** 4

### What Was Built

- Operator **clone-to-first-run** hardening (`first_run.sh`, Mix alias, README SSOT).
- **Game Boy** external-repo vertical slice on the Kiln side: workflow YAML, BDD/scenario argv bridge, spec stub, tests.
- Optional **`just`** / **`justfile`** path for db/dtu/otel + setup + smoke without a second official quick-start.
- **Planning truth** locked: `REQUIREMENTS.md` v1 checkboxes + traceability aligned with shipped Phases 1–9 and `PROJECT.md` **Validated**.

### What Worked

- Parking-lot **999.x** pattern kept ad-hoc docs work off the integer roadmap without losing history.
- Phase **13** as a dedicated “reconcile REQUIREMENTS/PROJECT/ROADMAP” plan reduced silent drift before tagging.

### What Was Inefficient

- **`gsd-sdk query milestone.complete`** is currently non-functional (calls `phases archive` without a version); milestone close required **manual** archive + git steps.
- **`roadmap.analyze`** omits phases **11–13** in JSON output even when `ROADMAP.md` lists them — readiness had to be verified by hand.

### Patterns Established

- **Host Phoenix + Compose data plane** remains the official local topology; optional task runners document wrappers only (**D-1201a**).
- **Argv-only** scenario steps for `System.cmd/3` to avoid shell-injection class issues in generated code.

### Key Lessons

1. Record **verification environment limits** in SUMMARY (e.g. `mix check` not green without DB) so milestone close can honestly carry **partial** self-checks without pretending CI was reproduced on the agent host.
2. When tooling claims “100%”, **spot-check disk** for SUMMARY files on phases the analyzer does not enumerate.

### Cost Observations

- Not tracked in-repo for this milestone; revisit if Kiln adds `SELF-01`-style post-mortems.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases (shipped) | Key change |
|-----------|------------------|------------|
| v0.1.0 | 1–9 (+999.1) | First end-to-end dark-factory + CI on Kiln itself |
| v0.2.0 | 10–13 | Operator dogfood slice + DX + documentation reconciliation before next planning cycle |

### Top Lessons (Verified Across Milestones)

1. **Postgres + secrets on the host** separate “agent finished the plan” from “merge is safe” — always name CI / second machine as the authority when local `mix check` is partial.
2. **Milestone archives** keep `ROADMAP.md` small; link out to `milestones/v*-ROADMAP.md` for forensic detail.
