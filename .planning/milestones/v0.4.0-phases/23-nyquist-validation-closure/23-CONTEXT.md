# Phase 23: Nyquist / VALIDATION closure - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **NYQ-01** for the shipped v0.3.0 phases still carrying unresolved Nyquist posture in their `VALIDATION.md` artifacts: **14**, **16**, **17**, and **19**. The goal is not to re-implement product behavior or perform broad historical cleanup. The goal is to make each target artifact end Phase 23 in one of two honest states:

- `nyquist_compliant: true` with cited evidence, or
- an explicit **Nyquist waiver** with narrow scope, owner, reason, review-by date, and exit criteria.

Out of scope: repo-wide normalization of old frontmatter/checklists, broad re-auditing of unrelated phases, or inventing a second governance system outside the existing planning artifacts.

</domain>

<decisions>
## Implementation Decisions

### Closure policy

- **D-2301:** Default posture is **closure to `nyquist_compliant: true`**, not blanket waiver for historical phases. Waivers are exceptions, not the normal state.
- **D-2302:** A waiver is only appropriate for a **specific residual gap** that is still non-deterministic, environment-bound, subjective, or intentionally out of milestone scope. No broad “historical artifact” waiver.
- **D-2303:** Phase 23 should optimize for **least surprise** and **operator trust**: no silent `false`, no fake rigor, no “all green” fiction.

### Evidence bar

- **D-2304:** Use a **mixed evidence standard**.
- **D-2305:** Existing `VERIFICATION.md` + plan `SUMMARY.md` evidence is sufficient to flip `nyquist_compliant: true` **when the underlying code paths have not materially changed** and the evidence already proves the core requirement claim.
- **D-2306:** Require a **fresh targeted rerun** only when evidence is missing, stale, caveated in a way that affects the Nyquist claim, or later code drift undermines the older verification.
- **D-2307:** Do **not** require fresh full-suite reruns just to close historical Nyquist debt. CI remains merge authority per `.planning/PROJECT.md`.
- **D-2308:** Grep/diff/manual-only checks are acceptable only for **documentation-only** claims, not runtime behavior.

### Waiver format

- **D-2309:** Use a **compact ADR-lite** waiver block inside the affected `VALIDATION.md`, not a separate file and not a heavyweight ADR.
- **D-2310:** Every waiver block must include:
  - **Scope**
  - **Reason**
  - **Owner**
  - **Review-by**
  - **Exit criteria**
- **D-2311:** Every waiver block should also include:
  - **Operator impact**
  - **Evidence**
- **D-2312:** Waiver wording must be factual, calm, and absolute-date based. Avoid vague “temporary” language without a concrete exit condition.

### Exact waiver shape

- **D-2313:** Use this exact section shape when a waiver is needed:

```md
## Nyquist waiver

- Scope: Nyquist compliance for this VALIDATION.md artifact only
- Reason: <plain-English reason this artifact remains non-compliant>
- Owner: @jon
- Review-by: 2026-05-23
- Exit criteria: <objective condition that permits `nyquist_compliant: true`>
- Operator impact: <what an operator should believe today>
- Evidence: <verification artifact / command / phase citation>
```

### Artifact scope

- **D-2314:** Primary edits belong in the four target `VALIDATION.md` files only: phases **14**, **16**, **17**, **19**.
- **D-2315:** Matching `VERIFICATION.md` files may be updated **only where a direct evidence anchor or waiver rationale is missing or unclear**.
- **D-2316:** Avoid broader cleanup of historical statuses, checklist wording, `verified` vs `verified_at`, or unrelated frontmatter drift in this phase.
- **D-2317:** After Phase 23 verification passes, perform the minimal SSOT updates needed to mark **NYQ-01** complete in `.planning/REQUIREMENTS.md` and Phase 23 complete in `.planning/ROADMAP.md`.

### Per-phase recommendations

