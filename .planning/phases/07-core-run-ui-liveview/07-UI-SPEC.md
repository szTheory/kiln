---
phase: 07
slug: core-run-ui-liveview
status: approved
shadcn_initialized: false
preset: kiln-brand
created: 2026-04-21
reviewed_at: 2026-04-21T00:00:00Z
---

# Phase 07 — UI Design Contract

> Visual and interaction contract for **Core Run UI** (UI-01..UI-06): run board, run detail, workflow registry, cost dashboard, audit ledger. Phoenix LiveView 1.1 + Tailwind v4; no React/shadcn. Locked to `prompts/kiln-brand-book.md` and `CLAUDE.md` brand contract.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Phoenix `core_components` + Tailwind v4) |
| Preset | `kiln-brand` (semantic mapping below; override daisyUI defaults where they conflict with palette) |
| Component library | `Layouts.app`, `KilnWeb.CoreComponents`, new `KilnWeb.Components.*` for run/cost/audit shells |
| Icon library | `<.icon name="hero-*">` only |
| Font | Inter (UI sans), IBM Plex Mono (diffs, YAML, logs, code, timestamps, token/USD figures in tabular numerals) |

---

## Spacing Scale

Declared values (multiples of 4px):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon gaps, inline pills |
| sm | 8px | Dense toolbars, kanban card gutters |
| md | 16px | Default padding inside panels |
| lg | 24px | Section padding, column gutters |
| xl | 32px | Page gutters |
| 2xl | 48px | Major section breaks (board vs. page chrome) |
| 3xl | 64px | Rare full-bleed breaks only |

Exceptions: **44px minimum hit target** for sole primary icon buttons (accessibility); treat as documented exception to the 4px grid for touch targets only — prefer labeled buttons at `md` padding where possible.

---

## Typography

Exactly **two weights**: **400** (body, supporting copy) and **600** (labels-as-headings, column titles, emphasized numerics). No third weight.

| Role | Size | Weight | Line height |
|------|------|--------|-------------|
| Body | 16px | 400 | 1.5 |
| Label | 12px | 600 | 1.4 (uppercase optional for table headers only; default sentence case) |
| Heading | 20px | 600 | 1.3 |
| Mono (diff, YAML, log, code) | 13px | 400 | 1.55 (IBM Plex Mono) |

---

## Color

Explicit **60 / 30 / 10** roles:

| Role | Value | Usage |
|------|-------|-------|
| Dominant (~60%) | `#121212` (Coal) | Page background, full-bleed canvas |
| Secondary (~30%) | `#1B1D21` (Char) + `#262B31` (Iron) for depth | Cards, column wells, side rails, inset panels |
| Accent (~10%) | `#E07A3F` (Ember) | See reserved list below |
| Destructive / severe error | `#9A5634` (Clay) | Destructive confirmations, blocked/escalated severity, failed checks |
| Muted text | `#8C857D` (Smoke) | Secondary metadata on cards |
| Primary readable text | `#F5EFE6` (Bone) on Coal/Char; `#161514` (Ink) on Paper if a light surface is ever used |

Accent (Ember) reserved for: **primary run action** (`Start run`, `Resume run`), **active run** indicator on the board, **focus ring** on interactive controls, **in-progress** stage node in the graph, **single** “you should look here” call-to-action per viewport — never full paragraphs, never every link, never column backgrounds.

