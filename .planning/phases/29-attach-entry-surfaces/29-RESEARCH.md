# Phase 29: Attach entry surfaces - Research

**Researched:** 2026-04-24
**Domain:** Phoenix LiveView entry-surface information architecture and route design for attach-to-existing
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- `/onboarding` remains a **demo-first guided wizard**, not a universal mode picker. Its main job is still to help a new operator learn Kiln safely before doing real-project work. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Attach should appear on `/onboarding` as a **secondary explicit branch** near the existing next-step CTA cluster, not by replacing the current scenario-driven template recommendation. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- The scenario system remains **demo-only**. Do **not** model attach as a scenario, a scenario recommendation, or a new meaning for `?scenario=...`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- `/templates` remains the global **Start** destination in Phase 29 and becomes the **primary attach discovery surface** because it already owns “how do I begin work in Kiln?” [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Attach should be introduced on `/templates` as a **parallel start path** beside the built-in template story, not as a buried footer link and not as a replacement for the `hello-kiln` first-run hero. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- `/` run board may get a **small convenience shortcut** to attach later in the phase plan if it helps skip-ahead users, but it must remain a **watch/monitoring** surface, not the primary entry point. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- `/settings` stays a remediation surface, not an attach chooser. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- The top-level product framing for Phase 29 is:
  - **Built-in templates** = fastest way to learn or prove Kiln
  - **Attach existing repo** = real-project path for bounded work on code that already exists [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Use the explicit phrase **“Attach existing repo”** in operator-facing copy. Avoid vague alternatives like “import project” or “continue from code” that blur attachment, cloning, and greenfield creation. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Attach copy should prime the Phase 30 shape honestly: one repo only, operator-owned codebase, sources like **local path / existing clone / GitHub URL**, and conservative brownfield handling ahead. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Do **not** imply that attach is already equivalent to the validated template path. Phase 29 should make attach visible and credible, but it must stay honest that the safe repo-resolution path is what Phase 30 will deliver. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Attach should hand off to a **dedicated attach entry surface** with its own route and its own state, not to template detail, not to the scenario system, and not to the spec editor. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- That attach entry surface should stay **lightweight and Phase-29-scoped**: orient the operator, clarify supported source types, and tee up the next phase. It should not attempt deep validation, hydration, or Git mutations yet. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- The attach handoff should be **route-based and explicit**, which is the idiomatic Phoenix/LiveView shape here: use a dedicated LiveView plus `navigate`/`push_navigate`, not a hidden modal or overloaded URL params on `/templates`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html]
- Do **not** broaden the current template-specific `return_to` / `template_id` resume plumbing in Phase 29. Attach should get its own future resume model in Phase 30 rather than piggybacking on template-only assumptions. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- `hello-kiln` stays the **single recommended first proof path** for operators who are new to Kiln or evaluating it quickly. That remains a locked product promise from Phase 26. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md]
- Attach should be **visibly first-class** for operators who already have a real project, but it should not outrank the `hello-kiln` hero on `/templates` and should not replace the current onboarding primary CTA. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- The intended emphasis is **“template-first for learning, attach-first for real brownfield work”**. Kiln should surface both clearly without forcing the operator to decode hidden “advanced” paths. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Preserve existing tested seams and ids for onboarding, scenario propagation, template apply/start flow, and run-detail-first proof. Attach work in Phase 29 should be **additive**. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: codebase grep]
- Give attach its **own ids, route params, and navigation helpers**. Do not reuse `template_id`, template forms, or demo-scenario controls for attach behavior. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Follow principle of least surprise in LiveView: explicit routes, stable navigation, calm copy, and server-authoritative next steps. Hidden attach state, magic inference, or ambiguous branching would be a regression. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html]
- Keep missing-readiness behavior consistent with prior phases: **explorable disconnected states plus exact remediation guidance**, not hard route blocking and not disabled-CTA-only behavior. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/run_board_live.ex]

### Claude's Discretion

