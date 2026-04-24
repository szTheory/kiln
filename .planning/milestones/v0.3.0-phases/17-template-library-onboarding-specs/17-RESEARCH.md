# Phase 17 — Technical research

**Phase:** Template library & onboarding specs (WFE-01, ONB-01)  
**Date:** 2026-04-22  
**Question answered:** What do we need to know to plan this phase well?

## Executive summary

Ship **manifest-indexed** template packs under `priv/templates/<id>/` (spec + workflow pairs), load paths **only** via `Application.app_dir(:kiln, …)`, validate **allow-listed** `template_id` values (no path traversal), and wire **`/templates`** LiveView for browse → preview → instantiate. **Instantiate** must land on **promoted** specs per Phase 8 (`Kiln.Specs.promote_draft/1` transaction + `:spec_draft_promoted` audit is the existing pattern; CONTEXT allows direct insert + new audit kind if cheaper). **Replace** inbox-only `load_dogfood_template` with template-ID-driven flows (D-1716). Reuse **`Kiln.Workflows`** YAML + JSV pipeline for CI verification of every manifest entry (D-1704). **Ecto** migrations are the schema mechanism here — no Prisma/Drizzle schema-push injection applies.

## Codebase anchors

| Concern | Location |
|--------|----------|
| Release-safe `priv` read | `lib/kiln/dogfood/template.ex` — `Application.app_dir(:kiln, "priv/dogfood/spec.md")` |
| Draft → promoted spec | `lib/kiln/specs.ex` — `create_draft/1`, `promote_draft/1`, `Audit.append(:spec_draft_promoted, …)` |
| Dogfood affordance to replace | `lib/kiln_web/live/inbox_live.ex` — `handle_event("load_dogfood_template", …)`, button `id="inbox-load-dogfood-template"` |
| Router / live_session | `lib/kiln_web/router.ex` — add `live "/templates", …` and optional `live "/templates/:template_id", …` inside `:default` session |
| Workflow validation | `Kiln.Workflows` (existing loader + JSV) — invoke from `mix templates.verify` and/or ExUnit |

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Path traversal via `template_id` | Resolve IDs **only** from parsed manifest; never `Path.join` user string to `priv/` |
| Unpromoted spec attached to run | Instantiate path **always** promotes (or inserts audited promoted revision) before enqueue |
| False-precision cost/time copy | Bands + disclaimers (D-1719–D-1723); align with `prompts/kiln-brand-book.md` |
| Manifest / disk drift | Single `mix templates.verify` (or dedicated test module) enumerates manifest entries |

## Open choices (planner resolves)

- Manifest **JSON vs YAML** (CONTEXT: pick one).
- **Ephemeral draft + immediate `promote_draft`** vs **direct Spec + new audit event** for “Use template”.
- **`mix templates.verify`** as `Mix.Task` vs ExUnit-only (D-1704 satisfied either way if CI runs it).

## Validation Architecture

Nyquist-style feedback for Phase 17:

| Dimension | Signal | Tooling |
|-----------|--------|---------|
| 1 — Correctness | Manifest entries parse; workflows JSV-validate; specs UTF-8 | `mix templates.verify` (or equivalent ExUnit) + `mix test` on new LiveView modules |
| 2 — Regression | Existing inbox / promote / run flows unchanged for non-template paths | Targeted tests on `InboxLive`, `Specs` |
| 3 — Security | No traversal; CSRF on mutate events; template_id allow-list | Sobelow + manual grep for `Path.join` on user input; LiveView tests for rejected unknown IDs |
| 4 — UX / IA | `/templates` reachable; onboarding CTA; microcopy | LiveView tests (`has_element?/2`) per `AGENTS.md` |
| 5 — Performance | Catalog load reads manifest once (or cached ETS optional — not required v1) | Light assertion on function called in test if needed |
| 6 — Ops | `Application.app_dir` works in release | CI `MIX_ENV=test` already exercises app_dir patterns via dogfood |
| 7 — Audit | Template instantiate emits identifiable audit payload | Integration test or assert on `Audit.append` kind |
| 8 — Requirements trace | WFE-01 + ONB-01 | ≥3 templates in tree; REQ strings in plan frontmatter |

**Wave 0:** No new test framework — ExUnit + existing `mix precommit` / `mix check` conventions.

**Sampling:** After each plan wave touching `priv/templates` or LiveView — `mix test` scoped paths; full `mix precommit` before phase close.

---

## RESEARCH COMPLETE
