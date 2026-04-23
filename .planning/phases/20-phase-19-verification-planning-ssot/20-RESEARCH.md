# Phase 20 — Research

**Question:** What do we need to know to plan **verification SSOT** and **requirements/roadmap alignment** without re-auditing the whole codebase?

## RESEARCH COMPLETE

### Findings

1. **Verification artifact pattern:** Phases **14–18** ship `*-VERIFICATION.md` beside the phase dir with YAML frontmatter `status: passed`, sections **Automated**, **Must-haves (from plans)**, optional **Human verification**. **Phase 18** (`18-VERIFICATION.md`) is the closest analog — short, command-first, table of plan-derived must-haves.

2. **Phase 19 evidence:** `19-VALIDATION.md` already lists scoped **`mix test`** commands per task; **`19-0x-SUMMARY.md`** files exist with **Self-Check: PASSED** narratives but omit **`requirements-completed`** in YAML (audit gap).

3. **Milestone audit:** `.planning/v0.3.0-MILESTONE-AUDIT.md` frontmatter lists **SELF-01** / **FEEDBACK-01** as **partial** solely due to missing formal verification + doc drift; integration note asserts static pass on key routes/tests.

4. **REQUIREMENTS.md:** v0.3.0 section already has **PARA-01 … COST-02** as `[x]` in the list body; traceability table still shows some **Complete** vs checkbox narrative — Phase 20 should make **traceability** rows consistent (**Phase 19**, **Complete** for SELF/FEEDBACK after verification).

5. **No schema migrations** in Phase 20 scope — planning/docs only; no `[BLOCKING]` schema push injection.

### Risk

- Running **full** `mix test` may be slow; prefer **scoped paths** from `19-VALIDATION.md` + `mix compile --warnings-as-errors` as in Phase 18 verification style.

---

## Validation Architecture

Phase 20 execution validates **documentation SSOT**, not new product modules:

| Dimension | Approach |
|-----------|----------|
| D1 Requirements | `19-VERIFICATION.md` cites SELF-01 + FEEDBACK-01 must-haves traceable to `19-0x-PLAN.md` |
| D2 Automated | Scoped `mix test` + `mix compile --warnings-as-errors` listed and run before `status: passed` |
| D3 Nyquist | `20-VALIDATION.md` maps each plan task to doc-editing + command verification |

Executor records **actual** command exit status in verification narrative or relies on CI parity; file frontmatter **`status: passed`** is set only after local green (or documented CI-only exception — default: local green).