- Exact route name and UI label hierarchy for the dedicated attach entry surface, as long as the operator-facing phrase remains “Attach existing repo.” [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Exact visual composition on `/templates` for the template-vs-attach start split, as long as `hello-kiln` remains the top recommendation and attach remains clearly discoverable. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Whether `/` run board gets a minor attach shortcut in this phase, as long as the board stays a monitoring surface. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

- Repository validation, source resolution, and single-repo workspace hydration — Phase 30 [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Dirty-worktree, detached-HEAD, and missing-prerequisite refusal mechanics — Phase 30 [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Branch creation, push, and draft PR trust ramp — Phase 31 [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Multi-root, monorepo-first, fork-and-continue, and clone-to-stack behaviors — deferred beyond this milestone slice [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: .planning/seeds/SEED-009-attach-fork-clone-existing-projects.md]
- Reusing template-specific `return_to` semantics for attach — defer until attach has its own concrete blocked/resume model [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ATTACH-01 | Operator can choose an attach-to-existing path from onboarding and template/start surfaces, with clear framing for when to use attach versus built-in greenfield templates. [VERIFIED: .planning/REQUIREMENTS.md] | Add an explicit `/attach` route, additive attach CTAs on `/onboarding` and `/templates`, and optional minor `/` shortcut while preserving the validated template-first learning path. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 29 should add one new routable surface, `GET /attach`, and treat attach as an additive navigation branch rather than a new workflow engine. The existing codebase already separates concerns cleanly: `/onboarding` is demo-first and uses `chrome_mode={:minimal}`, `/templates` is the current start surface, `/` is the run-monitoring balcony, and `/settings` is the remediation SSOT. That existing split is the seam to preserve. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/run_board_live.ex] [VERIFIED: lib/kiln_web/live/settings_live.ex]

Phoenix LiveView’s current navigation guidance favors route-based flow changes using `<.link navigate={...}>` and `push_navigate/2` for LiveView-to-LiveView transitions, while `push_patch/2` is for staying within the same LiveView. That matches the Phase 29 decision to make attach its own LiveView instead of a modal or a query-param overload on `/templates`. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]

The main implementation risk is not technical complexity; it is accidental product dishonesty. The validated template journey already promises `hello-kiln` as the first proof path and already has stable tests around onboarding, templates, settings redirects, run-detail handoff, route smoke, and E2E routing. Phase 29 should therefore be additive: new route, new ids, new copy, no reuse of template submission handlers, no attach state in the scenario system, and no hint that repo validation or branch/PR mechanics already exist. [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md] [VERIFIED: test/kiln_web/live/onboarding_live_test.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/route_smoke_test.exs] [VERIFIED: test/e2e/tests/onboarding.spec.ts] [VERIFIED: test/e2e/tests/routes.spec.ts]

**Primary recommendation:** Add `KilnWeb.AttachLive` at `/attach`, surface it as a secondary CTA on `/onboarding`, a peer start module on `/templates`, and optionally one minor link on `/`, while leaving template apply/start mechanics untouched. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Attach entry routing (`/attach`) | Frontend Server (SSR/LiveView) | — | Phoenix router and LiveView own route registration and mount/render for all current entry surfaces. [VERIFIED: lib/kiln_web/router.ex] |
| Onboarding attach branch CTA | Frontend Server (SSR/LiveView) | — | `/onboarding` already renders route-driven CTAs and scenario state on the server. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] |
| Templates attach discovery module | Frontend Server (SSR/LiveView) | — | `/templates` already owns start-surface IA and hero/catalog composition. [VERIFIED: lib/kiln_web/live/templates_live.ex] |
| Optional run-board attach shortcut | Frontend Server (SSR/LiveView) | — | `/` is a LiveView-rendered navigation surface today; no API tier is involved in adding one more link. [VERIFIED: lib/kiln_web/live/run_board_live.ex] |
| Attach orientation copy and supported-source framing | Frontend Server (SSR/LiveView) | — | Phase 29 is framing-only; no backend validation or hydration logic should run yet. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] |
| Future repo resolution and workspace hydration | API / Backend | Database / Storage | Phase 29 explicitly defers these mechanics to Phase 30. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] |

## Project Constraints (from CLAUDE.md)

