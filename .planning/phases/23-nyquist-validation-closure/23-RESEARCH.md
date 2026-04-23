# Phase 23: Nyquist / VALIDATION closure - Research

**Researched:** 2026-04-23  
**Domain:** Planning-artifact validation closure for Nyquist posture and requirement traceability. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**Confidence:** HIGH. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VALIDATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md]

<user_constraints>
## User Constraints (from CONTEXT.md)

Verbatim copy from `.planning/phases/23-nyquist-validation-closure/23-CONTEXT.md`. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

- Repo-wide normalization of historical `VALIDATION.md` frontmatter and checklist phrasing.
- A generalized Nyquist waiver schema or lint rule across all phases.
- Re-auditing older phases outside **14 / 16 / 17 / 19**.

None of the above belong in Phase 23.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NYQ-01 | For phases 14, 16, 17, and 19, each `*-VALIDATION.md` ends v0.4.0 with either `nyquist_compliant: true` with cited evidence or an explicit `## Nyquist waiver` subsection with reason, owner, and review-by date. [VERIFIED: .planning/REQUIREMENTS.md] | Use the sibling `VERIFICATION.md` and `SUMMARY.md` artifacts as the default proof source, update only the four target `VALIDATION.md` files first, treat Phase 16 as the only likely waiver case, and flip `.planning/REQUIREMENTS.md` only after Phase 23 verification passes. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Use a GSD workflow entry point before file-changing work; do not make direct repo edits outside GSD unless the user explicitly asks to bypass it. [VERIFIED: CLAUDE.md]
- Kiln is a single Phoenix app with strict bounded contexts; this phase should not invent new side-channel governance outside the existing planning artifacts. [VERIFIED: CLAUDE.md]
- `mix check` is the CI merge gate for the public repo. [VERIFIED: CLAUDE.md]

## Project Constraints (from AGENTS.md)

- Run `just precommit` or `bash script/precommit.sh` after changes; `mix precommit` is acceptable if the shell already exports the required env vars. [VERIFIED: AGENTS.md] [VERIFIED: script/precommit.sh] [VERIFIED: mix.exs]
- Before `/gsd-plan-phase N --gaps`, run `just shift-left` or `mix shift_left.verify`; `just planning-gates` or `mix planning.gates` is the narrower `mix check`-only gate. [VERIFIED: AGENTS.md] [VERIFIED: mix help planning.gates] [VERIFIED: script/planning_gates.sh]
- Prefer the existing `mix` tasks and repo scripts over assuming `just` is installed. `just` was not available in this workspace audit, while `mix`, `bash`, `git`, `grep`, and `rg` were available. [VERIFIED: codebase grep] [VERIFIED: local command audit]

## Summary

Phase 23 is a documentation-governance closure phase, not a product reimplementation phase. The locked scope is only phases 14, 16, 17, and 19, and the success condition is explicit Nyquist posture in each target `VALIDATION.md`: either `nyquist_compliant: true` with evidence, or an inline waiver with owner and review-by date. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

The repository already contains the evidence needed for three of the four targets. Phases 14, 17, and 19 each have passed `VERIFICATION.md` artifacts plus plan `SUMMARY.md` files with requirement-completion metadata and self-check commands, which matches the mixed-evidence standard locked in Phase 23 context. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-01-SUMMARY.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-02-SUMMARY.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-03-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-01-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-02-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-03-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-01-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-02-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-03-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-04-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-05-SUMMARY.md]

Phase 16 is the only phase that still presents a real planning decision. Its verification artifact is passed, but its validation artifact still records a manual-only “scrubber feel” check, and the locked context explicitly says not to mark it compliant while leaving a blocking manual-only caveat in place. The planner should therefore assume a narrow waiver unless it can honestly restate that note as non-blocking operator guidance without weakening the truth standard. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

