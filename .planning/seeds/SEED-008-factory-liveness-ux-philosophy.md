---
id: SEED-008
status: dormant
planted: 2026-04-20
planted_during: v0.1.0 / Phase 3 planning (captured mid-session from operator)
trigger_when: Phase 7 Core Run UI discuss/plan OR Phase 8 Operator UX discuss/plan OR any milestone touching LiveView dashboard, workflow visualization, operator experience, or "why is it hard to tell what Kiln is doing"
scope: Medium (cross-cuts Phase 7 + Phase 8 design + optional Phase 9 polish)
---

# SEED-008: Factory-Liveness UX Philosophy — Graph-Lit, Black-Box-First, Depth-On-Demand

## Why This Matters

Kiln's fundamental UX job is making autonomy **feel trustworthy without being interrogated**. A dark factory that looks dead is indistinguishable from a dark factory that IS dead. The operator needs to glance at the dashboard and *know* the factory is cranking — without having to read logs, traces, or Oban job tables to prove it.

The operator describes the feeling this way:

> "The phases should be very easy to wrap your head around and you can cluster them, chain them together in workflow graphs. Intuitive especially in the Phoenix LiveView area — maybe a graph that's lighting up, or list items of top items, some graph of activity. Match what's going on under the hood but from a black-box user perspective. Surface the technical aspect when it's relative to the user and could help them make better decisions."

The pattern the operator is pointing to is **GSD's phase-centric workflow itself** — `/gsd-ui-phase`, `/gsd-ai-integration-phase`, `/gsd-plan-phase`, `/gsd-execute-phase`, `/gsd-verify-work` etc. Each phase is a named, inspectable, chainable unit with clear state transitions. An operator using GSD builds a mental model of "what phase am I in, what does it produce, what's next" without needing internal documentation. Kiln's dashboard should give the same feel for runs.

## The Philosophy (three load-bearing principles)

### 1. Graph-lit liveness over log-digging

The **stage graph** (already in Phase 7 SC 7.2) is the primary liveness surface. Stages should visibly animate through state transitions:

- **Queued** → dim outline
- **Active** → pulsing glow in the stage's role-appropriate hue (clay/ember per brand book)
- **Completed** → solid fill with checkmark
- **Blocked** → amber border with typed reason inline
- **Failed** → muted red with retry affordance

The graph is not a static topology diagram — it's the *screen the operator looks at while it runs*. Edge animations showing data flow (workspace diff propagating from Coder → Tester, agent chatter streaming) are valuable if they communicate state, not decorative if they don't.

Success metric: a naive observer with zero Kiln context, looking at the graph for 10 seconds, can correctly describe which stage is working on what.

### 2. Black-box-first, technical-depth on demand

Every surface has a **two-layer disclosure model**:

- **Outer layer (default, black-box):** what is happening in human terms. Not tokens, traces, or process IDs. Plain-language stage names ("Coder is editing `lib/kiln/agents/adapter.ex`"), run state ("verifying build — 3/12 scenarios green"), ETA when available.
- **Inner layer (click-to-expand):** the technical detail. Telemetry span tree, diff viewer, Oban args, audit ledger row, model routing record, token spend breakdown. Same widget, progressive disclosure.

The outer layer must never leak internals the operator doesn't need. The inner layer must never sanitize away the truth.

This is NOT "dashboard vs admin console" — it's *the same widget at two resolutions*. An operator who has never heard of `telemetry.execute/3` should be able to read the outer layer; an operator debugging a regression should be able to descend to the inner layer in one click without navigating away.

### 3. GSD-style phase clustering / chainability in the UI vocabulary

GSD has crystallized a phase vocabulary: `discuss → plan → execute → verify → ship`. Each has a well-understood output and trigger condition. Kiln's runs already map cleanly onto this mental model (planning → coding → testing → verifying → merged). The dashboard should **reuse that vocabulary**, not invent a parallel one.

Concrete UI implications:

- A **run** is a chain of stages, rendered as a left-to-right flow with wave columns (matching PLAN.md frontmatter wave semantics).
- The **workflow registry** view (Phase 7 SC 7.3) reads like GSD's ROADMAP.md — each workflow is a named, inspectable unit with a goal line, dependencies, and success criteria.
- **Cross-run views** cluster runs by workflow, not by date first. The operator should see "all runs of `phoenix_saas_feature`" grouped, the way GSD groups phases under a milestone.
- Microcopy matches GSD's verb vocabulary: "Start run", "Resume run", "Verify changes", "Promote build", "View trace", "Retry step", "Waiting on upstream", "Manual review required" (already in brand book — this seed reinforces the principle).

## When to Surface