- Kiln is a single Phoenix app with Phoenix 1.8.5 and LiveView 1.1.28; recommendations should stay inside existing Phoenix LiveView idioms and not introduce a parallel frontend stack. [VERIFIED: CLAUDE.md] [VERIFIED: mix.lock]
- Postgres remains the system of record and run state stays server-authoritative; Phase 29 should not invent client-side attach state that tries to pre-own Phase 30 workspace logic. [VERIFIED: CLAUDE.md]
- Secrets are references, not values; attach entry copy and UI must not prompt for or render secret material. [VERIFIED: CLAUDE.md]
- Bounded autonomy is a core product rule; Phase 29 should frame the trust ramp honestly and defer branch/PR mechanics to the milestone phases that own them. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/ROADMAP.md]
- The brand contract requires calm, concrete microcopy and operator clarity over hype; that aligns with explicit “Attach existing repo” wording and explicit future-step notes. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- The repo workflow expects documentation work to stay inside GSD artifacts and final verification to use project gates like `bash script/precommit.sh` or `just precommit` when implementation lands. [VERIFIED: CLAUDE.md] [VERIFIED: AGENTS.md instructions]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | 1.8.5 [VERIFIED: mix.lock] | Router and LiveView route registration | All existing entry surfaces are Phoenix LiveViews under one `live_session :default`; Phase 29 fits that pattern without new dependencies. [VERIFIED: lib/kiln_web/router.ex] |
| Phoenix LiveView | 1.1.28 [VERIFIED: mix.lock] | Server-rendered route transitions and stateful UI | Current code already uses `push_navigate/2`, `push_patch/2`, `<.link navigate={...}>`, and `handle_params/3`, which is the right mechanism for an explicit attach route. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex] [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] |
| Phoenix Component / Verified Routes | bundled with current Phoenix + LiveView [VERIFIED: mix.lock] | Stable link generation and form helpers | Existing code consistently uses `~p` routes and component links; attach should follow the same path helper pattern. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.LiveViewTest | 1.1.28 docs for current project LV version [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Route-mounted LiveView regression tests | Use for `/attach` mount, CTA presence, and cross-surface navigation assertions. [VERIFIED: test/kiln_web/live/onboarding_live_test.exs] |
| Playwright | 1.59.1 CLI available locally [VERIFIED: npx playwright --version] | Route-matrix and first-use browser coverage | Use only to extend the existing route and onboarding E2E specs; do not make Playwright the owning Phase 29 proof seam. [VERIFIED: test/e2e/tests/onboarding.spec.ts] [VERIFIED: test/e2e/tests/routes.spec.ts] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated `/attach` LiveView | Query-param branch inside `/templates` | Reuses one route, but it overloads template semantics and weakens the honest handoff boundary Phase 29 explicitly wants. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] |
| Route-based attach entry | Modal or JS-only launcher | Faster to sketch, but inconsistent with current server-authoritative LiveView navigation and harder to cover with the existing route smoke tests. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] |
| New attach-specific scenario | Existing `?scenario=` system | Would blur demo narrative with brownfield repo selection, which Phase 29 forbids. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: lib/kiln/demo_scenarios.ex] |

**Installation:**

```bash
# None. Phase 29 should use the existing Phoenix/LiveView stack.
```

**Version verification:** Phoenix `1.8.5` and Phoenix LiveView `1.1.28` are pinned in `mix.lock`; no new package is required for this phase. [VERIFIED: mix.lock]

## Architecture Patterns

### System Architecture Diagram

```text
Operator click
  -> /onboarding CTA or /templates attach module or optional / shortcut [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
  -> Phoenix router live_session :default [VERIFIED: lib/kiln_web/router.ex]
  -> KilnWeb.AttachLive mount/render
  -> Attach orientation panels
     - supported sources
     - one-repo scope
     - honest "validation happens next" note
     - back-links to /templates and /onboarding
  -> Phase 30 handoff boundary
     - no repo validation yet
     - no workspace hydration yet
     - no dirty-worktree refusal yet
     - no branch/PR orchestration yet
```

### Recommended Project Structure

```text
lib/
├── kiln_web/router.ex                     # add GET /attach inside existing live_session
├── kiln_web/live/attach_live.ex           # new dedicated attach orientation LiveView
├── kiln_web/live/onboarding_live.ex       # additive secondary attach CTA only
├── kiln_web/live/templates_live.ex        # add peer attach module on index view
└── kiln_web/live/run_board_live.ex        # optional minor attach shortcut only

test/
├── kiln_web/live/attach_live_test.exs     # new route + shell + CTA assertions
├── kiln_web/live/onboarding_live_test.exs # additive CTA assertions
├── kiln_web/live/templates_live_test.exs  # attach module assertions
├── kiln_web/live/run_board_live_test.exs  # optional shortcut assertions
├── kiln_web/live/route_smoke_test.exs     # include /attach in route matrix
└── e2e/tests/routes.spec.ts               # include /attach in browser route matrix
```