**Primary recommendation:** Plan Phase 23 as a four-file evidence-linking pass plus minimal SSOT follow-through: flip 14, 17, and 19 to `nyquist_compliant: true`, default 16 to an inline waiver, create `23-VERIFICATION.md` proving those edits, then mark `NYQ-01` complete in `.planning/REQUIREMENTS.md` and Phase 23 complete in `.planning/ROADMAP.md`. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Decide per-phase Nyquist posture for 14/16/17/19 | Planning artifacts | Verification artifacts | The decision is expressed in each target `*-VALIDATION.md`, while sibling `*-VERIFICATION.md` files provide the proof base. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VALIDATION.md] [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md] |
| Record exception policy when compliance is not honest | Planning artifacts | Phase context | The waiver format and mandatory fields are locked in `23-CONTEXT.md`, and the waiver lives inside the affected `VALIDATION.md`. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Prove Phase 23 itself is complete | Verification artifacts | Planning artifacts | The roadmap success criteria say `NYQ-01` traceability moves only when verification passes, so Phase 23 needs its own verification artifact before SSOT flips. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] |
| Update milestone-level truth after closure | SSOT docs | Phase verification | `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` are the downstream truth surfaces, and context locks those edits to “after verification passes.” [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `*-VALIDATION.md` artifact | repo-local pattern | Decision surface for Nyquist posture | The four target files already carry `nyquist_compliant: false`, validation sign-off sections, and phase-specific verification maps, so closure belongs here rather than in a new governance file. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VALIDATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| `*-VERIFICATION.md` artifact | repo-local pattern | Primary evidence source | All four targets already have sibling verification docs with passed status and concrete commands or must-have evidence, which matches the mixed-evidence policy for this phase. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| `*-SUMMARY.md` artifacts | repo-local pattern | Secondary proof and requirement mapping | Summary files for the target phases record self-check commands and `requirements-completed`, which lets the planner cite implementation-level proof without reopening product scope. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-01-SUMMARY.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-01-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-01-SUMMARY.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-01-SUMMARY.md] |
| `.planning/REQUIREMENTS.md` + `.planning/ROADMAP.md` | repo-local SSOT | Final traceability and phase completion | The roadmap and requirements files are the only milestone-level places this phase needs to touch after verification succeeds. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `rg` | 15.1.0 | Fast audit of target docs and sign-off fields | Use for scoped closure checks and citation discovery. [VERIFIED: local command audit] |
| `grep` | 2.6.0-FreeBSD | Small exact-match artifact checks | Use for final verification one-liners and sign-off assertions. [VERIFIED: local command audit] |
| `mix planning.gates` / `script/planning_gates.sh` | repo task/script | CI-parity `mix check` before gap planning | Use before `/gsd-plan-phase 23 --gaps`; it is the project’s narrow check-only gate. [VERIFIED: AGENTS.md] [VERIFIED: mix help planning.gates] [VERIFIED: script/planning_gates.sh] |
| `mix precommit` / `script/precommit.sh` | repo alias/script | Final local guard after edits | Use after research/planning/execute docs changes; `mix precommit` resolves to `templates.verify` then `check`, and the script supplies CI-parity env defaults. [VERIFIED: AGENTS.md] [VERIFIED: mix help precommit] [VERIFIED: mix.exs] [VERIFIED: script/precommit.sh] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline `VALIDATION.md` waiver block | Separate ADR or waiver file | Rejected because the locked context requires a compact ADR-lite block inside the affected `VALIDATION.md`, and adding a new file would create a second governance surface. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Existing verification + summary evidence | Fresh full-suite reruns for every target phase | Rejected because the locked evidence policy says existing proof is enough when code paths have not materially changed, and fresh reruns are only required for missing, stale, or drift-undermined evidence. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Four-file surgical closure | Repo-wide normalization of historical validation artifacts | Rejected because the context explicitly marks broader normalization out of scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |

**Installation:** No new packages or frameworks are needed; this phase uses existing repo artifacts, `mix` tasks, and shell tools already present in the workspace. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: mix.exs] [VERIFIED: local command audit]

**Version verification:** `mix` was available as Mix 1.19.5 on OTP 28, `git` was available as 2.41.0, `rg` was available as 15.1.0, and `just` was not available in this workspace, so plans should prefer `mix` and `script/*` fallbacks over `just`-only commands. [VERIFIED: local command audit]

## Architecture Patterns

### System Architecture Diagram

```text
NYQ-01 requirement + Phase 23 context
            |
            v
   Identify target artifacts
   (14 / 16 / 17 / 19 VALIDATION)
            |
            v
 Collect local evidence from:
 - sibling VERIFICATION.md
 - plan SUMMARY.md
 - prior SSOT / milestone audit
            |
            v
      Decision per phase
   +-----------------------+
   | Evidence honest for   |
   | nyquist_compliant?    |
   +-----------------------+
      | yes                    | no
      v                        v
 set nyquist_compliant:true   add inline Nyquist waiver
 cite evidence                owner + review-by + exit criteria
      \                        /
       \                      /
        v                    v
        Phase 23 verification artifact
                 |
                 v
        SSOT updates after verification:
        REQUIREMENTS.md traceability
        ROADMAP.md phase completion
```

