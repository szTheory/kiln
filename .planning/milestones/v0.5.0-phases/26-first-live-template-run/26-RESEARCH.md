# Phase 26: First live template run - Research

**Researched:** 2026-04-23  
**Domain:** Phoenix LiveView first-run guidance, backend readiness preflight, and run-detail proof UX  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked decisions

- `hello-kiln` must be the single recommended first local live run. Scenario framing may remain, but it cannot override the primary recommendation. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`]
- `/templates` remains the canonical catalog, with one explicit first-run hero above the broader catalog. Other templates stay visible with honest role labels rather than hidden or de-emphasized into ambiguity. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`]
- `Use template` and `Start run` stay separate but adjacent. Phase 26 must not collapse them into a one-click opaque flow. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`; `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md`]
- Live start must perform a backend-authoritative preflight, and blocked recovery must route to the first missing `/settings#settings-item-*` anchor in checklist order while preserving return context for the chosen template. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`; `lib/kiln/operator_setup.ex`]
- Successful live launch should land on `/runs/:id`, and run detail should answer immediate proof questions before the operator needs the broader run board. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`; `lib/kiln_web/live/run_detail_live.ex`]

### Deferred ideas

- No broader template-ranking/filter system or scenario-driven recommendation switching. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`]
- No combined “use template and start run” choreography. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`]
- No repository-level automated proof artifact for the full local-first journey; Phase 27 owns that. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`; `.planning/REQUIREMENTS.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LIVE-01 | Identify one built-in template as the recommended first local live run. | `hello-kiln` already has the smallest-scope manifest metadata and is already the default recommendation for the default scenario, but `/templates` still gives scenario-specific recommendations equal visual weight. [VERIFIED: `priv/templates/manifest.json`; `lib/kiln/demo_scenarios.ex`; `lib/kiln_web/live/templates_live.ex`] |
| LIVE-02 | Starting a live run performs a readiness preflight and routes the operator back to the missing setup step when blocked. | `OperatorSetup.checklist/0` already defines deterministic blocker order and exact `/settings#settings-item-*` anchors, and `RunDirector.start_run/1` already enforces backend readiness. The current template flow bypasses that seam by calling `Runs.create_for_promoted_template/2` directly and never invoking `RunDirector.start_run/1`. [VERIFIED: `lib/kiln/operator_setup.ex`; `lib/kiln/runs/run_director.ex`; `lib/kiln_web/live/templates_live.ex`; `test/kiln/runs/run_director_readiness_test.exs`] |
| LIVE-03 | Once ready, the operator can launch one believable local live run and see enough run detail to confirm Kiln is operating. | `TemplatesLiveTest` already proves `/templates` -> `/runs/:id`, and `RunDetailLive` already exposes `#run-detail-overview`, `#run-detail-current-state`, and `#run-detail-next-action`, but the current copy still frames the run board as the fast primary balcony instead of making run detail the first proof surface after launch. [VERIFIED: `test/kiln_web/live/templates_live_test.exs`; `lib/kiln_web/live/run_detail_live.ex`; `test/kiln_web/live/run_detail_live_test.exs`] |
</phase_requirements>

## Summary

Phase 26 does not need new route families or a new run system. The repo already has the right primitives: a built-in template catalog, a promoted-spec materialization step, a backend readiness gate in `RunDirector.start_run/1`, stable `/settings#settings-item-*` anchors, and a routed run-detail surface. The gap is orchestration and emphasis, not missing infrastructure. [VERIFIED: repo grep]

The strongest implementation risk is that the current UI flow cannot honestly satisfy `LIVE-02`. `TemplatesLive.handle_event("start_run", ...)` creates a queued run directly through `Runs.create_for_promoted_template/2` and then navigates to `/runs/:id`, but never invokes `RunDirector.start_run/1`. That means the operator-facing path bypasses the backend-authoritative readiness preflight that already exists, so blocked starts cannot route back to the first missing settings step through the real gate. [VERIFIED: `lib/kiln_web/live/templates_live.ex`; `lib/kiln/runs/run_director.ex`]

The recommendation problem is also narrower than it first appears. `hello-kiln` is already the lowest-friction candidate in `priv/templates/manifest.json`, and the default scenario already points to it. The ambiguity comes from the current catalog presentation: scenario recommendation badges and `gameboy-vertical-slice` special treatment still visually compete with the first-run answer. Phase 26 should replace that competition with one explicit first-run hero and honest secondary role labels. [VERIFIED: `priv/templates/manifest.json`; `lib/kiln/demo_scenarios.ex`; `lib/kiln_web/live/templates_live.ex`]