### Pattern 1: Route-Based Branching From Start Surfaces

**What:** Use existing LiveView entry pages to branch into attach with `<.link navigate={~p"/attach"}>` or `push_navigate/2`, not local component state. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html]

**When to use:** Any cross-surface transition that mounts a distinct LiveView with its own page title, ids, and honest boundary. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]

**Example:**

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/live-navigation.html
<.link navigate={~p"/attach"} id="templates-attach-existing-repo" class="btn btn-primary">
  Attach existing repo
</.link>
```

### Pattern 2: Keep Demo Scenario State Separate From Attach State

**What:** Preserve `?scenario=` only for demo narrative and introduce no attach state in that channel. [VERIFIED: lib/kiln/demo_scenarios.ex] [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex]

**When to use:** Any CTA or helper that targets attach from onboarding/templates/run board. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]

**Example:**

```elixir
# Source: current Kiln route helpers in layouts/run_board/templates
defp templates_path(nil), do: ~p"/templates"
defp templates_path(scenario), do: ~p"/templates?scenario=#{scenario.id}"

# Phase 29 recommendation:
# add a separate helper for attach instead of overloading `scenario`
defp attach_path, do: ~p"/attach"
```

### Pattern 3: Additive Entry-Surface Change, Not Flow Rewiring

**What:** Add new ids and modules around existing heroes and CTA clusters while leaving template submit/start handlers alone. [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/onboarding_live.ex]

**When to use:** Whenever Phase 29 work touches pages that already own milestone-proof seams. [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]

**Example:**

```elixir
# Source: current Kiln style in onboarding/templates
<.link id="onboarding-attach-existing-repo" navigate={~p"/attach"} class="btn border border-base-300 bg-base-100">
  Attach existing repo
</.link>
<p id="onboarding-attach-path-note" class="kiln-meta">
  Real-project path for bounded work on one codebase you already own.
