---
phase: 08
slug: operator-ux-intake-ops-unblock-onboarding
status: approved
shadcn_initialized: false
preset: kiln-brand
created: 2026-04-21
reviewed_at: 2026-04-21T00:00:00Z
---

# Phase 08 — UI Design Contract

> Visual and interaction contract for **Operator UX** (BLOCK-02, BLOCK-04, INTAKE-01..03, OPS-01, OPS-04, OPS-05, UI-07..09): intake inbox, provider health, cost intelligence, diagnostic bundle, unblock panel, onboarding wizard, factory header, run progress, agent ticker. Extends Phase 07 (`07-UI-SPEC.md`); same stack: Phoenix LiveView 1.1 + Tailwind v4. **Domain routes only** — nothing new under `/ops/*` (D-801).

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Phoenix `core_components` + Tailwind v4) |
| Preset | `kiln-brand` (inherit Phase 07 semantic mapping) |
| Component library | `Layouts.app`, `KilnWeb.CoreComponents`, new `KilnWeb.Components.FactoryHeader`, `KilnWeb.Components.RunProgress`, `KilnWeb.Components.UnblockPanel`, `KilnWeb.Components.AgentTicker` |
| Icon library | `<.icon name="hero-*">` only |
| Font | Inter (UI sans), IBM Plex Mono (issue slugs, token/USD, playbook commands, diagnostic manifest) |

---

## Information Architecture (locked)

| Route | LiveView / surface | Notes |
|-------|-------------------|--------|
| `/inbox` | `InboxLive` | Draft triage; links to promote → existing spec flow |
| `/providers` | `ProviderHealthLive` | Per-provider cards; poll interval documented in plan |
| `/onboarding` | `OnboardingLive` | Wizard + re-entry `?review=1`; not a permanent blocking modal (D-806) |
| `/costs` | `CostLive` | Intel / advisory via `?tab=intel` or path segment **same LiveView** (D-802) |
| `/` | `RunBoardLive` | **Agent ticker** home only (D-823) |
| `/runs/:id` | `RunDetailLive` | Unblock panel when blocked; progress in header; optional diagnostic trigger |

---

## Spacing, Typography, Color

Inherit **Phase 07** spacing scale, two-weight typography (400 / 600), and **60/30/10** color roles verbatim. **Ember** remains reserved per 07 list; **Clay** for blocked severity / destructive diagnostic confirmations.

**Additional accent rule:** Provider RAG uses **semantic status tokens** (green/amber/red) implemented as **text + border + icon**, not Ember fills on whole cards — keeps Ember for primary CTAs only.

---

## Copywriting Contract (Phase 8 additions)

| Element | Copy |
|---------|------|
| Inbox empty | Heading: "No drafts in the inbox" — Body: "Create a spec from text, import markdown, or pull a GitHub issue. Promote a draft when it is ready to run." |
| Inbox row actions | "Promote", "Archive", "Edit" |
| GitHub import CTA | "Import from GitHub" |
| Import in progress | "Syncing issue…" |
| Follow-up button (run detail, merged runs) | "File as follow-up" |
| Provider card — API key missing | "API key missing" |
| Provider card — healthy | "Operational" |
| Cost intel empty | "Not enough history for an advisory yet" (reuse Phase 7 pattern) |
| Diagnostic bundle | "Bundle last 60 minutes" — success flash: "Diagnostic bundle ready" |
| Unblock panel title | "Run blocked" |
| Unblock retry | "I fixed it — retry" |
| Onboarding wizard title | "Set up Kiln" |
| Onboarding step complete | "Verified" |
| Onboarding gate flash | "Complete setup before starting a run" |
| Factory header — active runs | "{n} active" (tabular numerals) |
| Factory header — blocked | "{n} blocked" with Clay badge when > 0 |
| Progress — no estimate | "Not enough history" |
| Ticker empty | "No recent agent activity" |

All Phase 07 microcopy for run board, detail, costs base tab, audit remains authoritative where surfaces overlap.

---

## Layout, Streams & Performance

| LiveView | Primary focal | Streams / async |
|----------|---------------|-----------------|
| `InboxLive` | Draft list + row actions | `stream(:drafts, …)`; promote/archive optimistic UI with server reconciliation |
| `ProviderHealthLive` | Grid of provider cards | Assigns refreshed on poll timer; **no** per-run PubSub |
| `OnboardingLive` | Stepper + probe status rows | Assigns + `phx-submit` per step; links open docs in new tab |
| `CostLive` (intel) | Advisory strip + pivot table | Reuse 07 streaming rules when row count > 100 |
| `FactoryHeader` | Counts + health lights | Subscribes **`factory:summary`** only (D-821–822); debounced server publish |
| `RunProgress` | Stages fraction + elapsed + staleness dot | Assigns from parent; **no** independent subscription |
| `AgentTicker` (home) | Rolling feed | `stream` prepend `at: -1`, cap 50–100 rows, `stream_delete` tail (D-824–825) |

**Cross-cutting:** `prefers-reduced-motion` for ticker highlight (D-827). Every `handle_event/3` includes auth check path (`allow?` stub acceptable solo v1). Stable IDs: `id="inbox"`, `id="provider-health"`, `id="onboarding-wizard"`, `id="factory-header"`, `id="agent-ticker"`, `id="unblock-panel"`, `id="run-progress-{run_id}"` (or component root pattern documented in plan).

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Phoenix / Kiln core | same as Phase 07 | unchanged |
| Third-party UI kits | none | n/a |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-04-21 (orchestrated with `/gsd-plan-phase 8` — UI gate satisfied before planning)

---

## UI-SPEC VERIFIED (inline)

**Phase:** 8 — Operator UX  
**Status:** APPROVED

| Dimension | Verdict | Notes |
|-----------|---------|-------|
| 1 Copywriting | PASS | Typed unblock; no chat microcopy |
| 2 Visuals | PASS | Route table + focal points declared |
| 3 Color | PASS | RAG semantic colors documented; Ember discipline |
| 4 Typography | PASS | Inherits 07 |
| 5 Spacing | PASS | Inherits 07 |
| 6 Registry Safety | PASS | No new third-party UI |