**Primary recommendation:** split the phase into three execution slices:
1. Reframe `/templates` around one `hello-kiln` first-run hero while keeping the catalog honest.
2. Route the `Start run` path through a new backend start seam that can return either success or a typed preflight block carrying the first settings anchor and template return context.
3. Strengthen `/runs/:id` as the proof-first arrival surface and close the phase with focused verification evidence tied to the exact LiveView and domain commands that prove `LIVE-01` to `LIVE-03`. [INFERRED from code + context]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| First-run recommendation and catalog framing | Frontend Server (SSR) | Manifest metadata | `TemplatesLive` already owns the catalog presentation while `priv/templates/manifest.json` provides stable template intent. [VERIFIED: `lib/kiln_web/live/templates_live.ex`; `priv/templates/manifest.json`] |
| Readiness blocker order and remediation target | API / Backend | Frontend Server (SSR) | `OperatorSetup.checklist/0` already yields ordered blocker items with stable `href` anchors. UI should consume, not reinvent, this ordering. [VERIFIED: `lib/kiln/operator_setup.ex`] |
| Final live-start gate | API / Backend | Database / Storage | `RunDirector.start_run/1` is the existing hard readiness and provider-key gate. Phase 26 should route the template flow through it rather than duplicating the decision in UI-only code. [VERIFIED: `lib/kiln/runs/run_director.ex`] |
| Run creation for built-in templates | API / Backend | Frontend Server (SSR) | `Runs.create_for_promoted_template/2` already creates queued runs, so the missing seam is a higher-level “create + preflight start” contract, not a new persistence layer. [VERIFIED: `lib/kiln/runs.ex`] |
| Post-launch proof of life | Frontend Server (SSR) | API / Backend | `RunDetailLive` already renders a routed overview, stage graph, and live data; Phase 26 should strengthen the overview instead of inventing another success page. [VERIFIED: `lib/kiln_web/live/run_detail_live.ex`] |

## Current Architecture and Gaps

### Recommendation and catalog today

- The catalog header says “Pick the smallest believable path first,” but there is no single dominant `hello-kiln` hero. [VERIFIED: `lib/kiln_web/live/templates_live.ex`]
- Scenario guidance is rendered above the catalog and the catalog uses scenario-based ring/badge treatment, which makes the recommended first run vary by scenario rather than stay anchored on `hello-kiln`. [VERIFIED: `lib/kiln_web/live/templates_live.ex`; `lib/kiln/demo_scenarios.ex`]
- `gameboy-vertical-slice` gets an additional “Closest to your dogfood goal” badge, so the current page still visually competes between multiple “recommended” ideas. [VERIFIED: `lib/kiln_web/live/templates_live.ex`]
- `hello-kiln` already has the right metadata for first-run prominence: smallest path, onboarding tag, low time hint, and standard Phoenix workflow. [VERIFIED: `priv/templates/manifest.json`]

### Start-run path today

- `Use template` promotes the selected template into a spec and stores `%{spec, revision, template_id}` in `@last_promoted`. [VERIFIED: `lib/kiln_web/live/templates_live.ex`] 
- `Start run` currently calls `Runs.create_for_promoted_template(spec, id)` and immediately navigates to `/runs/:id` on success. [VERIFIED: `lib/kiln_web/live/templates_live.ex`] 
- `Runs.create_for_promoted_template/2` only inserts a queued run. It does not check readiness or provider secrets. [VERIFIED: `lib/kiln/runs.ex`] 
- `RunDirector.start_run/1` does check readiness and missing provider keys, but the template flow does not use it. [VERIFIED: `lib/kiln/runs/run_director.ex`] 
- The current live-unready behavior is disabled-button copy plus a disconnected card with links to `/settings` and `/providers`; that is guidance, not the required backend-authoritative preflight. [VERIFIED: `lib/kiln_web/live/templates_live.ex`] 

### Run detail today