</p>
```

### Anti-Patterns to Avoid

- **Attach as scenario:** breaks the current meaning of `DemoScenarios` and would leak brownfield state into demo guidance. [VERIFIED: lib/kiln/demo_scenarios.ex] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- **Attach as template detail variant:** would couple attach to `template_id`, `use_template`, and `start_run` handlers that are greenfield-specific today. [VERIFIED: lib/kiln_web/live/templates_live.ex]
- **Attach modal on `/templates`:** hides the new route from route smoke and makes honest back/forward navigation harder than the current LiveView pattern. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html]
- **Phase 30 logic in Phase 29 UI:** validation, hydration, dirty-worktree checks, branch orchestration, and draft PR creation are milestone-following phases, not entry-surface work. [VERIFIED: .planning/ROADMAP.md]

## Existing Codebase Constraints and Seams

- The router currently exposes `/onboarding`, `/`, `/templates`, and `/settings` in one `live_session :default`; `/attach` should be added there to inherit the same mounted hooks and shell behavior. [VERIFIED: lib/kiln_web/router.ex]
- `Layouts.app/1` already owns the global `Start` nav item through `templates_path/1`; Phase 29 should keep that nav target pointed at `/templates` instead of moving “Start” directly to `/attach`. [VERIFIED: lib/kiln_web/components/layouts.ex]
- Onboarding already uses `chrome_mode={:minimal}` and already has a next-step card plus CTA cluster; that is the right insertion point for a secondary attach CTA. [VERIFIED: lib/kiln_web/live/onboarding_live.ex]
- Templates already owns the first-run hero and catalog split, with `hello-kiln` as the recommended first path; the attach module should live beside that hero rather than replace it. [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md]
- The run board explicitly frames itself as the watch balcony and currently points users to setup and templates; any attach link there should stay subordinate to that framing. [VERIFIED: lib/kiln_web/live/run_board_live.ex]
- Settings has template-only `return_to` plumbing constrained to `/templates/...`; Phase 29 should not generalize that mechanism for attach yet. [VERIFIED: lib/kiln_web/live/settings_live.ex]

## Recommended Route / Surface Structure

### Routes

- Add `live "/attach", AttachLive, :index` inside the existing `live_session :default`. [VERIFIED: lib/kiln_web/router.ex]
- Keep `/templates` as the `Start` nav destination and the primary attach discovery surface. [VERIFIED: lib/kiln_web/components/layouts.ex] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Do not add attach query params to `/templates` or `/onboarding`; attach should have its own route and state. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]

### Surface Roles

- **`/onboarding`**: keep demo-first; add one bordered secondary CTA and one short note near the recommended-template cluster. Required ids are already specified by the UI contract: `onboarding-attach-existing-repo` and `onboarding-attach-path-note`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- **`/templates`**: add a peer start-choice module above the template catalog and adjacent to or immediately below the first-run hero. It should include the attach use case, supported sources, a scope note, and a CTA to `/attach`. Required ids: `templates-start-choice`, `templates-attach-module`, and `templates-attach-existing-repo`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- **`/attach`**: make this a dedicated orientation page with intro, supported sources, what attach means, what happens next, and links back to `/templates` and `/onboarding`. Required ids: `attach-entry-root`, `attach-entry-hero`, `attach-supported-sources`, `attach-next-step`, and `attach-back-to-templates`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- **`/`**: only add `run-board-attach-shortcut` if it can remain a minor link in the journey card or empty state. Do not turn the run board into a brownfield chooser. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md] [VERIFIED: lib/kiln_web/live/run_board_live.ex]

### Attach Page Recommendation

- Use the full operator chrome, not onboarding’s minimal chrome, so `/attach` behaves like a normal start surface alongside `/templates`. This matches the current split where `/templates` is a full-shell start page and `/onboarding` is the exceptional guided wizard. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex]
- Keep the page informational in Phase 29. If a placeholder form is included, it should be explicitly presentational only and should not submit or imply real validation. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- Reuse Kiln’s calm readiness language pattern: explain what attach is for, what is not done yet, and what Phase 30 will do next. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]

## Suggested Plan Decomposition

### `29-01-PLAN.md` — add attach-vs-template branching to onboarding and start surfaces

- Add `/attach` to the router and implement `KilnWeb.AttachEntryLive` with the required route-owned ids and orientation-only content. [VERIFIED: lib/kiln_web/router.ex] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- Add the secondary attach CTA and note to `/onboarding` without changing scenario selection or the primary template CTA. [VERIFIED: lib/kiln_web/live/onboarding_live.ex]
- Add the attach peer module and start-choice framing to `/templates` index without changing template detail or template submission handlers. [VERIFIED: lib/kiln_web/live/templates_live.ex]

### `29-02-PLAN.md` — align operator copy and flow guidance around greenfield vs attach entry points

- Update surface copy so the distinction is consistent across onboarding, templates, and attach: templates are the fastest proof path; attach is the real-project path. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
- Update shared helper text and microcopy only where it touches first-use orientation; do not reframe `/settings` as an attach chooser. [VERIFIED: lib/kiln_web/live/settings_live.ex] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
- Reconcile any route-smoke or E2E route-count assumptions after `/attach` becomes the new sixteenth LiveView route in `live_session :default`. The current `routes.spec.ts` comment says 15 routes. [VERIFIED: test/e2e/tests/routes.spec.ts] [VERIFIED: mix phx.routes]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-surface attach launcher | Custom JS modal state machine | Dedicated LiveView route plus `<.link navigate={...}>` / `push_navigate/2` | Current app is already route-first; modal state would be harder to reason about and test. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] [VERIFIED: codebase grep] |
| Attach source encoding | Ad-hoc reuse of `scenario` or `template_id` params | Separate `/attach` state and future attach-specific params | Current params already mean something specific and are tested that way. [VERIFIED: lib/kiln/demo_scenarios.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex] |
| Attach resume plumbing | Broadening `return_to` now | Defer to Phase 30 attach-specific blocked/resume model | Current settings return logic is intentionally template-scoped. [VERIFIED: lib/kiln_web/live/settings_live.ex] |

**Key insight:** Phase 29 is a navigation and trust-shaping phase, not a backend attach phase. The cheapest wrong move is to simulate Phase 30 behavior in UI copy or handlers. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Overloading the Scenario System

**What goes wrong:** Attach becomes another “scenario,” which mixes demo narrative with brownfield repo intent. [VERIFIED: lib/kiln/demo_scenarios.ex]
**Why it happens:** Onboarding already has a scenario picker, so it is tempting to thread attach through that existing param and control flow. [VERIFIED: lib/kiln_web/live/onboarding_live.ex]
**How to avoid:** Keep attach out of `DemoScenarios` entirely and route directly to `/attach`. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
**Warning signs:** New `scenario` values like `attach-existing-repo`, conditional attach copy in scenario detail panels, or attach CTAs that preserve `?scenario=` as semantic state. [VERIFIED: codebase grep]

### Pitfall 2: Smuggling Phase 30 Mechanics Into Phase 29

**What goes wrong:** The attach page starts validating repo paths, reading git state, or implying workspace readiness. [VERIFIED: .planning/ROADMAP.md]
**Why it happens:** A blank page feels incomplete, so implementation pressure pulls future logic forward. [ASSUMED]
**How to avoid:** Keep `/attach` informational and explicitly say validation and workspace checks happen next. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
**Warning signs:** Event handlers for attach forms, filesystem probes in `mount/3`, or copy that says the repo is “connected” or “ready.” [VERIFIED: codebase grep]

### Pitfall 3: Regressing the Validated Template Journey

**What goes wrong:** The `hello-kiln` hero loses emphasis, template tests break, or first-run proof language becomes ambiguous. [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md]
**Why it happens:** The phase adds a new first-class branch to the same pages that already carry the learning path. [VERIFIED: lib/kiln_web/live/templates_live.ex]
**How to avoid:** Make attach visually first-class but still smaller than the `hello-kiln` hero and leave template handlers untouched. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]
**Warning signs:** changed ids for existing template controls, renamed hero sections, or template CTA priority reversal on `/onboarding` and `/templates`. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official and local sources:

### Cross-LiveView Navigation

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/live-navigation.html
<.link navigate={~p"/attach"}>Attach existing repo</.link>

def handle_event("open_attach", _, socket) do
  {:noreply, push_navigate(socket, to: ~p"/attach")}
end
```

