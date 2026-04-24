# Phase 24: template-run-uat-smoke - Patterns

**Mapped:** 2026-04-23
**Scope:** Existing Phoenix LiveView regression patterns for the `/templates` -> `/runs/:id` operator path

## Relevant files

| File | Role | Phase 24 relevance |
|------|------|--------------------|
| `lib/kiln_web/live/templates_live.ex` | Source LiveView | Owns the template detail controls, success panel, and start-run navigation |
| `lib/kiln_web/live/run_detail_live.ex` | Destination LiveView | Already exposes `#run-detail` as the stable terminal shell |
| `lib/kiln_web/plugs/onboarding_gate.ex` | Browser pipeline gate | Redirects `/templates` traffic to `/onboarding` until readiness is satisfied |
| `test/kiln_web/live/templates_live_test.exs` | Owning LiveView regression file | Natural place to strengthen template -> run proof |
| `test/kiln_web/live/run_detail_live_test.exs` | Destination shell assertion analog | Shows the shallow `#run-detail` proof style already used in repo |
| `.planning/phases/22-merge-authority-operator-docs/22-VERIFICATION.md` | Verification artifact analog | Shows the house style for exact command citation and scoped claims |

## Reusable patterns

### Pattern 1: Id-first LiveView happy path

- Mount routed LiveViews with `live(conn, path)`.
- Drive operator actions with `form("#...") |> render_submit()`.
- Prefer `has_element?/2` over raw HTML assertions for state boundaries.
- Keep text assertions secondary.

### Pattern 2: Follow routed navigation, then prove the destination shell

- `TemplatesLive` uses `push_navigate/2` on successful run start.
- Current tests already capture the redirect tuple.
- Phase 24 should extend that proof with `follow_redirect/3` and `assert has_element?(run_view, "#run-detail")`.

### Pattern 3: Respect browser-pipeline readiness gates in tests

- `/templates` is behind `KilnWeb.Plugs.OnboardingGate`.
- Any Phase 24 LiveView regression must satisfy `Kiln.OperatorReadiness.ready?/0` before mounting the page.
- This belongs in test setup, not in product code or a new harness.

## Selector contract to preserve

- `#template-card-<template_id>`
- `#template-use-form-<template_id>`
- `#template-edit-first-form-<template_id>`
- `#templates-success-panel`
- `#templates-start-run-form`
- `#templates-start-run`
- `#run-detail`

## Ownership boundary

- Prefer changes in `test/kiln_web/live/templates_live_test.exs`.
- Touch `lib/kiln_web/live/templates_live.ex` only if a genuinely missing state-boundary id is discovered.
- Do not add browser-E2E ownership for this slice.
- Do not deepen assertions into run internals already covered below the UI layer.