- `RunDetailLive` already exposes a strong top-of-page overview with stable ids: `#run-detail-overview`, `#run-detail-current-state`, and `#run-detail-next-action`. [VERIFIED: `lib/kiln_web/live/run_detail_live.ex`; `test/kiln_web/live/run_detail_live_test.exs`]
- The current copy still assumes the run board is the quick-state surface and run detail is where the operator goes “if you need deeper evidence.” Phase 26 wants the opposite ordering immediately after launch: run detail first, run board second. [VERIFIED: `lib/kiln_web/live/templates_live.ex`; `lib/kiln_web/live/run_detail_live.ex`] 
- The journey guide already links back to templates and onboarding, which gives Phase 26 a natural place to preserve return-context and teach the first-run story without adding a new route family. [VERIFIED: `lib/kiln_web/live/run_detail_live.ex`] 

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| Phoenix LiveView | Phoenix 1.8.5 / LiveView 1.1.28 | `/templates`, `/settings`, `/runs/:id` UX surfaces | All Phase 26 route seams are already LiveViews in one session family. [VERIFIED: `mix.exs`; repo grep] |
| `Kiln.OperatorSetup` | app-internal | Ordered readiness contract with stable blocker anchors | Already the canonical readiness/remediation projection from Phase 25. [VERIFIED: `lib/kiln/operator_setup.ex`] |
| `Kiln.Runs` + `Kiln.Runs.RunDirector` | app-internal | Queued run creation and backend start gate | The required preflight should extend these existing domain seams rather than re-implement run gating in the UI. [VERIFIED: `lib/kiln/runs.ex`; `lib/kiln/runs/run_director.ex`] |

### Supporting

| Library / Module | Purpose | When to Use |
|------------------|---------|-------------|
| `Phoenix.LiveViewTest` | UI flow and routed destination proof | Use for `TemplatesLive` and `RunDetailLive` first-run behavior. [VERIFIED: existing tests] |
| `OperatorReadiness` / `OperatorSetup` tests | Backend readiness and settings-anchor proof | Extend when phase code adds new preflight return shapes or blocker helpers. [VERIFIED: existing tests] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One explicit first-run hero for `hello-kiln` | Scenario-driven recommendation switching | Violates the phase context by making the first trusted path depend on scenario state. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`] |
| Backend start seam that returns a typed blocked outcome | Disabled button as the only unreadiness enforcement | Fails `LIVE-02` because the real preflight never runs. [VERIFIED: `lib/kiln_web/live/templates_live.ex`; `.planning/REQUIREMENTS.md`] |
| Strengthen `/runs/:id` as the proof destination | Add a third “launch success” surface on `/templates` | Creates another competing truth surface and duplicates run-state proof. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`] |

## Architecture Patterns

### Pattern 1: Recommendation hero above an honest catalog

**What:** Present `hello-kiln` in a single dedicated first-run hero that explains readiness -> use template -> start run -> inspect proof, then keep the full catalog visible below with role labels for other templates. [INFERRED from context + existing catalog]

**When to use:** `/templates` index and any supporting scenario copy. [INFERRED]

**Why it fits here:** The catalog already has the necessary metadata and stable ids, but recommendation emphasis is currently split between scenario and dogfood signals. [VERIFIED: `priv/templates/manifest.json`; `lib/kiln_web/live/templates_live.ex`]

### Pattern 2: Backend preflight with UI recovery routing

**What:** A single backend-facing start function should either:
- create and start the run successfully, returning the run id, or
- return a typed blocked outcome carrying the first blocker `href` and any template return context the UI needs.

**When to use:** `TemplatesLive.handle_event("start_run", ...)` in live mode. [INFERRED]

**Why it fits here:** `RunDirector.start_run/1` is already the authoritative gate, but it needs a higher-level start seam so the UI can avoid creating “pretend” success paths and can route deterministic settings recovery. [VERIFIED: `lib/kiln/runs.ex`; `lib/kiln/runs/run_director.ex`] 

### Pattern 3: Proof-first run-detail arrival

**What:** The top of `/runs/:id` should immediately answer:
- did the run start?
- what state is it in?
- what is active or next?
- where should the operator look next?
- what recent evidence shows the system is moving?

**When to use:** run-detail overview and focused tests. [INFERRED]

**Why it fits here:** The route and stable overview ids already exist, so the phase can deepen the top summary and add a small recent-evidence excerpt without changing the run-detail information architecture wholesale. [VERIFIED: `lib/kiln_web/live/run_detail_live.ex`; `test/kiln_web/live/run_detail_live_test.exs`] 

## Common Pitfalls

### Pitfall 1: “Preflight” that never touches the backend gate

