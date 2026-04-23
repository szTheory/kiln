# Phase 20: Phase 19 verification & planning SSOT — Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning  
**Source:** Roadmap Phase 20 detail + `.planning/v0.3.0-MILESTONE-AUDIT.md`

<domain>
## Phase Boundary

Close **milestone audit gaps** for v0.3.0: (1) add formal **`.planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md`** so **SELF-01** and **FEEDBACK-01** meet the three-source gate (VERIFICATION + plan SUMMARYs + REQUIREMENTS); (2) add **`requirements-completed`** to Phase **19** `19-0x-SUMMARY.md` frontmatter where applicable; (3) align **`REQUIREMENTS.md`** checkboxes + traceability table and **`ROADMAP.md`** Phase 19 checkbox with verification outcomes.

**Out of scope:** Re-implementing Phase 19 product behavior; changing runtime code except where a doc error forces a one-line fix (unlikely).

</domain>

<decisions>
## Implementation Decisions

### D-2001 — Verification doc is evidence, not new tests

- **`19-VERIFICATION.md`** records **commands already implied** by `19-VALIDATION.md` + shipped tests; executor **runs** those commands and sets frontmatter **`status: passed`** only when green.
- Must-haves table cites **plan objectives** from `19-01` … `19-05` and maps to **SELF-01** / **FEEDBACK-01** per ROADMAP success criteria.

### D-2002 — SUMMARY frontmatter

- Mirror **Phase 14** pattern: `requirements-completed: [REQ-ID]` on each `19-0x-SUMMARY.md` where that plan materially delivered the requirement (**19-01** FEEDBACK-01; **19-02**/**19-03** SELF-01; **19-04** FEEDBACK-01; **19-05** both).

### D-2003 — REQUIREMENTS + ROADMAP

- After verification passes: mark **SELF-01** and **FEEDBACK-01** checkboxes **`[x]`**; traceability rows **Phase 19**, **Complete**; **ROADMAP** Phase 19 line **`[x]`** with completion date; Phase 20 remains **`[ ]`** until its own execute/verify cycle completes (or mark complete in same PR if team bundles — default: Phase 20 checkbox flips when Phase 20 verification is added later; **minimal change**: only Phase 19 + reqs table in this phase).

### Claude's Discretion

- Exact **comma order** of test paths in `19-VERIFICATION.md` automated block.
- Whether to add a **one-line** note in `19-VALIDATION.md` sign-off pointing to `19-VERIFICATION.md` (optional hygiene).

</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 19–20 goals and success criteria
- `.planning/REQUIREMENTS.md` — SELF-01, FEEDBACK-01, traceability table
- `.planning/v0.3.0-MILESTONE-AUDIT.md` — gap list and three-source matrix
- `.planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md` — task → command map
- `.planning/phases/19-post-mortems-soft-feedback/19-0x-PLAN.md` / `19-0x-SUMMARY.md` — evidence of delivery
- `.planning/phases/18-cost-hints-budget-alerts/18-VERIFICATION.md` — format template for verification doc

</canonical_refs>

<specifics>
## Specific Ideas

- Audit explicitly calls out **missing `19-VERIFICATION.md`** and **REQUIREMENTS.md** drift (checkboxes still open for 14–18 despite passed verifications — refresh **PARA-01 … COST-02** rows to **Complete** while touching the table).

</specifics>

<deferred>
## Deferred Ideas

- None for this phase scope.

</deferred>

---

*Phase: 20-phase-19-verification-planning-ssot*