The primary flow is evidence collection first, posture decision second, SSOT updates last. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]

### Recommended Project Structure

```text
.planning/
├── REQUIREMENTS.md                     # NYQ-01 traceability flips only after Phase 23 verification
├── ROADMAP.md                          # Phase 23 completion flips only after verification
└── phases/
    ├── 14-fair-parallel-runs/
    │   ├── 14-VALIDATION.md            # likely true
    │   ├── 14-VERIFICATION.md          # evidence
    │   └── 14-0x-SUMMARY.md            # supporting proof
    ├── 16-read-only-run-replay/
    │   ├── 16-VALIDATION.md            # likely waiver unless manual caveat is reframed honestly
    │   ├── 16-VERIFICATION.md          # evidence
    │   └── 16-0x-SUMMARY.md            # supporting proof
    ├── 17-template-library-onboarding-specs/
    ├── 19-post-mortems-soft-feedback/
    └── 23-nyquist-validation-closure/
        ├── 23-CONTEXT.md               # locked decisions
        ├── 23-RESEARCH.md              # this file
        └── 23-VERIFICATION.md          # required before SSOT flips
```

All required artifacts already exist except `23-VERIFICATION.md`, which the execution plan should create as the closure proof for this phase. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: codebase grep]

### Pattern 1: Evidence-First Local Closure

**What:** Decide each target `VALIDATION.md` from existing local evidence before considering reruns. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**When to use:** Default for phases 14, 17, and 19 because their verification and summary artifacts already demonstrate shipped behavior with passed checks. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md]

**Example:**
```md
---
nyquist_compliant: true
updated: 2026-04-23
---

## Validation Sign-Off

- [x] `nyquist_compliant: true` set in frontmatter after execute-phase

**Approval:** signed off 2026-04-23 (`14-VERIFICATION.md`, `14-01-SUMMARY.md`, `14-02-SUMMARY.md`, `14-03-SUMMARY.md`)
```
Source pattern: existing compliant validation artifacts plus the locked evidence policy. [VERIFIED: .planning/phases/22-merge-authority-operator-docs/22-VALIDATION.md] [VERIFIED: .planning/phases/15-run-comparison/15-VALIDATION.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

### Pattern 2: Inline Waiver, Not Separate Governance

**What:** Keep any exception local to the affected `VALIDATION.md` with the exact waiver block shape from context. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**When to use:** Only when a narrow residual gap remains genuinely non-deterministic, manual, or out of scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

**Example:**
```md
## Nyquist waiver

- Scope: Nyquist compliance for this VALIDATION.md artifact only
- Reason: Residual manual-only scrubber-feel observation remains operator-judgment, not a runtime correctness gap
- Owner: @jon
- Review-by: 2026-05-23
- Exit criteria: Replace the manual-only note with a non-blocking observation or automate the remaining UX signal
- Operator impact: Replay remains read-only and verified for routing, query behavior, and mutation safety
- Evidence: `16-VERIFICATION.md`, `16-01-SUMMARY.md`, `16-02-SUMMARY.md`, `16-03-SUMMARY.md`
```
Source pattern: exact waiver shape locked in context; Phase 16 is the default waiver candidate. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md]

### Pattern 3: SSOT Last

**What:** Update `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` only after the phase’s own verification artifact says the closure work passed. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**When to use:** Always for this phase; the roadmap success criteria explicitly depend on verification passing first. [VERIFIED: .planning/ROADMAP.md]

**Example:**
```md
| Requirement | Phase | Status |
|-------------|-------|--------|
| NYQ-01 | Phase 23 | Complete |
```
Source pattern: requirements traceability row is pending now and is intended to flip after Phase 23 verification. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]

### Anti-Patterns to Avoid