**What goes wrong:** The UI disables buttons or checks `@setup_summary` and calls that “preflight.” [VERIFIED: current code shape]
**Why it happens:** `TemplatesLive` already has readiness-aware labels and disconnected-state messaging, so it is tempting to stop there. [VERIFIED: `lib/kiln_web/live/templates_live.ex`] 
**How to avoid:** Route the launch path through a domain function that ultimately uses `RunDirector.start_run/1` and returns typed blocked outcomes for routing. [INFERRED]

### Pitfall 2: Creating queued runs even when readiness is missing

**What goes wrong:** A blocked launch still inserts a run, leaving a misleading queued record behind. [INFERRED from current API split]
**Why it happens:** `Runs.create_for_promoted_template/2` and `RunDirector.start_run/1` are currently separate steps. [VERIFIED: `lib/kiln/runs.ex`; `lib/kiln/runs/run_director.ex`]
**How to avoid:** Add a higher-level API that checks or cleansly handles preflight before treating the start as successful, and make the UI success path depend on that result rather than on queued-row creation alone. [INFERRED]

### Pitfall 3: Letting scenario framing override the first-run answer

**What goes wrong:** The page still reads as “recommended template depends on scenario,” which leaves operators guessing again. [VERIFIED: current catalog banner/badge behavior]
**Why it happens:** `DemoScenarios` already ships three scenario recommendations, and the current page uses them directly. [VERIFIED: `lib/kiln/demo_scenarios.ex`; `lib/kiln_web/live/templates_live.ex`] 
**How to avoid:** Keep scenario copy secondary and use it to explain “what next after the first run,” not “what should I trust first.” [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`] 

### Pitfall 4: Adding another success surface on `/templates`

**What goes wrong:** The operator sees a success panel on `/templates`, then a proof panel somewhere else, then run detail, with no clear source of truth. [INFERRED]
**Why it happens:** It feels easier to enrich the existing success panel than to make run detail carry the proof burden. [INFERRED]
**How to avoid:** Keep `/templates` focused on recommendation and launch initiation; put post-launch proof on `/runs/:id` as the context already requires. [VERIFIED: `.planning/phases/26-first-live-template-run/26-CONTEXT.md`] 

## Code Examples

Verified seams from the current repo:

### Deterministic blocker anchors already exist

```elixir
# Source: lib/kiln/operator_setup.ex
%{
  id: :docker,
  href: "/settings#settings-item-docker"
}
```

[VERIFIED: `lib/kiln/operator_setup.ex`]

### Backend readiness gate already exists

```elixir
# Source: lib/kiln/runs/run_director.ex
def start_run(run_id) when is_binary(run_id) do
  if not OperatorReadiness.ready?() do
    {:error, :factory_not_ready}
  else
    start_run_when_ready(run_id)
  end
end
```

[VERIFIED: `lib/kiln/runs/run_director.ex`]

### Current template path bypasses that gate

```elixir
# Source: lib/kiln_web/live/templates_live.ex
case Runs.create_for_promoted_template(spec, id) do
  {:ok, run} ->
    {:noreply, push_navigate(socket, to: ~p"/runs/#{run.id}")}
```

[VERIFIED: `lib/kiln_web/live/templates_live.ex`]

### Existing run-detail overview selectors are already stable

```elixir
# Source: lib/kiln_web/live/run_detail_live.ex
<section id="run-detail-overview" class="grid gap-3 xl:grid-cols-4">
  <p id="run-detail-current-state" class="kiln-h2 mt-2">
  <p id="run-detail-next-action" class="kiln-body mt-2 text-sm text-base-content/70">
```

[VERIFIED: `lib/kiln_web/live/run_detail_live.ex`; `test/kiln_web/live/run_detail_live_test.exs`]

## Recommended Planning Shape

1. **Plan 26-01:** `/templates` first-run hero and honest catalog reframing around `hello-kiln`; update template tests for the new recommendation contract. [INFERRED]
2. **Plan 26-02:** backend start seam plus blocked recovery routing to `/settings#settings-item-*` with template return context; update domain and LiveView tests. [INFERRED]
3. **Plan 26-03:** proof-first `/runs/:id` arrival experience plus phase verification artifact and planning-SSOT closure after the code paths pass. [INFERRED]

---
*Phase: 26-first-live-template-run*  
*Research completed: 2026-04-23*