### Route-Mounted LiveView Tests

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
{:ok, view, _html} = live(conn, ~p"/attach")
assert has_element?(view, "#attach-entry-root")
assert has_element?(view, "#attach-back-to-templates[href=\"/templates\"]")
```

### Existing Kiln Pattern: Stable CTA IDs

```elixir
# Source: lib/kiln_web/live/onboarding_live.ex
<.link
  id="onboarding-start-from-template"
  navigate={~p"/templates?from=onboarding&scenario=#{@operator_demo_scenario.id}"}
  class="btn btn-primary"
>
  Open recommended template
</.link>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Greenfield-only first-use framing | Explicit split between learning path and attach path at entry surfaces | Phase 29 target | Makes brownfield usefulness visible without pretending brownfield mechanics already ship. [VERIFIED: .planning/ROADMAP.md] |
| Overloaded single-route start surface | Dedicated LiveView route for attach handoff | Phase 29 target | Cleaner browser navigation, easier route smoke coverage, and clearer Phase 30 handoff. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] |

**Deprecated/outdated:**

- Hidden or implied attach workflow behind greenfield-only onboarding language is no longer compatible with v0.6.0 milestone goals. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Adding any non-trivial attach form behavior in Phase 29 would be scope creep rather than necessary entry-surface work. [ASSUMED] | Common Pitfalls | Medium — planner may under-scope a harmless placeholder interaction if product intent actually wants one. |

## Open Questions (RESOLVED)

1. **`/attach` should use full chrome.**
   - Decision: Use the standard `Layouts.app` shell without `chrome_mode={:minimal}` so `/attach` behaves like a normal start surface alongside `/templates`, not like the special-case guided onboarding wizard. [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/templates_live.ex]
   - Why: `/templates` remains the global Start destination and `/attach` is the route-backed real-project branch off that surface. Full chrome keeps navigation, operator context, and back-navigation posture consistent with the rest of the start experience. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md]

2. **The optional `/` attach shortcut should not ship in Phase 29.**
   - Decision: Keep the run board out of the Phase 29 plan split and center scope on `/onboarding`, `/templates`, and `/attach` only. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]
   - Why: The milestone requirement for Phase 29 is explicit attach choice from onboarding and template/start surfaces, while the run board is only an allowed convenience. Cutting that optional work keeps the boundary cleaner and prevents `/` from drifting away from its monitoring-first role. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/kiln_web/live/run_board_live.ex]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Phoenix tests and route introspection | ✓ | 1.19.5 [VERIFIED: environment probe] | — |
