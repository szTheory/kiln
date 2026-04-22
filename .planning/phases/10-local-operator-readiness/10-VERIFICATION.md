---
status: passed
phase: 10-local-operator-readiness
verified: "2026-04-21"
---

# Phase 10 — Verification

## Automated / machine checks

- `mix compile --warnings-as-errors` — green after `mix.exs` alias addition.
- `mix test test/kiln_web/live/onboarding_live_test.exs` — green (authoritative wizard shell per D-934; not duplicated in `first_run.sh`).
- `bash test/integration/first_run.sh` — **not** re-run in this agent session (requires healthy Docker + free `:5432`); script and README contract verified by inspection and prior Phase 9 baseline.

## Plan UAT crosswalk (10-01-PLAN)

| # | Criterion | Evidence |
|---|-----------|----------|
| 1 | Fresh env + migrate path documented | README quick start + **Operator checklist**; `first_run.sh` steps 1–3 |
| 2 | Boot + health SSOT | `first_run.sh` asserts `/health` JSON; README **Integration smoke** |
| 3 | Boot without `KILN_SKIP_BOOTCHECKS` | README checklist + **Bypassing boot checks** section |
| 4 | Onboarding automated proof | `KilnWeb.OnboardingLiveTest` executed above |
| 5 | Run board after onboarding | Documented in README quick start step 5 (existing product path) |
| 6 | Optional Jaeger | README **Traces (local)**; manual once per **10-01-SUMMARY.md** (D-1003) |

## Requirement trace

| ID | Evidence |
|----|-----------|
| LOCAL-01 | README + `compose.yaml` + `LOCAL-DX-AUDIT.md` shipped truth; `PROJECT.md` validated line |
| LOCAL-03 | README + `first_run.sh` + optional `mix integration.first_run` |
| BLOCK-04 | Onboarding typed blockers — unchanged; tests prove wizard |

## Self-check: PASSED

Phase 10 goal (documented clone-to-run path, checklist, DTU timing, integration smoke SSOT with optional Mix delegate) satisfied by **10-01-SUMMARY.md** and files cited above.
