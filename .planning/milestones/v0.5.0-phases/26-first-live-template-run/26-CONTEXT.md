# Phase 26: First live template run - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn Kiln's existing built-in template and run-entry surfaces into **one trustworthy first local live run path**. The operator should not have to guess which template to trust first, whether live prerequisites are actually satisfied, or where to look after launch to confirm the factory is really operating.

This phase is about **guidance, preflight enforcement, and believable post-launch proof**. It is not about expanding the template catalog, inventing a new run system, or broadening into the end-to-end automated proof path for the whole milestone. Phase 27 owns the explicit repeatable proof artifact.

</domain>

<decisions>
## Implementation Decisions

### Canonical first-run recommendation

- **D-2601:** `hello-kiln` is the **single recommended first local live run** for Phase 26. It should be presented as the stable default answer, not as one recommendation among several equally-weighted choices.
- **D-2602:** Scenario guidance remains useful, but it is **secondary framing**, not the primary recommendation system. Scenario copy may explain why another template matters next, but it must not replace or override `hello-kiln` as the first trusted path.
- **D-2603:** Do **not** promote `gameboy-vertical-slice` as the default first live run. It remains the deeper dogfood path after the operator has proven the basic local flow.
- **D-2604:** Do **not** let `markdown-spec-stub` read as the main live-run recommendation. It is an edit/import-first path, not the clearest first-believable-run proof.

### Templates page information architecture

- **D-2605:** `/templates` stays the canonical catalog, but the surface should be split into two layers:
  1. one explicit **recommended first live run hero** for `hello-kiln`
  2. the broader template catalog below
- **D-2606:** The recommended hero should teach the operator journey clearly: readiness -> use template -> start run -> inspect proof. It should feel like the shortest believable path, not like a marketing spotlight.
- **D-2607:** Keep the broader catalog fully visible below the hero. Other templates should remain browseable and honest, not hidden, muted into irrelevance, or framed as unsafe.
- **D-2608:** Non-recommended templates should get **honest role labels** rather than weak ranking signals. For example:
  - `gameboy-vertical-slice` = dogfood-depth / real-project next step
  - `markdown-spec-stub` = edit/import-first path
- **D-2609:** Avoid recommendation patterns that create surprise or drift:
  - no scenario-driven primary recommendation switching
  - no hidden “all templates” state
  - no wizard-like chooser that duplicates `/templates`
  - no badge-only emphasis that leaves the first-run answer ambiguous

### Start-run preflight and blocked recovery

- **D-2610:** `Start run` must perform a **real, backend-authoritative preflight**. The final gate for live readiness belongs to the backend, not to disabled-button-only UI logic.
- **D-2611:** On blocked live start, the operator should be routed directly to the **first missing `/settings#settings-item-*` anchor** using the existing readiness checklist order as the deterministic blocker priority.
- **D-2612:** `/settings` remains the only remediation SSOT. Do not create a second full blocked-state decision surface on `/templates`.
- **D-2613:** Inline disconnected/live-readiness messaging on `/templates` can remain as **non-authoritative guidance**, but it must not be the final enforcement mechanism.
- **D-2614:** The blocked-start recovery flow should preserve **return context** for the chosen template so the operator can fix the issue and come back to the same first-run path without re-orienting.
- **D-2615:** Do **not** rely on a disabled CTA as the only unreadiness behavior. That fails the requirement that starting a live run performs a preflight and routes recovery.

### Template apply and run-entry choreography

- **D-2616:** Preserve the locked Phase 17 flow: `Use template` and `Start run` remain **separate but adjacent**. Kiln should not collapse them into one opaque “do everything” action for Phase 26.
- **D-2617:** `Use template` should remain a calm, explicit materialization step. `Start run` is the execution-intent step and is where live readiness preflight belongs.
- **D-2618:** Avoid adding a transitional “launch success” surface on the template page. Strengthen the existing route seams instead of inventing a third place where run truth lives.

### Post-launch proof of life

- **D-2619:** After a successful live start, navigate **directly to `/runs/:id`**. This is the strongest proof that a specific run exists and is operating.
- **D-2620:** The run board (`/`) remains the default balcony for general monitoring, but it is **secondary** to run detail for first-run trust building.
- **D-2621:** Phase 26 should strengthen the top of run detail into a **proof-first overview** that answers, immediately:
  - did the run actually start?
  - what state is it in right now?
  - what stage is active or next?
  - what should the operator look at next?
- **D-2622:** Sufficient believable proof is:
  - run created
  - current lifecycle state
  - active stage or next-action indicator
  - recent transition timing
  - a small live event/log excerpt
  - a clear pointer to the run board as the broader watch surface
- **D-2623:** Avoid noisy or performative proof patterns:
  - fake progress percentages
  - decorative transitional success panels
  - duplicate “live” surfaces competing for truth
  - telemetry overload that obscures the basic answer “Kiln is operating”

### UX and architecture guardrails

