# Phase 24: Template -> run UAT smoke - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Add automated regression coverage for the existing built-in template -> start run happy path. This phase proves the operator can move from template selection through run start using stable UI selectors and leaves a verification artifact that cites the exact `mix test ...` command used for this slice.

This phase does **not** add new template capabilities, new run behavior, or a broader browser-test strategy. It tightens proof around the current `/templates` flow.

</domain>

<decisions>
## Implementation Decisions

### Regression seam and selector contract

- **D-2401:** Phase 24 should keep **explicit DOM ids** as the primary regression contract for the template flow. Treat the existing ids in `TemplatesLive` as the canonical test seam unless one missing transition boundary must be made explicit.
- **D-2402:** Use a **hybrid selector policy**: ids for operator actions and state transitions, route/destination assertion for completion, and only minimal text assertions for sanity. Text is not the primary contract.
- **D-2403:** Do **not** pivot this flow to text-heavy, semantic-only, or accessibility-only selectors for the owning regression. In LiveView tests, those are more brittle for this operator path and less precise than the existing ids.
- **D-2404:** Additional selector surface is allowed only if it captures a real product state boundary already visible to the operator, such as the success panel after template promotion. Avoid test-hook sprawl.

### Harness ownership

- **D-2405:** `Phoenix.LiveViewTest` is the **owning harness** for this phase. The template -> run regression belongs in the fast, deterministic `mix test` path, not in browser-first E2E.
- **D-2406:** Existing browser coverage remains **thin smoke only**. Do not duplicate the detailed happy-path proof in Playwright or similar unless the flow later gains client-side hooks or browser-only behavior that LiveView tests cannot prove.
- **D-2407:** Phase 24 should prefer a **small, auditable LiveView expansion** over introducing a new harness, new fixtures, or CI orchestration complexity.

### Happy-path proof depth

- **D-2408:** The regression should prove more than a bare redirect tuple. After starting the run, the test should follow navigation and assert a **small stable run-detail invariant** on the destination surface.
- **D-2409:** The preferred terminal invariant is the existing `#run-detail` shell in `RunDetailLive`. This is the right balance between believable user-path proof and low brittleness.
- **D-2410:** Do **not** turn the LiveView smoke into a deep domain-assertion test that re-proves queued-run internals already covered by lower-layer tests such as `Runs.create_for_promoted_template/2`.
- **D-2411:** Redirect-only proof is too weak for this milestone unless the destination shell is also proven. The goal is first-success confidence, not test theater.

### Verification artifact and command shape

- **D-2412:** The phase verification artifact should cite a **focused file-level command**, not a line-number rerun and not a vague broader suite.
- **D-2413:** Default command shape: `mix test test/kiln_web/live/templates_live_test.exs`.
- **D-2414:** The verification doc must state this command as **targeted evidence for the template -> run journey**, not as a claim that it replaces the broader merge-authority suite.
- **D-2415:** If CI is updated for this phase, prefer a dedicated named step that runs the same focused file-level command so the verification artifact and CI evidence stay aligned.

### Coherence with prior phase decisions

- **D-2416:** Preserve the Phase 17 mental model: `/templates` remains the canonical catalog, `Use template` and `Start run` stay separate but adjacent steps in one tight flow.
- **D-2417:** Preserve the Phase 22 honesty model: exact commands must map cleanly to what they prove, and CI remains merge authority for broader correctness.

### the agent's Discretion

- Exact assertion mix inside the LiveView test, as long as ids remain primary and destination proof stays shallow but real.
- Whether one additional success-state selector is needed beyond the existing `#templates-success-panel`.
- Exact wording and structure inside `24-VERIFICATION.md`, as long as the focused `mix test ...` line is cited precisely and honestly.

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set is:
  - Keep id-first selectors for the `/templates` journey.
  - Let `Phoenix.LiveViewTest` own the regression.
  - Follow navigation into the run detail and assert `#run-detail`.
  - Cite `mix test test/kiln_web/live/templates_live_test.exs` in the verification artifact.
- Browser smoke should remain a separate thin full-stack signal, not the owning proof for this feature slice.
- The target UX is calm and unsurprising: the test should read like the operator journey itself, not like an implementation-internals inspection.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements
- `.planning/ROADMAP.md` — Phase 24 goal, success criteria, and milestone boundary for `UAT-03`
- `.planning/REQUIREMENTS.md` — `UAT-03` requirement wording and traceability expectation

### Prior phase decisions
- `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md` — locked template-flow decisions: canonical `/templates` route, separate but adjacent `Use template` and `Start run`, manifest-backed template semantics
- `.planning/phases/22-merge-authority-operator-docs/22-CONTEXT.md` — honesty rules for verification claims and exact command citation expectations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/kiln_web/live/templates_live.ex` — already exposes the operator-path ids: `#template-use-form-<template_id>`, `#templates-success-panel`, `#templates-start-run-form`, `#templates-start-run`
- `lib/kiln_web/live/run_detail_live.ex` — already exposes `#run-detail` as a stable destination shell for post-navigation proof
- `test/kiln_web/live/templates_live_test.exs` — current owning LiveView test file for the template flow; natural place to strengthen Phase 24 coverage

### Established Patterns
- LiveView UI tests already use `Phoenix.LiveViewTest`, `form/2`, `render_submit/1`, and `has_element?/2` in the existing template-flow tests
- Lower-layer tests already cover template promotion and run creation semantics in `test/kiln/specs/template_instantiate_test.exs`, so the UI smoke does not need to re-prove those internals deeply
- Existing route and browser smoke already live elsewhere, so this phase should avoid duplicating them as detailed happy-path ownership

### Integration Points
- Phase 24 likely centers on strengthening `test/kiln_web/live/templates_live_test.exs`
- If needed, minor HEEx changes should stay in `lib/kiln_web/live/templates_live.ex`
- Verification evidence should be recorded in a new Phase 24 verification artifact under `.planning/phases/24-template-run-uat-smoke/`

</code_context>

<deferred>
## Deferred Ideas

- Expanding browser/E2E ownership for the full template -> run journey — defer unless the flow gains browser-only behavior
- Broader run-detail assertions or multi-layer persistence checks inside the LiveView smoke — defer unless lower-layer run creation coverage becomes insufficient

</deferred>

---

*Phase: 24-template-run-uat-smoke*
*Context gathered: 2026-04-23*