- **D-2318 — Phase 14:** Close to **`nyquist_compliant: true`**. Existing `14-VERIFICATION.md` and phase summaries already support the core fairness/telemetry claim; this reads as closure lag, not unresolved risk.
- **D-2319 — Phase 17:** Close to **`nyquist_compliant: true`**. Existing `17-VERIFICATION.md` and shipped template/onboarding evidence are sufficient for the phase’s core requirement claims.
- **D-2320 — Phase 19:** Close to **`nyquist_compliant: true`**. Existing `19-VERIFICATION.md` plus the Phase 20 SSOT work make this a clear closure case.
- **D-2321 — Phase 16:** Default to an explicit **narrow Nyquist waiver** unless planning finds a clean, honest way to convert the remaining manual “scrubber feel” note into a non-blocking observation that no longer conflicts with compliance. Do not mark true while leaving a blocking manual-only caveat in place.

### the agent's Discretion

- Whether any of the four target `VERIFICATION.md` files need a short “Nyquist evidence” note for clearer local citations.
- Whether Phase 16 can be honestly reframed to compliant without hiding the residual UX caveat. Default remains **waiver** unless that reframing is clearly defensible.
- Exact citation style inside the updated `VALIDATION.md` files.

</decisions>

<specifics>
## Specific Ideas

- Research across Elixir/Phoenix and adjacent ecosystems converged on the same norm: **strict by default, explicit local exceptions when needed**.
- Useful precedent patterns:
  - **ExUnit** skip tags make exceptions explicit, not silent.
  - **Credo** disable comments are local and named.
  - **Phoenix.LiveViewTest** favors concrete executable UI assertions over prose-only validation.
  - **Rust**, **Rails**, and **Cargo** normalize targeted reruns for the narrowest proving scope, while CI remains the broad authority.
  - **GitHub code scanning**, **ESLint**, **TypeScript**, and **pytest** all reinforce “named suppressions/exceptions with reasons” over silent drift.
- DX principle locked for this phase: prefer **small, auditable edits** over broad cleanup theater.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone / requirement truth

- `.planning/PROJECT.md` — CI merge authority, trust posture, bounded autonomy
- `.planning/REQUIREMENTS.md` — **NYQ-01** requirement text
- `.planning/ROADMAP.md` — Phase 23 goal and success criteria
- `.planning/MILESTONES.md` — v0.4.0 milestone intent

### Target artifacts

- `.planning/phases/14-fair-parallel-runs/14-VALIDATION.md`
- `.planning/phases/16-read-only-run-replay/16-VALIDATION.md`
- `.planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md`
- `.planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md`
- `.planning/phases/14-fair-parallel-runs/14-VERIFICATION.md`
- `.planning/phases/16-read-only-run-replay/16-VERIFICATION.md`
- `.planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md`
- `.planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md`

### Prior planning / SSOT precedent

- `.planning/phases/20-phase-19-verification-planning-ssot/20-CONTEXT.md`
- `.planning/phases/20-phase-19-verification-planning-ssot/20-RESEARCH.md`
- `.planning/milestones/v0.3.0-MILESTONE-AUDIT.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **Per-phase `VERIFICATION.md` files** already act as the primary evidence artifact for historical closure.
- **Plan `SUMMARY.md` files** provide local proof that the intended task-level work and self-checks landed.
- **Phase 20** established the repo pattern for targeted verification/document SSOT repair without reopening implementation scope.

### Established patterns

- Small planning phases should make **local, evidence-backed artifact repairs**, then flip top-level SSOT after verification.
- Verification artifacts are **evidence**, not a second implementation wave.
- CI is the broad merge authority; local reruns should be the **narrowest proving commands**.

### Integration points

- The target `VALIDATION.md` files should cite the existing evidence in their sibling `VERIFICATION.md` / `SUMMARY.md` artifacts.
- Phase 23 verification should be the gate before updating `REQUIREMENTS.md` and `ROADMAP.md`.

</code_context>

<deferred>
## Deferred Ideas

- Repo-wide normalization of historical `VALIDATION.md` frontmatter and checklist phrasing.
- A generalized Nyquist waiver schema or lint rule across all phases.
- Re-auditing older phases outside **14 / 16 / 17 / 19**.

None of the above belong in Phase 23.

</deferred>

---

*Phase: 23-nyquist-validation-closure*
*Context gathered: 2026-04-23*
