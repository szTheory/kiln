# Phase 29: Attach entry surfaces - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Make attach-to-existing a first-class first-use path on Kiln's onboarding and start surfaces without destabilizing the already-validated greenfield/template journey.

This phase is about **entry-point information architecture, framing, and honest routing**. It is **not** about repository validation, workspace hydration, dirty-worktree refusal, branch orchestration, draft PR creation, or broad trust-policy mechanics. Those stay in **Phases 30-31**.

</domain>

<decisions>
## Implementation Decisions

### Onboarding role

- **D-2901:** `/onboarding` remains a **demo-first guided wizard**, not a universal mode picker. Its main job is still to help a new operator learn Kiln safely before doing real-project work.
- **D-2902:** Attach should appear on `/onboarding` as a **secondary explicit branch** near the existing next-step CTA cluster, not by replacing the current scenario-driven template recommendation.
- **D-2903:** The scenario system remains **demo-only**. Do **not** model attach as a scenario, a scenario recommendation, or a new meaning for `?scenario=...`.

### Start-surface placement

- **D-2904:** `/templates` remains the global **Start** destination in Phase 29 and becomes the **primary attach discovery surface** because it already owns “how do I begin work in Kiln?”
- **D-2905:** Attach should be introduced on `/templates` as a **parallel start path** beside the built-in template story, not as a buried footer link and not as a replacement for the `hello-kiln` first-run hero.
- **D-2906:** `/` run board may get a **small convenience shortcut** to attach later in the phase plan if it helps skip-ahead users, but it must remain a **watch/monitoring** surface, not the primary entry point.
- **D-2907:** `/settings` stays a remediation surface, not an attach chooser.

### Choice framing

- **D-2908:** The top-level product framing for Phase 29 is:
  - **Built-in templates** = fastest way to learn or prove Kiln
  - **Attach existing repo** = real-project path for bounded work on code that already exists
- **D-2909:** Use the explicit phrase **“Attach existing repo”** in operator-facing copy. Avoid vague alternatives like “import project” or “continue from code” that blur attachment, cloning, and greenfield creation.
- **D-2910:** Attach copy should prime the Phase 30 shape honestly: one repo only, operator-owned codebase, sources like **local path / existing clone / GitHub URL**, and conservative brownfield handling ahead.
- **D-2911:** Do **not** imply that attach is already equivalent to the validated template path. Phase 29 should make attach visible and credible, but it must stay honest that the safe repo-resolution path is what Phase 30 will deliver.

### Attach handoff shape

- **D-2912:** Attach should hand off to a **dedicated attach entry surface** with its own route and its own state, not to template detail, not to the scenario system, and not to the spec editor.
- **D-2913:** That attach entry surface should stay **lightweight and Phase-29-scoped**: orient the operator, clarify supported source types, and tee up the next phase. It should not attempt deep validation, hydration, or Git mutations yet.
- **D-2914:** The attach handoff should be **route-based and explicit**, which is the idiomatic Phoenix/LiveView shape here: use a dedicated LiveView plus `navigate`/`push_navigate`, not a hidden modal or overloaded URL params on `/templates`.
- **D-2915:** Do **not** broaden the current template-specific `return_to` / `template_id` resume plumbing in Phase 29. Attach should get its own future resume model in Phase 30 rather than piggybacking on template-only assumptions.

### Default emphasis

- **D-2916:** `hello-kiln` stays the **single recommended first proof path** for operators who are new to Kiln or evaluating it quickly. That remains a locked product promise from Phase 26.
- **D-2917:** Attach should be **visibly first-class** for operators who already have a real project, but it should not outrank the `hello-kiln` hero on `/templates` and should not replace the current onboarding primary CTA.
- **D-2918:** The intended emphasis is **“template-first for learning, attach-first for real brownfield work”**. Kiln should surface both clearly without forcing the operator to decode hidden “advanced” paths.

### Architecture and DX guardrails

- **D-2919:** Preserve existing tested seams and ids for onboarding, scenario propagation, template apply/start flow, and run-detail-first proof. Attach work in Phase 29 should be **additive**.
- **D-2920:** Give attach its **own ids, route params, and navigation helpers**. Do not reuse `template_id`, template forms, or demo-scenario controls for attach behavior.
- **D-2921:** Follow principle of least surprise in LiveView: explicit routes, stable navigation, calm copy, and server-authoritative next steps. Hidden attach state, magic inference, or ambiguous branching would be a regression.
- **D-2922:** Keep missing-readiness behavior consistent with prior phases: **explorable disconnected states plus exact remediation guidance**, not hard route blocking and not disabled-CTA-only behavior.

### the agent's Discretion

- Exact route name and UI label hierarchy for the dedicated attach entry surface, as long as the operator-facing phrase remains “Attach existing repo.”
- Exact visual composition on `/templates` for the template-vs-attach start split, as long as `hello-kiln` remains the top recommendation and attach remains clearly discoverable.
- Whether `/` run board gets a minor attach shortcut in this phase, as long as the board stays a monitoring surface.

</decisions>

<specifics>
## Specific Ideas

- The coherent recommendation set is:
  - keep the **demo/template journey intact**
  - introduce attach as a **parallel real-project branch**
  - land attach on its **own route**
  - defer repo mechanics to the next phase instead of faking them here

