# Phase 27: Local first-run proof - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Leave milestone `v0.5.0` with **one explicit, repeatable proof command** that shows Kiln's local-first operator journey works end to end. The proof must be honest about the **real local topology** and still prove the **operator-visible first-run path** rather than only backend internals or a generic health probe.

This phase is about **proof ownership, command shape, and verification honesty**. It is **not** about inventing a new browser-test strategy, broadening the milestone into external-provider realism, or relitigating the Phase 25/26 product UX decisions.

</domain>

<decisions>
## Implementation Decisions

### Proof harness ownership

- **D-2701:** Phase 27 should expose **one dedicated thin Mix task** as the canonical proof command. It should be explicit about intent, memorable for operators and contributors, and suitable for exact citation in `27-VERIFICATION.md`.
- **D-2702:** The Mix task should be a **wrapper only**. It must delegate to existing proof layers rather than re-implement shell/bootstrap/test logic inside a new task.
- **D-2703:** The canonical proof command should run **exactly two layers in order**:
  1. the existing local-topology smoke via `mix integration.first_run`
  2. the focused operator-path proof via `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`
- **D-2704:** Do **not** cite `mix shift_left.verify` / `just shift-left` as the owning Phase 27 proof command. That command is broader than the requirement and would blur what this phase actually proves.
- **D-2705:** Do **not** make `test/integration/first_run.sh` the only owning proof surface. Shell is correct for the local-machine bring-up boundary, but not for the detailed Phoenix operator journey.

### Environment realism

- **D-2706:** The milestone proof must include the **real local topology** that Kiln documents and expects operators to run: **Compose data plane + host Phoenix + `.env` contract**.
- **D-2707:** The existing `mix integration.first_run` / `test/integration/first_run.sh` path remains the **SSOT for machine-level readiness proof**. Phase 27 should reuse it rather than cloning its Docker/bootstrap logic.
- **D-2708:** Purely test-seeded readiness or LiveView-only proof is **insufficient alone** for `UAT-04`. Those layers remain necessary support coverage, but they do not honestly prove the local-first machine story by themselves.
- **D-2709:** Full browser E2E is **not** the default ownership layer for this phase. It may remain as broader acceptance coverage elsewhere, but it should not become the phase's primary proof harness.
- **D-2710:** The Phase 27 proof should stay **deterministic and local**. Do not widen it to depend on live external vendors, real provider success, or unrelated network conditions beyond the existing local stack contract.

### Journey depth

- **D-2711:** The owning proof should cover the **setup-ready operator happy path**, not just a backend seam and not the blocked detour. The intended story is:
  1. `/settings` as the readiness SSOT
  2. `/templates` with `hello-kiln` as the recommended first run
  3. `Start run`
  4. `/runs/:id` as the first proof-of-life surface
- **D-2712:** The proof should be explicitly framed as **setup-ready**. Missing-readiness redirect/recovery remains valuable supporting coverage, but it should not be the centerpiece of the phase-owned proof command.
- **D-2713:** Do **not** reduce Phase 27 to a rerun of Phase 24's `/templates` happy path alone. Phase 27 must step up one level by tying the path back to the milestone's canonical readiness surface and real local machine story.
- **D-2714:** Do **not** deepen the phase into broad dashboard, browser, or multi-branch journey coverage. One coherent first-success path is more valuable than a wide but fuzzy proof story.

### Verification strictness

- **D-2715:** The primary proof contract should remain **stable routes + stable DOM ids** at operator-visible state boundaries.
- **D-2716:** Minimal text assertions are acceptable only when they disambiguate a meaningful branch or user-facing meaning. **Copy is not the primary contract.**
- **D-2717:** Do **not** make deep domain-state assertions, screenshot/visual snapshots, or raw HTML blob matching the top-level proof contract. Those are too brittle or duplicate lower-layer tests.
- **D-2718:** Shell assertions are appropriate only for the **outer integration boundary**: command success, local service health, and boot reachability. UI meaning should still be proven in Phoenix tests.
- **D-2719:** The verification artifact must cite the **single explicit Mix task command** and then transparently list the delegated layers underneath so the claim remains precise and honest.

### DX and architecture guardrails

- **D-2720:** Favor **principle of least surprise**: one command, two delegated SSOT layers, no hidden extra suites.
- **D-2721:** Keep the proof path aligned with existing repo idioms:
  - thin Mix wrappers for memorable project commands
  - `Phoenix.LiveViewTest` for routed LiveView behavior
  - shell integration only for real local stack bring-up