- **Blanket waivering all four phases:** The context locks `true` as the default posture and treats waivers as exceptions. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
- **Creating a second waiver registry:** The context explicitly requires the waiver to live inside the affected `VALIDATION.md`. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
- **Flipping `nyquist_compliant: true` without local citations:** This phase’s requirement is “true with cited evidence” or explicit waiver, not “true because the milestone shipped.” [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
- **Updating SSOT before verification:** The roadmap and context both make verification the gate before `NYQ-01` and Phase 23 completion are marked complete. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
- **Treating the Phase 16 manual-only note as harmless by default:** The locked context explicitly warns against calling it compliant while a blocking manual-only caveat still stands. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exception recording | Separate ADR file, issue, or JSON registry | Inline `## Nyquist waiver` block in the affected `VALIDATION.md` | The exact waiver shape is already locked, and keeping it local avoids a second source of truth. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Closure proof | New custom audit script or repo-wide linter | Existing `VERIFICATION.md` + `SUMMARY.md` evidence, plus a small `23-VERIFICATION.md` | The repo already uses verification artifacts as closure proof, and this phase is scoped to documentation posture rather than new runtime validation. [VERIFIED: .planning/phases/20-phase-19-verification-planning-ssot/20-CONTEXT.md] [VERIFIED: .planning/phases/20-phase-19-verification-planning-ssot/20-RESEARCH.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Final gate | `just`-only commands | `mix precommit`, `mix planning.gates`, `bash script/precommit.sh`, `bash script/planning_gates.sh` | `just` was not available in this workspace, while the repo already provides `mix` aliases and shell fallbacks. [VERIFIED: AGENTS.md] [VERIFIED: mix.exs] [VERIFIED: script/precommit.sh] [VERIFIED: script/planning_gates.sh] [VERIFIED: local command audit] |

**Key insight:** This phase should reuse the repo’s existing evidence surfaces and only repair the missing decision layer. The expensive mistake is inventing new process when the real gap is an explicit recorded posture. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/milestones/v0.3.0-MILESTONE-AUDIT.md]

## Common Pitfalls

### Pitfall 1: Treating Historical `false` as a Runtime Failure

**What goes wrong:** The planner reopens implementation or asks for broad reruns even though the context says the problem is silent posture, not missing shipped behavior. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**Why it happens:** `nyquist_compliant: false` looks like a product gap when it is actually a documentation-closure gap for three of the four targets. [VERIFIED: .planning/phases/14-fair-parallel-runs/14-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/19-post-mortems-soft-feedback/19-VERIFICATION.md]  
**How to avoid:** Start from sibling verification and summary artifacts, and require reruns only when evidence is missing, stale, or undermined by later drift. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**Warning signs:** Plans that add new product tests or refactors to Phases 14, 17, or 19. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

### Pitfall 2: Making Phase 16 Look Cleaner Than It Is

**What goes wrong:** The plan flips Phase 16 to compliant while its `VALIDATION.md` still contains a manual-only operator-feel caveat that reads like a blocking gap. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md]  
**Why it happens:** The verification doc passed, so it is tempting to ignore the validation artifact’s stricter wording. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md]  
**How to avoid:** Either rewrite the residual note into a clearly non-blocking observation with evidence, or keep the default narrow waiver. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**Warning signs:** Approval text that says “signed off” while a manual-only row still implies the artifact is not fully Nyquist-complete. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md]

### Pitfall 3: Updating SSOT Too Early

**What goes wrong:** `NYQ-01` or the roadmap checkbox flips before Phase 23 has its own verification artifact. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]  
**Why it happens:** The target edits are small, so the final traceability update can look harmless. [VERIFIED: .planning/ROADMAP.md]  
**How to avoid:** Make `23-VERIFICATION.md` an explicit plan deliverable and sequence SSOT edits after it passes. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** A plan that edits `REQUIREMENTS.md` in the same task that decides per-phase posture, with no explicit verification step. [VERIFIED: .planning/ROADMAP.md]

## Code Examples

Verified patterns from repository sources:

### Compliant Validation Closure
```md
---
status: complete
nyquist_compliant: true
updated: 2026-04-23
---

## Validation Sign-Off

- [x] `nyquist_compliant: true` set in frontmatter after execute-phase

**Approval:** signed off 2026-04-23 (`17-VERIFICATION.md`, `17-01-SUMMARY.md`, `17-02-SUMMARY.md`, `17-03-SUMMARY.md`)
```
Source: compliant validation artifact shape plus target evidence sources. [VERIFIED: .planning/phases/22-merge-authority-operator-docs/22-VALIDATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-VERIFICATION.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-01-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-02-SUMMARY.md] [VERIFIED: .planning/phases/17-template-library-onboarding-specs/17-03-SUMMARY.md]