- **Phase 7 discuss/plan** (primary trigger) — operator-dashboard scoping is exactly when this principle applies. The existing SC 7.2 ("stage graph topologically laid out") benefits from being upgraded with explicit liveness/animation requirements; SC 7.6 (brand-book compliance) benefits from the two-layer disclosure contract.
- **Phase 8 discuss/plan** — the agent activity ticker (SC 8.10) and factory header (SC 8.8) are prime surfaces for Principle 1; the unblock panel (SC 8.6) is a prime surface for Principle 2.
- **First user-testing / dogfood retrospective (Phase 9)** — if operators report "it's hard to tell what Kiln is doing," this seed is the corrective.
- **Any milestone touching observability UX** — telemetry dashboards, trace viewers, audit explorer all inherit these three principles.

## Relationship to Existing Work

This seed is **not net-new scope** for Phases 7+8; it's a **design directive** that sharpens decisions made during their discuss/plan phases. Specifically:

- **Reinforces** Phase 7 SC 7.2 (stage graph) — adds explicit liveness animation requirements.
- **Reinforces** Phase 7 SC 7.6 (brand-book compliance) — adds the two-layer disclosure contract.
- **Reinforces** Phase 8 SC 8.8 (factory header visible on every page) — header is a black-box-first surface.
- **Reinforces** Phase 8 SC 8.10 (agent activity ticker) — ticker is graph-lit liveness manifest.
- **Complements** SEED-001 (operator feedback loop) — the feedback widget lives in the inner/expanded layer of whichever stage the operator wants to nudge.
- **Complements** SEED-002 (remote operator dashboard) — the two-layer disclosure works especially well on mobile (outer layer is glanceable, inner layer is drill-down).

## Scope Estimate

**Medium.** This is primarily:

- A ~2-page **UX principles document** (`.planning/research/UX-PRINCIPLES.md` or similar) produced during Phase 7 discuss that Phase 7+8 planning must read.
- A handful of **component-library tweaks** to the brand-book components (state tokens, animation primitives, disclosure patterns).
- **Per-stage role-appropriate hue mapping** (Coder uses Clay, Verifier uses Ember-soft, Audit uses Smoke, etc. — choose from the brand palette).
- **Acceptance criteria additions** in Phase 7+8 PLAN.md files that verify the liveness + disclosure contract.

Not a new phase. Not a rewrite. A principle that, applied consistently, differentiates Kiln from "another CI dashboard" and makes the dark factory feel alive the way GSD's phase chain feels alive.

## Open Questions (for Phase 7 discuss to answer)

1. **Animation budget** — how much motion is permitted under the brand-book principle "restraint over spectacle"? Calm pulse vs Linear-style micro-transitions vs nothing-just-color-change. Probably calm pulse + color-change, no ostentatious motion.
2. **Graph layout algorithm** — topological (dot/Graphviz) vs swimlanes (wave columns) vs force-directed. Swimlanes by wave match the PLAN.md mental model; topological reads better for complex DAGs. Decide after prototyping both on a real workflow.
3. **Inner-layer depth ceiling** — how deep does "click to expand" go? Single expansion with 80% of the useful detail? Or nested progressive disclosure down to raw JSON payloads? Probably single-expansion with a "View raw" escape hatch to the audit ledger / Oban Web / LiveDashboard.
4. **Liveness beacon when idle** — if no runs are active, should the dashboard feel idle-calm or still animate to prove it's alive? (Pulse the factory header's "0 active" indicator slowly? Or just show last-run-completed timestamp prominently?)
5. **Applicability to Workflow YAML authoring** — the workflow registry (read-only per Phase 7 anti-feature) — does the "graph-lit" principle apply to the YAML-to-graph render, or only to live runs?

## Concrete Artifacts (hypothesized, for Phase 7+8 to refine or discard)

- `KilnWeb.Components.StageNode` — brand-book compliant stage node with state-driven hue + optional pulse
- `KilnWeb.Components.Disclosure` — two-layer outer/inner component wrapping any widget
- `KilnWeb.Components.WorkflowGraph` — live-updating graph, subscribes to `run:{run_id}` PubSub, re-renders stage nodes on state change
- `.planning/research/UX-PRINCIPLES.md` — the three-principle doc, treated as a spec input for Phase 7+8 plans (analogous to `kiln-brand-book.md` but focused on liveness + disclosure rather than palette/type)
- An optional **animation primitives** sub-library (CSS custom properties for pulse-rate / transition-duration per the brand's "calm" voice)

## Why This Is Load-Bearing for Kiln's Thesis

Kiln's elevator pitch is "given a spec, ships working software with no human intervention." The UX's job is making that pitch *feel* true at a glance. A dark factory with an inscrutable dashboard reads as "black box I have to trust" — which is exactly the Thing That Alienates Operators From AI Systems. A dark factory with a graph-lit, black-box-first, depth-on-demand dashboard reads as "a factory I can watch from the balcony and drop into the line whenever I want" — which is the Thing That Earns Trust.

The difference is almost entirely in Phase 7+8 execution, not in the underlying runtime. This seed exists to make sure that execution lands with the right design taste rather than defaulting to CI-dashboard-tropes.

---

*Planted 2026-04-20 during Phase 3 planning. Triggers at Phase 7 discuss. Not a phase, a principle.*