- **D-2722:** The phase should improve **developer ergonomics** by making the proof command obvious without hiding what it actually does. Convenience must not come at the cost of misleading scope.

### the agent's Discretion

- Exact naming of the new proof command, as long as it is explicit and memorable.
- Whether the command is implemented as a `Mix.Task` or alias-backed `Mix.Task`, as long as it remains a thin delegator.
- Exact decomposition of any new supporting test file, if a small Phase 27-specific happy-path test is needed to make the `/settings` -> `/templates` -> `/runs/:id` story more explicit.
- Exact wording of `27-VERIFICATION.md`, as long as the proof claim stays narrow and transparent.

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set is:
  - **One dedicated Mix command** for the phase-owned proof surface
  - **Real local boot first** through `mix integration.first_run`
  - **Focused Phoenix operator journey second** through the existing LiveView proof files
  - **Stable ids/routes as the proof seam**, not screenshots or deep internals
- A strong command shape would be something explicit like **`mix kiln.first_run.prove`**.
- The verification artifact should cite that single command verbatim, then list the two delegated commands underneath for transparency.
- The intended trust story is: “Kiln boots the real local stack, then the recommended first run path still lands me on a concrete run detail page that shows the factory is operating.”

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth

- `.planning/ROADMAP.md` — Phase 27 goal and success criteria
- `.planning/REQUIREMENTS.md` — `UAT-04` wording and traceability
- `.planning/PROJECT.md` — local-first milestone framing and product trust goals
- `.planning/STATE.md` — current milestone position and next-phase intent

### Prior phase context that constrains this work

- `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md` — id-first proof seam, LiveView ownership, exact-command honesty
- `.planning/phases/25-local-live-readiness-ssot/25-CONTEXT.md` — `/settings` as readiness remediation SSOT
- `.planning/phases/26-first-live-template-run/26-CONTEXT.md` — `hello-kiln` as the first recommended run, `/runs/:id` as proof destination, blocked path as supporting behavior

### Implementation anchors

- `README.md` — canonical local-first story and current operator checklist
- `mix.exs` — existing `integration.first_run` alias pattern
- `test/integration/first_run.sh` — local-topology SSOT for Compose DB + host Phoenix + `/health`
- `script/shift_left_verify.sh` — example of thin command composition, but intentionally broader than this phase
- `test/kiln_web/live/settings_live_test.exs` — readiness SSOT surface seams
- `test/kiln_web/live/templates_live_test.exs` — recommended first-run and start-run journey seams
- `test/kiln_web/live/run_detail_live_test.exs` — run-detail proof-of-life seams
- `test/kiln/specs/template_instantiate_test.exs` — lower-layer domain contracts that Phase 27 should not duplicate deeply

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `mix.exs` already exposes `mix integration.first_run` as a thin wrapper over the shell SSOT.
- `test/integration/first_run.sh` already proves the real local machine path up to `/health`.
- `TemplatesLiveTest` already proves the first-run recommendation, blocked recovery behavior, and `/templates` -> `/runs/:id` happy path.
- `RunDetailLiveTest` already proves the proof-of-life surface near the top of `/runs/:id`.
- `SettingsLiveTest` already proves the readiness SSOT surface and return-context seams.

### Established Patterns

- The codebase already prefers exact, memorable Mix entrypoints that delegate to lower-level SSOTs instead of duplicating orchestration logic.
- LiveView tests already use stable ids, `form/2`, `render_submit/1`, `follow_redirect/3`, and `has_element?/2` as the main UI proof contract.
- Browser/E2E and broad shift-left coverage already exist as **larger** repo gates; Phase 27 should not claim them as its narrow proof slice.

### Likely Integration Points

- A new thin Mix task under `lib/mix/tasks/` for the phase-owned proof command
- Possibly one small focused LiveView test addition if the `/settings` -> `/templates` ready-path story is not explicit enough today
- A new `27-VERIFICATION.md` that cites the single proof command and transparently lists the delegated layers

</code_context>

<deferred>
## Deferred Ideas

- Making Playwright/browser E2E the owning Phase 27 proof harness
- Expanding `test/integration/first_run.sh` into a pseudo-browser or HTML-scraping UI harness
- Using `mix shift_left.verify` as the phase-owned command
- Making the blocked `/settings` recovery path the main Phase 27 proof story
- Deep domain-state or screenshot-based ownership for the top-level proof
- External-provider/live-vendor realism in the phase-owned proof command

</deferred>

---

*Phase: 27-local-first-run-proof*
*Context gathered: 2026-04-23*