| Erlang/OTP | Phoenix runtime | ✓ | 28 [VERIFIED: environment probe] | — |
| Mix | Phoenix commands and test runs | ✓ | present [VERIFIED: environment probe] | — |
| Node.js | Existing Playwright/browser tests | ✓ | 22.14.0 [VERIFIED: environment probe] | Skip browser layer and rely on LiveView tests if needed |
| npm / npx | Existing Playwright/browser tests | ✓ | npm 11.1.0, Playwright CLI 1.59.1 [VERIFIED: environment probe] | Skip browser layer and rely on LiveView tests if needed |
| Docker | Repo-level planning gates and shift-left smoke | ✓ | 29.3.1 [VERIFIED: environment probe] | `SHIFT_LEFT_SKIP_INTEGRATION=1` for planning-only gates per repo instructions |
| jq | Repo-level shift-left integration script | ✓ | 1.7.1 [VERIFIED: environment probe] | — |
| curl | Repo-level integration smoke | ✓ | 8.7.1 [VERIFIED: environment probe] | — |
| lsof | Repo-level integration smoke | ✓ | present [VERIFIED: environment probe] | — |

**Missing dependencies with no fallback:**

- None. [VERIFIED: environment probe]

**Missing dependencies with fallback:**

- None for Phase 29 research. Browser-layer verification can fall back to LiveView tests if Playwright is temporarily unavailable during implementation. [VERIFIED: environment probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest + LazyHTML, with existing Playwright browser coverage on the side. [VERIFIED: mix.exs] [VERIFIED: test/e2e/tests/routes.spec.ts] |
| Config file | `mix.exs`, `.check.exs`, and Playwright project files already in repo. [VERIFIED: mix.exs] |
| Quick run command | `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/route_smoke_test.exs` |
| Full suite command | `bash script/precommit.sh` [VERIFIED: AGENTS.md instructions] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ATTACH-01 | `/onboarding` exposes additive attach CTA without breaking scenario/template CTA | LiveView | `mix test test/kiln_web/live/onboarding_live_test.exs -x` | ✅ |
| ATTACH-01 | `/templates` shows template-vs-attach start framing while preserving `hello-kiln` hero | LiveView | `mix test test/kiln_web/live/templates_live_test.exs -x` | ✅ |
| ATTACH-01 | `/attach` mounts with required ids, honest scope copy, and back-links | LiveView | `mix test test/kiln_web/live/attach_entry_live_test.exs -x` | ❌ Wave 0 |
| ATTACH-01 | Router/browser matrix includes `/attach` and no route renders regress | LiveView + browser smoke | `mix test test/kiln_web/live/route_smoke_test.exs -x` and `npx playwright test test/e2e/tests/routes.spec.ts` | route smoke ✅, browser file ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/route_smoke_test.exs`
- **Per wave merge:** `npx playwright test test/e2e/tests/onboarding.spec.ts test/e2e/tests/routes.spec.ts`
- **Phase gate:** `bash script/precommit.sh`

### Wave 0 Gaps

- [ ] `test/kiln_web/live/attach_entry_live_test.exs` — new `/attach` route and ids are not covered yet. [VERIFIED: file existence probe]
- [ ] `test/kiln_web/live/onboarding_live_test.exs` — add assertions for `onboarding-attach-existing-repo` and `onboarding-attach-path-note`. [VERIFIED: current file contents]
- [ ] `test/kiln_web/live/templates_live_test.exs` — add assertions for `templates-start-choice`, `templates-attach-module`, and `/attach` CTA. [VERIFIED: current file contents]
- [ ] `test/kiln_web/live/route_smoke_test.exs` — add `/attach` to the index-route matrix. [VERIFIED: current file contents]
- [ ] `test/e2e/tests/routes.spec.ts` — update route count comment and add `/attach` to the matrix. [VERIFIED: current file contents]
- [ ] `test/e2e/tests/onboarding.spec.ts` — add one assertion that the new onboarding attach CTA routes correctly if Phase 29 wants browser coverage for that branch. [VERIFIED: current file contents]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Not applicable; Kiln has no login flow on these routes. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no | Not applicable for this phase scope. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] |
| V4 Access Control | no | Not applicable; Phase 29 adds public operator entry surfaces only. [VERIFIED: lib/kiln_web/router.ex] |
| V5 Input Validation | yes | Keep attach state route-based and server-rendered; do not accept repo source input or attach mutations in Phase 29. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] |
| V6 Cryptography | no | No cryptographic operation is added in this phase. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] |

### Known Threat Patterns for Phoenix LiveView Entry Surfaces

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Misleading operator action boundary | Spoofing | Use explicit route and copy that says validation and safety checks happen later; do not imply repo attach already succeeded. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md] |
| Param overloading between template and attach flows | Tampering | Keep attach off `scenario`, `template_id`, and `return_to` semantics. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: lib/kiln_web/live/settings_live.ex] |
| Hidden client-only state for attach entry | Repudiation | Prefer server-authoritative LiveView route transitions with stable ids and test coverage. [CITED: https://hexdocs.pm/phoenix_live_view/live-navigation.html] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |

## Sources

### Primary (HIGH confidence)

- `lib/kiln_web/router.ex` - current routable LiveView surface and `live_session :default` membership.
- `lib/kiln_web/components/layouts.ex` - global `Start` navigation and helper path semantics.
- `lib/kiln_web/live/onboarding_live.ex` - demo-first onboarding flow and CTA cluster.
- `lib/kiln_web/live/templates_live.ex` - current start surface, first-run hero, and greenfield handlers.
- `lib/kiln_web/live/run_board_live.ex` - run board framing and optional shortcut insertion points.
- `lib/kiln_web/live/settings_live.ex` - current template-only resume plumbing.
- `.planning/phases/29-attach-entry-surfaces/29-CONTEXT.md` - locked scope and product decisions.
- `.planning/phases/29-attach-entry-surfaces/29-UI-SPEC.md` - required ids and surface contract.
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md` - milestone truth and requirement mapping.
- `https://hexdocs.pm/phoenix_live_view/live-navigation.html` - current LiveView guidance for `navigate`, `push_navigate/2`, and `push_patch/2`.
- `https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html` - current LiveView navigation semantics.
- `https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html` - current routable LiveView testing idioms.

### Secondary (MEDIUM confidence)

- `.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md` - longer-term attach/fork/clone framing informing scope boundaries.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - current project stack is pinned in `mix.lock` and Phase 29 needs no new dependency.
- Architecture: HIGH - route structure, shell behavior, and existing start-surface seams are directly visible in the codebase and aligned with official LiveView navigation docs.
- Pitfalls: MEDIUM - most pitfalls are strongly supported by current code and context, but one scope-creep warning relies on product judgment rather than a runtime failure mode.

**Research date:** 2026-04-24
**Valid until:** 2026-05-24

## RESEARCH COMPLETE

**Phase:** 29 - attach-entry-surfaces
**Confidence:** HIGH

### Key Findings

- `/templates` is already the strongest attach discovery surface, while `/onboarding` should only add a secondary attach branch and `/` should stay optional/minor for attach. [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/onboarding_live.ex] [VERIFIED: lib/kiln_web/live/run_board_live.ex]
- Phase 29 should add exactly one new route-backed LiveView, `/attach`, and keep attach state separate from scenarios, templates, and settings return plumbing. [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md] [VERIFIED: lib/kiln/demo_scenarios.ex] [VERIFIED: lib/kiln_web/live/settings_live.ex]
- Existing LiveView and route-smoke tests already give a strong ownership seam; Phase 29 mainly needs one new `AttachEntryLive` test file plus additive assertions in onboarding/templates/routes coverage. [VERIFIED: test/kiln_web/live/onboarding_live_test.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/route_smoke_test.exs]
- The main regression risk is product honesty, not framework complexity: do not imply repo validation, workspace hydration, dirty-worktree refusal, or branch/PR behavior before Phases 30-31. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/29-attach-entry-surfaces/29-CONTEXT.md]

### File Created

`.planning/phases/29-attach-entry-surfaces/29-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Existing Phoenix/LiveView stack is pinned and sufficient. |
| Architecture | HIGH | Recommendations map directly to current router and LiveView surface seams. |
| Pitfalls | MEDIUM | Scope-creep risks are partly product/UX judgment, though the codebase and context make the likely regressions clear. |

### Open Questions (RESOLVED)

- `/attach` should use full chrome so it reads as a normal start surface aligned with `/templates`.
- The optional run-board shortcut should be deferred out of Phase 29 to keep scope centered on `/onboarding`, `/templates`, and `/attach`.

### Ready for Planning

Research complete. Planner can now create PLAN.md files.
