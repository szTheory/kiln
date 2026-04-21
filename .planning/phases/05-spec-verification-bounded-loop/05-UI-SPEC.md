---
phase: 05
slug: spec-verification-bounded-loop
status: draft
shadcn_initialized: false
preset: kiln-brand
created: 2026-04-21
---

# Phase 05 — UI Design Contract

> Visual and interaction contract for the **spec editor** (`SPEC-01`). Phoenix LiveView + Tailwind v4; no shadcn. Aligns with `prompts/kiln-brand-book.md` and `05-CONTEXT.md` D-S06.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (Phoenix core_components + Tailwind) |
| Preset | `kiln-brand` |
| Component library | Phoenix `core_components` + project layout (`Layouts.app`) |
| Icon library | `<.icon name="hero-*">` only |
| Font | Inter (UI), IBM Plex Mono (editor monospace) |

---

## Spacing Scale

Declared values (multiples of 4px):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline gaps |
| sm | 8px | Toolbar clusters |
| md | 16px | Default padding |
| lg | 24px | Editor chrome |
| xl | 32px | Page gutters |
| 2xl | 48px | Section breaks |

Exceptions: none

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|---------------|
| Body | 16px | 400 | 1.5 |
| Label | 12px | 500 | 1.4 |
| Heading | 20px | 600 | 1.3 |
| Editor mono | 13px | 400 | 1.55 (Plex Mono) |

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#121212` (Coal) | Page background |
| Secondary (30%) | `#1B1D21` (Char) | Panels, sidebar |
| Accent (10%) | `#E07A3F` (Ember) | Primary actions, focus ring |
| Destructive | `#9A5634` (Clay) | Errors, destructive confirm |

Accent reserved for: Save / Verify actions, link hover, focus ring — never full paragraph text.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | "Save revision" / "Run verify" (disabled until parse+JSV pass) |
| Empty state heading | "No spec content yet" |
| Empty state body | "Write markdown and `kiln-scenario` blocks. Changes save as new revisions." |
| Error state | "Syntax error at line {N}: {detail}" — always line reference |
| Destructive confirmation | "Discard unsaved changes" — confirm copy names the action |

---

## Layout & Interaction (D-S06)

| Surface | Behavior |
|---------|----------|
| Route | Full-page `/specs/:id/edit` under `KilnWeb` router |
| Save | Debounced autosave 2–4s + blur + Cmd/Ctrl+S; states: Saved / Saving / Unsaved / Error + `last_saved_at` |
| Versions | Timeline of revisions; read-only snapshot; diff between revisions; restore = **new** revision copying prior body |
| Verify gate | "Run verify" disabled until parser + JSV pass; preview uses **same** parse module as compiler |
| Streams | Use `stream/3` only if revision/event list is large; small revision lists may use assigns per AGENTS.md guidance |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Phoenix core | `<Layouts.app>`, `<.input>`, `<.form>` | not required |
| Third-party UI kits | none | n/a |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending — run `/gsd-ui-review` after implementation if desired
