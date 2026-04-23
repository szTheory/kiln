# Milestones

Living summary of shipped versions. Detailed phase history lives under `.planning/milestones/` and `.planning/phases/`.

## v0.4.0 — Trust, docs & validation closure

**Shipped:** 2026-04-23  
**Phases:** 22–24 (**3** phases, **4** plans, **10** tasks)  
**Archives:** [v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md) · [v0.4.0-REQUIREMENTS.md](milestones/v0.4.0-REQUIREMENTS.md) · [v0.4.0-MILESTONE-AUDIT.md](milestones/v0.4.0-MILESTONE-AUDIT.md)  
**Tag:** `v0.4.0`

**What shipped**

1. **Merge authority SSOT** — DOCS-08 aligned `README.md` and `PROJECT.md` on CI merge authority vs optional local smoke, with the Phase 12 PARTIAL caveat preserved.
2. **Nyquist closure** — NYQ-01 resolved historical validation posture for Phases 14, 16, 17, and 19 with explicit compliant or waiver outcomes.
3. **Template -> run regression** — UAT-03 added a readiness-aware LiveView proof from `/templates` through `#run-detail`, with a narrow verification command recorded.

**Milestone audit:** Passed on 2026-04-23. A stale `24-UAT.md` record was reconciled during pre-close audit and is now complete.

## v0.3.0 — Scale → templates → operator intelligence

**Shipped:** 2026-04-23  
**Phases:** 14–21 (**8** phases, **24** plans)  
**Archives:** [v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md) · [v0.3.0-REQUIREMENTS.md](milestones/v0.3.0-REQUIREMENTS.md) · [v0.3.0-MILESTONE-AUDIT.md](milestones/v0.3.0-MILESTONE-AUDIT.md)  
**Tag:** `v0.3.0`

**What shipped**

1. **Fair parallel runs + comparison + replay** — PARA-01/02 and read-only REPL-01 timeline MVP for multi-run operations and incident-style review.
2. **Template library & onboarding** — WFE-01 / ONB-01 with curated `priv/` templates and one-action instantiate.
3. **Cost hints & budget alerts** — COST-01 advisory tier hints + COST-02 threshold notifications.
4. **Post-mortems & soft feedback** — SELF-01 merged-run artifact + FEEDBACK-01 non-blocking `operator_feedback_received` audit path; formal `19-VERIFICATION.md` and Phase 20 planning SSOT.
5. **Containerized local operator DX (optional)** — Phase 21 devcontainer / documented Docker-centric path alongside host Phoenix + Compose.

## v0.2.0 — Operator dogfood

**Shipped:** 2026-04-22  
**Phases:** 10–13 (4 plans)  
**Archives:** [v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md) · [v0.2.0-REQUIREMENTS.md](milestones/v0.2.0-REQUIREMENTS.md)  
**Tag:** `v0.2.0`

**What shipped**

- **Phase 10 — Local operator readiness:** README / `test/integration/first_run.sh` / Mix `integration.first_run` parity; operator cold-path SSOT for dogfood.
- **Phase 11 — Game Boy dogfood vertical slice:** `rust_gb_dogfood_v1` workflow, argv-only scenario shell oracle, `priv/dogfood/gb_vertical_slice_spec.md`, compiler/parser tests; external Rust workspace + ROM execution remains operator-owned (`GB-SPIKE.md`).
- **Phase 12 — Local Docker / dev DX:** Optional `justfile` + README “Just” path + `LOCAL-DX-AUDIT.md` alignment. **Known gap:** `12-01-SUMMARY.md` Self-Check PARTIAL — full `mix check` authority is CI / DB-backed workstation.
- **Phase 13 — Requirements & roadmap hygiene:** All v1 `REQUIREMENTS.md` rows `[x]`; traceability Complete; `DOCS-ALIGN-01` validated.

## v0.1.0 — Foundation through dogfood release

**Reference:** [v0.1.0.md](milestones/v0.1.0.md)  
**Scope:** Phases 1–9 (+ parking `999.1`). Operator follow-ups (tag `v0.1.0` + GitHub Release) remain per `09-05-SUMMARY.md` when ready.