Supporting neutrals: **Ash** `#C7BFB5` for borders/dividers; **Paper** `#FAF6F0` reserved for printable/export surfaces only, not default dark UI.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA (board) | "Start run" |
| Primary CTA (blocked / paused path) | "Resume run" |
| Open detail / telemetry | "View trace" |
| Re-drive failed stage | "Retry step" |
| Verify / CI | "Verify changes" / success: "Build verified" / failure: "Verification failed" |
| Upstream wait | "Waiting on upstream" |
| Manual gate (if shown) | "Manual review required" |
| PR checks on card (GIT-03) | "Checks passing" / "Checks failing" (never generic "OK") |
| Run board empty state heading | "No runs in flight" |
| Run board empty state body | "Start a run from the workflow registry when you are ready. New activity appears here in real time." |
| Run detail — no stage selected | "Select a stage" (body: "Choose a stage in the graph to inspect diff, logs, events, and agent output.") |
| Run detail — logs collapsed empty | "No log lines for this stage yet" |
| Run detail — agent chatter empty | "No agent messages for this stage yet" |
| Workflow registry empty | "No workflows loaded" (body: "Load a workflow from disk to inspect YAML and version history here. Editing stays out of the browser.") |
| Cost dashboard empty | "No spend recorded yet" (body: "Cost appears after agents run. Confirm telemetry from the adapter is enabled if this stays empty.") |
| Audit ledger empty (filters) | "No events match these filters" (body: "Widen the time range or clear filters. Audit data is read-only.") |
| Audit ledger error / load fail | "Audit view failed to load" (body: "Retry. If it persists, check database connectivity and try again.") |
| Destructive confirmation (if a cancel/stop is added later) | Named action only, e.g. "Stop run" — confirm: "Stop run: queued work is discarded and cannot be resumed." |

---

## Layout, Streams & Performance

| LiveView | Primary focal | Streams / async |
|----------|----------------|-----------------|
| `RunBoardLive` | Kanban columns by run state; **center of gravity** = column for `coding` / `verifying` (where attention usually is) | `stream(:runs, …)` per column or single stream with column assign; PubSub `runs` topic; card lists never plain assigns |
| `RunDetailLive` | **Stage graph** (topological layout) as top anchor; selected stage drives diff / logs / events / chatter panes | Separate streams: `stages`, `logs`, `events`, `chatter`; bounded log buffer (cap + trim UI-side); diff and YAML use mono typography |
| `WorkflowLive` | Read-only YAML viewer + version list side-by-side | Versions stream if long; YAML body is single assign or streamed chunks for huge files via `stream_async/4` |
| `CostLive` | Summary strip (today / week / projection) then pivot breakdown | Tables stream rows when > 100 rows; else assigns acceptable |
| `AuditLive` | Filter toolbar (run, stage, actor, event kind, time range) then timeline | `stream(:events, …)`; **no write path** to `audit_events` |

**Cross-cutting:** Every `handle_event/3` includes an auth check path (solo v1: explicit `allow?` stub is fine but must exist). Use `LazyHTML` selectors in tests keyed off stable IDs (`id="run-board"`, `id="audit-filter-form"`, etc.).

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Phoenix / Kiln core | `<Layouts.app>`, `<.icon>`, `<.form>`, `<.input>` | not required |
| Third-party UI kits | none | n/a |

---

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS
- [x] Dimension 2 Visuals: PASS
- [x] Dimension 3 Color: PASS
- [x] Dimension 4 Typography: PASS
- [x] Dimension 5 Spacing: PASS
- [x] Dimension 6 Registry Safety: PASS

**Approval:** approved 2026-04-21 (inline verification per `/gsd-ui-phase` orchestration)

---

## UI-SPEC VERIFIED (inline)

**Phase:** 7 — Core Run UI (LiveView)  
**Status:** APPROVED

| Dimension | Verdict | Notes |
|-----------|---------|-------|
| 1 Copywriting | PASS | Verb+noun CTAs; empty/error pairs include next step |
| 2 Visuals | PASS | Focal point per route declared above |
| 3 Color | PASS | 60/30/10 explicit; accent list is restrictive; Clay for destructive/error severity |
| 4 Typography | PASS | Four sizes, two weights (400, 600) |
| 5 Spacing | PASS | 4px-scale tokens; one justified 44px a11y exception |
| 6 Registry Safety | PASS | No third-party registries |

**Recommendations (non-blocking):** When implementing, add a one-page brand checklist in `mix check` or Credo doc hook so UI-06 stays enforced as new surfaces land.
