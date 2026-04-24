# Milestones

Living summary of shipped versions. Detailed phase history lives under `.planning/milestones/` and `.planning/phases/`.

## v0.7.0 — PR-sized brownfield execution

**Shipped:** 2026-04-24  
**Phases:** 32–35 (**4** phases, **11** plans)  
**Archives:** [v0.7.0-ROADMAP.md](milestones/v0.7.0-ROADMAP.md) · [v0.7.0-REQUIREMENTS.md](milestones/v0.7.0-REQUIREMENTS.md)  
**Tag:** `v0.7.0`

**What shipped**

1. **Bounded attached intake** — WORK-01 introduced structured request contracts (Summary, Acceptance Criteria, Out-of-Scope) frozen into spec revisions for clear brownfield boundaries.
2. **Repo-centric continuity** — CONT-01 added explicit usage metadata and recency tracking to attached repos, enabling seamless repeat-work context.
3. **Advisory brownfield preflight** — SAFE-01 / SAFE-02 implemented typed findings (fatal/warning/info) and safety guardrails to detect conflicts before git mutation.
4. **Reviewer-first draft PRs** — TRUST-04 / UAT-06 optimized GitHub delivery to derive review-ready titles and bodies from durable request facts and proof citations.

## v0.6.0 — Attach existing repo first

**Shipped:** 2026-04-24  
**Phases:** 29–31 (**3** phases, **8** plans)  
**Archives:** [v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md) · [v0.6.0-REQUIREMENTS.md](milestones/v0.6.0-REQUIREMENTS.md) · [v0.6.0-MILESTONE-AUDIT.md](milestones/v0.6.0-MILESTONE-AUDIT.md)  
**Tag:** `v0.6.0`

**What shipped**

1. **Attach discovery** — ATTACH-01 brought "Attach existing repo" as a first-class discovery path to onboarding and start surfaces.
2. **Managed workspace hydration** — ATTACH-02 / ATTACH-03 established the single-repo attach resolution and conservative hydration boundary.
3. **Draft-PR trust ramp** — TRUST-01 / TRUST-02 / TRUST-03 / GIT-05 / UAT-05 added frozen branch push, draft PR delivery, and the owning `mix kiln.attach.prove` command for attached-repo validation.

## v0.5.0 — Local first success

**Shipped:** 2026-04-24  
**Phases:** 25–28 (**4** phases, **8** plans, **17** recorded tasks)  
**Archives:** [v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md) · [v0.5.0-REQUIREMENTS.md](milestones/v0.5.0-REQUIREMENTS.md) · [v0.5.0-MILESTONE-AUDIT.md](milestones/v0.5.0-MILESTONE-AUDIT.md)  
**Tag:** `v0.5.0`

**What shipped**

1. **Local readiness SSOT** — SETUP-01 / SETUP-02 / DOCS-09 made `/settings` the live-readiness and remediation authority, fixed false-ready defaults, and aligned the docs around one host-first local trial path.
2. **First live run path** — LIVE-01 / LIVE-02 / LIVE-03 promoted `hello-kiln` into the single recommended first local run, moved launch preflight into the backend, and made `/runs/:id` the proof-first arrival surface.
3. **Repository-level first-run proof** — Phase 27 introduced the owning `mix kiln.first_run.prove` command, and Phase 28 repaired the Oban/runtime seam so `UAT-04` now closes on rerun-backed repository evidence.

**Milestone audit:** Ready to close with accepted tech debt on 2026-04-24. Known deferred items at close: 1 (see `STATE.md` Deferred Items).

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