- The strongest `/templates` information architecture is:
  - keep the existing `hello-kiln` hero
  - add a clearly labeled **Attach existing repo** peer module nearby
  - explain when to choose each path in one sentence each

- The strongest `/onboarding` information architecture is:
  - keep scenario selection and the primary “open recommended template” CTA
  - add a secondary attach CTA for operators who already know they want Kiln on an existing codebase

- Ecosystem lessons that informed these decisions:
  - **Vercel, Netlify, and GitHub** all make the distinction between **start from a template** and **connect/import existing code** explicit at the moment a project is created. That early branch reduces ambiguity and is the right model for Kiln.
  - **Netlify** and **Vercel** ask the operator to choose an existing repository first, then configure framework/root details. That supports Kiln branching early in Phase 29 and doing the real repo-resolution work in Phase 30.
  - **GitHub template repositories** produce unrelated history, which is useful for greenfield starts but the wrong mental model for attach-to-existing. Kiln should keep template and attach as clearly different jobs.
  - **Railway** distinguishes template deployment from working on your own repo and preserves branch/PR-mediated update flows. That supports keeping template and attach separate rather than pretending they are the same path with different copy.
  - Recent **v0** docs and community threads show the cost of blurring “import existing repo” with hidden runtime assumptions: repo-shape expectations, broken reconnection paths, and destructive-feeling integration state create distrust fast. Kiln should stay conservative, explicit, and branch/PR-safe rather than imply magic compatibility.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth

- `.planning/ROADMAP.md` — Phase 29 goal, milestone ordering, and attach-only boundary
- `.planning/REQUIREMENTS.md` — `ATTACH-01` milestone wording and traceability
- `.planning/PROJECT.md` — v0.6.0 goals, non-goals, and attach-related product decisions
- `.planning/STATE.md` — active milestone posture and next-step context

### Prior phase context that constrains this work

- `.planning/phases/25-local-live-readiness-ssot/25-CONTEXT.md` — `/settings` as readiness/remediation SSOT
- `.planning/phases/26-first-live-template-run/26-CONTEXT.md` — `hello-kiln` as the first recommended live path and `/templates` / `/runs/:id` journey contract
- `.planning/phases/27-local-first-run-proof/27-CONTEXT.md` — narrow, honest proof contract around the validated template-first journey

### Brownfield intent and backlog context

- `.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md` — original attach/fork/clone framing, trust-ramp intent, and scope decomposition

### Implementation anchors

- `lib/kiln_web/router.ex` — current LiveView route surface
- `lib/kiln_web/components/layouts.ex` — global navigation and “Start” IA
- `lib/kiln_web/components/operator_chrome.ex` — shared scenario/runtime chrome
- `lib/kiln/demo_scenarios.ex` — current scenario model and demo-only semantics
- `lib/kiln_web/live/onboarding_live.ex` — demo-first onboarding wizard and next-step cluster
- `lib/kiln_web/live/templates_live.ex` — primary start surface and `hello-kiln` hero
- `lib/kiln_web/live/run_board_live.ex` — operator balcony framing and empty-state shortcuts
- `lib/kiln_web/live/settings_live.ex` — current return-context and remediation plumbing

### Testing anchors

- `test/kiln_web/live/onboarding_live_test.exs`
- `test/kiln_web/live/templates_live_test.exs`
- `test/kiln_web/live/run_board_live_test.exs`
- `test/kiln_web/live/settings_live_test.exs`
- `test/kiln_web/live/operator_chrome_live_test.exs`
- `test/kiln_web/live/route_smoke_test.exs`
- `test/e2e/tests/onboarding.spec.ts`
- `test/e2e/tests/routes.spec.ts`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `/templates` already owns the “how do I start?” mental model and is the cleanest place to introduce a second first-class start path.
- `/onboarding` already has a next-step CTA cluster where attach can appear as an additive alternative without replacing the demo-first story.
- `Layouts` and operator chrome already carry stable journey context and navigation patterns that new attach UI should follow instead of inventing its own shell behavior.

### Established Patterns

- The codebase prefers **route-based LiveView flows** with stable ids and explicit navigation over hidden UI state.
- The validated first-run journey is **template -> start run -> run detail first**, with `/` as the broader balcony and `/settings` as the remediation SSOT.
- Scenario context is already a tested cross-surface concern; attach should not overload that channel because it represents demo narrative, not repo source selection.

### Integration Points

- New attach entry work should connect to:
  - global `Start` navigation
  - onboarding next-step CTA area
  - templates index information architecture
- New attach work should **not** hook into:
  - template apply/start handlers
  - template-specific resume plumbing
  - scenario selection semantics

</code_context>

<deferred>
## Deferred Ideas

- Repository validation, source resolution, and single-repo workspace hydration — Phase 30
- Dirty-worktree, detached-HEAD, and missing-prerequisite refusal mechanics — Phase 30
- Branch creation, push, and draft PR trust ramp — Phase 31
- Multi-root, monorepo-first, fork-and-continue, and clone-to-stack behaviors — deferred beyond this milestone slice
- Reusing template-specific `return_to` semantics for attach — defer until attach has its own concrete blocked/resume model

</deferred>

---

*Phase: 29-attach-entry-surfaces*
*Context gathered: 2026-04-24*
