---
id: todo-2026-04-18-phase-10-slot-decision
area: roadmap
captured: 2026-04-18
captured_during: Phase 1 planning
priority: medium
trigger: late Phase 8 / early Phase 9 (before v0.1.0 tag)
---

# Revisit Phase 10 slot decision — Docs & Landing Site

## The question

Does the `999.1-docs-landing-site` backlog item ship as **new Phase 10 inside the v0.1.0 milestone** (tighter product-docs binding, better first-tag impression) or as a **v1.1 milestone post-v0.1.0 tag** (keeps v0.1.0 scope focused)?

## Why this todo exists

The docs & landing site was captured to backlog on 2026-04-18 with the slot decision intentionally deferred. Two defensible answers existed at capture time:

- **Phase 10 inside v0.1.0:** CI/CD-published docs tightly bind to the shipped product; releasing v0.1.0 without a guided landing is a worse first impression.
- **v1.1 milestone:** v0.1.0 is already 9 phases + a hard dogfood validation; adding a 10th phase for a non-runtime deliverable stretches an already-substantial milestone.

At late Phase 8 / early Phase 9 we'll have a clearer read on remaining energy, cycles, and whether the docs work can realistically complete before the v0.1.0 tag without delaying it.

## Action when triggered

1. Review `DOCS-01..DOCS-07` scope in `.planning/REQUIREMENTS.md § Docs & Release (v1.0+)`.
2. Review `.planning/phases/999.1-docs-landing-site/README.md` for latest context.
3. Decide: Phase 10 (add to current milestone via `/gsd-insert-phase 10 docs-landing-site`) OR v1.1 (leave in backlog, plan as first phase of v1.1 milestone via `/gsd-new-milestone`).
4. Regardless of slot: run `/gsd-discuss-phase` before planning to pick the static site generator (DOCS-07 candidates: Astro Starlight, Docusaurus, VitePress, MkDocs Material) and decide the CI/CD publish mechanism (DOCS-06).

## Related

- `.planning/ROADMAP.md` § Backlog entry 999.1
- `.planning/phases/999.1-docs-landing-site/README.md`
- `.planning/REQUIREMENTS.md` § Docs & Release (v1.0+)
- `.planning/seeds/SEED-001-operator-feedback-loop.md` (related — post-v1 feedback work; do NOT bundle with docs decision)
