# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.3.0 — Scale → templates → operator intelligence

**Shipped:** 2026-04-23  
**Phases:** 8 (14–21) | **Plans:** 24

### What Was Built

- **Multi-run fairness and operator situational awareness:** fair scheduling (PARA-01), run comparison (PARA-02), read-only replay / timeline scrub (REPL-01).
- **Template library + onboarding:** versioned `priv/` templates with one-action instantiate (WFE-01 / ONB-01).
- **Spend visibility:** advisory cost hints (COST-01) and budget threshold alerts (COST-02).
- **Learning loop:** merged-run post-mortem artifact (SELF-01) and non-blocking soft nudge to audit (FEEDBACK-01), with formal **`19-VERIFICATION.md`** and **Phase 20** SSOT.
- **Optional container-first local path:** Phase **21** devcontainer / documented Docker-centric operator DX alongside host Phoenix + Compose.

### What Worked

- **Small vertical slices** (14–19) kept reviews bounded; **Phase 20** as an explicit “close the audit gaps” slice avoided pretending SSOT was green while checkboxes lagged.
- **Three-source gate** (VERIFICATION + SUMMARY + REQUIREMENTS) for SELF-01 / FEEDBACK-01 became enforceable once `19-VERIFICATION.md` landed.

### What Was Inefficient

- **`gsd-sdk query milestone.complete`** still returns `GSDError: version required for phases archive` — milestone close remains **manual** archive + git steps (same as v0.2.0 retrospective).
- **`gsd-sdk query roadmap.analyze`** still returns empty `phases` for this repo’s ROADMAP shape — readiness checks are manual or script-assisted.

### Patterns Established

- **Parking 999.x** for shipped backlog work stays referenced from the living roadmap without re-opening integer phases.
- **Tiered LOCAL DX:** host Phoenix canonical; optional `.devcontainer/` + CI drift gate for Linux-reproducible toolchains.

### Key Lessons

1. When a milestone audit finds **`gaps_found`**, either run a dedicated “SSOT + verification” phase (here: **20**) or accept explicit tech debt in `MILESTONES.md` — do not silently retag.
2. Keep **Nyquist / VALIDATION** honesty in phase docs; “partial” is acceptable if CI is named as authority.

### Cost Observations

- Post-mortem materialization (SELF-01) improves future cost forensics; no in-repo token spend aggregates added in this retrospective pass.

---

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
| v0.3.0 | 14–21 | Scale + templates + cost/post-mortem signals + optional containerized operator DX |

### Top Lessons (Verified Across Milestones)

1. **Postgres + secrets on the host** separate “agent finished the plan” from “merge is safe” — always name CI / second machine as the authority when local `mix check` is partial.
2. **Milestone archives** keep `ROADMAP.md` small; link out to `milestones/v*-ROADMAP.md` for forensic detail.
