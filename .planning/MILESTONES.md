# Milestones

Living summary of shipped versions. Detailed phase history lives under `.planning/milestones/` and `.planning/phases/`.

## v0.2.0 — Operator dogfood

**Shipped:** 2026-04-22  
**Phases:** 10–13 (4 plans)  
**Archives:** [v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md) · [v0.2.0-REQUIREMENTS.md](milestones/v0.2.0-REQUIREMENTS.md)  
**Tag:** `v0.2.0`

**What shipped**

- **Phase 10 — Local operator readiness:** README / `test/integration/first_run.sh` / Mix `integration.first_run` parity; operator cold-path SSOT for dogfood.
- **Phase 11 — Game Boy dogfood vertical slice:** `rust_gb_dogfood_v1` workflow, argv-only scenario shell oracle, `priv/dogfood/gb_vertical_slice_spec.md`, compiler/parser tests; external Rust workspace + ROM execution remains operator-owned (`GB-SPIKE.md`).
- **Phase 12 — Local Docker / dev DX:** Optional `justfile` + README “Just” path + `LOCAL-DX-AUDIT.md` alignment. **Known gap:** `12-01-SUMMARY.md` Self-Check PARTIAL — full `mix check` authority is CI / DB-backed workstation.
- **Phase 13 — Requirements & roadmap hygiene:** All v1 `REQUIREMENTS.md` rows `[x]`; traceability **Complete**; `DOCS-ALIGN-01` validated.

## v0.1.0 — Foundation through dogfood release

**Reference:** [.planning/milestones/v0.1.0.md](milestones/v0.1.0.md)  
**Scope:** Phases 1–9 (+ parking **999.1**). Operator follow-ups (tag `v0.1.0` + GitHub Release) remain per `09-05-SUMMARY.md` when ready.