### Inline Nyquist Waiver
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
Source: exact waiver block locked in Phase 23 context. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Silent `nyquist_compliant: false` in historical `VALIDATION.md` files | Explicit `nyquist_compliant: true` with evidence or inline waiver with owner and review-by | v0.4.0 Phase 23 scope opened 2026-04-23. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] | Removes silent ambiguity and makes operator trust posture explicit. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Fresh reruns as the instinctive closure move | Reuse existing verification unless evidence is missing, stale, caveated, or drift-undermined | Locked in D-2305 through D-2307 on 2026-04-23. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | Keeps this phase small and auditable instead of reopening runtime scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Exception policy in separate process memory | Compact waiver block in the affected artifact | Locked in D-2309 through D-2313 on 2026-04-23. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | Preserves local traceability and avoids a second SSOT. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |

**Deprecated/outdated:**
- Silent `partial` posture with no waiver path is outdated for the four targeted v0.3.0 phases. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | No assumed claims remain; all recommendations above were tied to repo artifacts or local tool audits. [VERIFIED: codebase grep] | n/a | n/a |

## Open Questions

1. **Can Phase 16 be reframed to compliant without a waiver?** [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
   - What we know: `16-VERIFICATION.md` is passed, but `16-VALIDATION.md` still lists a manual-only “Range slider debounce feel” check. [VERIFIED: .planning/phases/16-read-only-run-replay/16-VERIFICATION.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md]
   - What's unclear: whether that note can be rewritten as non-blocking operator guidance without weakening the honesty standard. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
   - Recommendation: Default the plan to a narrow waiver and only switch to compliant if the planner can produce exact replacement wording that keeps the artifact factually stronger, not merely cleaner. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | `planning.gates`, `precommit`, final verification commands | ✓ [VERIFIED: local command audit] | 1.19.5 / OTP 28 [VERIFIED: local command audit] | — |
| `bash` | `script/precommit.sh`, `script/planning_gates.sh` | ✓ [VERIFIED: local command audit] | 5.2.37 [VERIFIED: local command audit] | — |
| `git` | repo diff review and commit flow | ✓ [VERIFIED: local command audit] | 2.41.0 [VERIFIED: local command audit] | — |
| `rg` | scoped artifact audit | ✓ [VERIFIED: local command audit] | 15.1.0 [VERIFIED: local command audit] | `grep` [VERIFIED: local command audit] |
| `just` | optional AGENTS convenience commands | ✗ [VERIFIED: local command audit] | — | `mix precommit`, `mix planning.gates`, `bash script/precommit.sh`, `bash script/planning_gates.sh` [VERIFIED: AGENTS.md] [VERIFIED: mix.exs] [VERIFIED: script/precommit.sh] [VERIFIED: script/planning_gates.sh] |

**Missing dependencies with no fallback:**
- None for this phase. [VERIFIED: local command audit]

**Missing dependencies with fallback:**
- `just` is absent, but every referenced command path has a `mix` or `bash` fallback already documented in the repo. [VERIFIED: AGENTS.md] [VERIFIED: mix.exs] [VERIFIED: script/precommit.sh] [VERIFIED: script/planning_gates.sh]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Repository artifact verification plus project gate commands. [VERIFIED: .planning/phases/22-merge-authority-operator-docs/22-VALIDATION.md] [VERIFIED: AGENTS.md] |
| Config file | none for the doc checks themselves; gate commands are defined in `mix.exs`, `script/precommit.sh`, and `script/planning_gates.sh`. [VERIFIED: mix.exs] [VERIFIED: script/precommit.sh] [VERIFIED: script/planning_gates.sh] |
| Quick run command | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' \"$f\" || grep -q '^## Nyquist waiver$' \"$f\"; done` [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Full suite command | `bash script/precommit.sh` after changes; `mix planning.gates` before gap planning if needed. [VERIFIED: AGENTS.md] [VERIFIED: script/precommit.sh] [VERIFIED: mix help planning.gates] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NYQ-01 | Each targeted `VALIDATION.md` ends with either `nyquist_compliant: true` and cited evidence or an explicit `## Nyquist waiver`, and SSOT flips only after Phase 23 verification passes. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] | doc + grep + artifact review [VERIFIED: .planning/phases/22-merge-authority-operator-docs/22-VALIDATION.md] | `for f in .planning/phases/14-fair-parallel-runs/14-VALIDATION.md .planning/phases/16-read-only-run-replay/16-VALIDATION.md .planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md .planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md; do grep -q '^nyquist_compliant: true$' \"$f\" || grep -q '^## Nyquist waiver$' \"$f\"; done && grep -q '| NYQ-01 | Phase 23 | Complete |' .planning/REQUIREMENTS.md` [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | ✅ existing artifacts, plus `23-VERIFICATION.md` to be created in execution. [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** Run the smallest grep loop that proves the edited target artifact still has an explicit Nyquist posture. [VERIFIED: .planning/REQUIREMENTS.md]
- **Per wave merge:** Re-run the four-file posture loop and inspect any touched `VERIFICATION.md` or `SUMMARY.md` citations. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
- **Phase gate:** `bash script/precommit.sh` plus a passed `23-VERIFICATION.md` before SSOT flips. [VERIFIED: AGENTS.md] [VERIFIED: script/precommit.sh] [VERIFIED: .planning/ROADMAP.md]

### Wave 0 Gaps

- [ ] `23-VERIFICATION.md` — execution must add this artifact so `NYQ-01` and the Phase 23 roadmap row can move to complete honestly. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]
- [ ] Optional: add one-line “Nyquist evidence” notes to any target `VERIFICATION.md` only if the local citation trail is too implicit for the planner. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | n/a — this phase edits planning artifacts only. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| V3 Session Management | no [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | n/a — no runtime session behavior is in scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| V4 Access Control | no [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | n/a — no permission surface changes are in scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| V5 Input Validation | no [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | n/a — waiver fields are documentation content, not a runtime input parser change. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| V6 Cryptography | no [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] | n/a — no crypto behavior or secret handling changes are in scope. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| False-positive compliance claim | Repudiation | Require evidence citations in each `VALIDATION.md` that flips to `true`, backed by sibling `VERIFICATION.md` and `SUMMARY.md` artifacts. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| Silent exception drift | Tampering | Use an inline waiver with owner, absolute review-by date, and exit criteria instead of leaving `false` unexplained. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |
| SSOT drift between phase docs and milestone docs | Tampering | Sequence `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` edits after Phase 23 verification passes. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/23-nyquist-validation-closure/23-CONTEXT.md` - locked closure policy, evidence bar, waiver shape, target scope.
- `.planning/REQUIREMENTS.md` - `NYQ-01` text and traceability row.
- `.planning/ROADMAP.md` - Phase 23 goal and success criteria.
- `.planning/phases/14-fair-parallel-runs/14-VALIDATION.md` and `14-VERIFICATION.md` - current posture and evidence.
- `.planning/phases/16-read-only-run-replay/16-VALIDATION.md` and `16-VERIFICATION.md` - current posture and the only live waiver decision.
- `.planning/phases/17-template-library-onboarding-specs/17-VALIDATION.md` and `17-VERIFICATION.md` - current posture and evidence.
- `.planning/phases/19-post-mortems-soft-feedback/19-VALIDATION.md` and `19-VERIFICATION.md` - current posture and evidence.
- `.planning/phases/14-fair-parallel-runs/*SUMMARY.md`, `.planning/phases/16-read-only-run-replay/*SUMMARY.md`, `.planning/phases/17-template-library-onboarding-specs/*SUMMARY.md`, `.planning/phases/19-post-mortems-soft-feedback/*SUMMARY.md` - plan-level self-check and requirement-completion evidence.
- `AGENTS.md`, `CLAUDE.md`, `mix.exs`, `script/precommit.sh`, `script/planning_gates.sh`, `mix help planning.gates`, `mix help precommit` - project and command constraints.

### Secondary (MEDIUM confidence)

- `.planning/phases/20-phase-19-verification-planning-ssot/20-CONTEXT.md` and `20-RESEARCH.md` - precedent for verification-first SSOT repair in a planning-only phase.
- `.planning/milestones/v0.3.0-MILESTONE-AUDIT.md` - milestone-level note that Nyquist remained partial for 14/16/17/19 at close.

### Tertiary (LOW confidence)

- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the phase uses existing repo artifacts and locally audited tools, not a changing external ecosystem. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: local command audit]
- Architecture: HIGH - the work is explicitly scoped to planning artifacts, verification artifacts, and SSOT files. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]
- Pitfalls: HIGH - the main failure modes are already named in the phase context and visible in the current target artifacts. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md] [VERIFIED: .planning/phases/16-read-only-run-replay/16-VALIDATION.md]

**Research date:** 2026-04-23. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]  
**Valid until:** 2026-05-23 for planning purposes, unless the target artifacts change before planning starts. [VERIFIED: .planning/phases/23-nyquist-validation-closure/23-CONTEXT.md]