- **D-2624:** Favor **principle of least surprise** over dynamic cleverness. Phase 26 should make the first live run path more obvious, not more adaptive.
- **D-2625:** Prefer strengthening existing LiveView routes, stable ids, and shared readiness contracts over introducing new route families, hidden UI state, or duplicated guidance logic.
- **D-2626:** The phase should keep operator language calm and instructive: one clear starter, one real preflight, one specific remediation destination, one specific proof destination.

### the agent's Discretion

- Exact visual treatment of the `hello-kiln` hero, as long as it is clearly primary without making the rest of the catalog look deprecated.
- Exact wording for the blocked-start flash and return-context affordance, as long as the flow routes to the first missing `/settings` anchor and back cleanly.
- Exact composition of the proof-first run-detail overview, as long as it prioritizes clear run truth over decorative telemetry.

</decisions>

<specifics>
## Specific Ideas

- The coherent first-run story is:
  - **Start with `hello-kiln`**
  - **Use template**
  - **Attempt `Start run`**
  - If blocked, **route to the exact missing `/settings` item**
  - If ready, **land on `/runs/:id`** and show proof that the factory is operating
- Cross-ecosystem precedent supports this shape:
  - starter-first onboarding from Phoenix/Fly-style quick starts
  - explicit template materialization from GitHub-style template flows
  - run/build-specific proof from GitHub Actions / Buildkite / Prefect-style operator surfaces
  - requirements-driven remediation over custom drift-prone UI gating from Stripe/Vercel-style readiness flows
- The main footguns to avoid are:
  - making the primary recommendation change by scenario
  - keeping `Start run` disabled so the real preflight path never happens
  - adding a third “launch success” surface on `/templates`
  - hiding non-recommended templates behind filters or low-contrast de-emphasis

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and requirement truth

- `.planning/ROADMAP.md` — Phase 26 goal and success criteria
- `.planning/REQUIREMENTS.md` — `LIVE-01`, `LIVE-02`, `LIVE-03`
- `.planning/PROJECT.md` — local-first milestone framing, bounded-autonomy goals, operator UX constraints

### Prior phase context that constrains this work

- `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md` — `/templates` canonical catalog, separate `Use template` and `Start run`, template semantics
- `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md` — existing `/templates` -> `/runs/:id` proof seam and selector contract
- `.planning/phases/25-local-live-readiness-ssot/25-CONTEXT.md` — `/settings` as readiness remediation SSOT and readiness-aware surface cohesion

### Implementation anchors

- `lib/kiln_web/live/templates_live.ex` — current templates UX, recommendation banner, apply/start flow
- `lib/kiln/demo_scenarios.ex` — current scenario framing and recommended-template metadata
- `priv/templates/manifest.json` — current built-in templates, hints, and likely first-run candidate
- `lib/kiln/operator_setup.ex` — readiness summary, blocker order, and `/settings#settings-item-*` anchors
- `lib/kiln/runs/run_director.ex` — backend readiness truth for live start
- `lib/kiln_web/live/settings_live.ex` — canonical remediation surface
- `lib/kiln_web/live/run_detail_live.ex` — proof destination to strengthen
- `lib/kiln_web/live/run_board_live.ex` — default watch surface that should remain secondary after launch

### Testing anchors

- `test/kiln_web/live/templates_live_test.exs`
- `test/kiln_web/live/run_detail_live_test.exs`
- `test/kiln_web/live/settings_live_test.exs`
- `test/kiln/runs/run_director_readiness_test.exs`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- `TemplatesLive` already has the main route seams, stable ids, scenario banner, apply/start controls, and live-disconnected messaging.
- `OperatorSetup.summary/0` already exposes an ordered readiness checklist with stable `/settings` anchors that can power deterministic remediation routing.
- `RunDirector.start_run/1` already enforces backend readiness truth via `{:error, :factory_not_ready}`.
- `RunDetailLive` already exists as the natural post-launch proof surface and is already used in the Phase 24 regression seam.

### Established patterns

- The codebase already prefers explicit LiveView ids and route-based proof over text-heavy assertions.
- Prior phases already locked `/templates` as catalog SSOT, `/settings` as readiness remediation SSOT, and `/` as the default balcony.
- LiveView navigation and shared readiness copy are already present; Phase 26 should extend those patterns rather than branching into a new flow family.

### Likely integration points

- `TemplatesLive` will likely need:
  - a dedicated recommended-template hero for `hello-kiln`
  - revised catalog framing for secondary templates
  - backend-driven blocked-start routing behavior
- `SettingsLive` may need return-context handling or minor copy/anchor reinforcement for first-run recovery.
- `RunDetailLive` will likely need a stronger proof-first overview near the top of the page.

</code_context>

<deferred>
## Deferred Ideas

- Broader template ranking/filter systems or scenario-driven catalog state — out of scope for this phase
- One-click “use template and start run” choreography — unnecessary for Phase 26 and easy to make opaque
- The repository-level explicit automated proof artifact for the whole local-first journey — Phase 27

</deferred>

---

*Phase: 26-first-live-template-run*
*Context gathered: 2026-04-23*
