# Phase 999.1: Docs & Landing Site (BACKLOG)

**Captured:** 2026-04-18
**Status:** Backlog — unscheduled
**Slot decision deferred to:** late Phase 8 / early Phase 9

## What this is

A static documentation + landing site for Kiln, hosted on GitHub Pages, CI/CD-published on every merge to `main`, brand-consistent with `prompts/kiln-brand-book.md`, inspired by (but visually distinct from) Fabro.

The site serves two purposes:

1. **Landing/marketing** — why Kiln, 60–90s operator demo, "run your first spec in 10 minutes" CTA.
2. **Documentation** — onboarding guide, spec/workflow authoring, architecture reference, configuration reference, troubleshooting. Covers new, intermediate, and advanced audiences with a strict happy-path-first bias.

Reference designs to study (take lessons, don't copy): Stripe, Linear, Prisma, Tailwind, Astro Starlight, Raycast, Framer, Vercel, Docusaurus. Explicitly do NOT clone Fabro — take inspiration only.

## Requirement cluster (`DOCS-01..DOCS-07`)

See `.planning/REQUIREMENTS.md` § "Docs & Release (v1.0+)" for the canonical list. Summary:

| ID | Scope |
|---|---|
| `DOCS-01` | Landing/home page — single-page why-Kiln + operator video/demo + "first spec in 10 minutes" CTA |
| `DOCS-02` | Operator onboarding guide — zero-to-first-run walkthrough, footguns, happy-path-first |
| `DOCS-03` | Workflow & spec authoring — YAML schema reference, BDD scenario patterns, holdout strategy |
| `DOCS-04` | Architecture & internals — four-layer model, supervision tree, audit ledger, Mermaid diagrams kept in sync via CI |
| `DOCS-05` | Configuration reference — every env var, config.json key, kiln.toml/workflow.yaml field; cross-linked from error messages |
| `DOCS-06` | CI/CD auto-publish — gh-pages deploy on merge to `main`; broken-link + spell-check in `mix check`; automated initial setup |
| `DOCS-07` | Static site generator choice — Astro Starlight / Docusaurus / VitePress / MkDocs Material (decide at Phase 10 discuss) |

## Design constraints (from `prompts/kiln-brand-book.md`)

- Typography: Inter (sans), IBM Plex Mono (code). Geist allowed for marketing headers only.
- Palette: coal / char / iron / bone / ash / smoke / clay / ember / paper / ink.
- Visual: borders over shadows, rectangles with softened corners, clear state hierarchy.
- Voice: precise, calm, grounded, competent, restrained. No hype, short sentences, concrete nouns, active verbs.
- Microcopy: "Start run", "Resume run", "Verify changes", "Build verified", "Retry step", "Waiting on upstream".
- Avoid: cyberpunk neon, flames, robots, AI brains, mascots, fantasy forge imagery.

## Why backlog (not Phase 10 yet)

Locking a slot today would either:
- Add scope risk to v0.1.0 (9 phases + dogfood is already substantial), or
- Commit to v1.1 prematurely before we know what v0.1.0 actually ships.

Revisit at late Phase 8 / early Phase 9 when remaining energy/cycles are clearer. Both slots (Phase 10 in v0.1.0, or v1.1 milestone) remain defensible.

## Promote to active milestone

```
/gsd-review-backlog
```

or, when ready:

```
/gsd-discuss-phase 999.1   # explore scope further
/gsd-plan-phase 999.1      # plan as-is
```

If promoted, the phase will be renumbered (e.g., Phase 10) via `/gsd-insert-phase`.
