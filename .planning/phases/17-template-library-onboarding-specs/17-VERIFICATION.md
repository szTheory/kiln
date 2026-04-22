---
status: passed
phase: 17-template-library-onboarding-specs
updated: 2026-04-22
---

# Phase 17 — Verification

## Automated

| Check | Result |
|-------|--------|
| `mix templates.verify` | PASS |
| `mix test test/kiln/templates_manifest_test.exs` | PASS |
| `mix test test/kiln/specs/template_instantiate_test.exs test/kiln/specs/spec_draft_test.exs` | PASS |
| `mix test test/kiln_web/live/templates_live_test.exs` | PASS |
| `mix compile --warnings-as-errors` | PASS |

## Must-haves (from plans)

- [x] Manifest sole authority + `Kiln.Templates` allow-list (17-01)
- [x] `instantiate_template_promoted/1` + audited `template_id` + run create API (17-02)
- [x] `/templates` routes in default `live_session`; inbox dogfood control removed; onboarding CTA (17-03)
- [x] Unknown template param surfaces **This template is not available.** (LiveView redirect)

## Human verification

None required for this phase — operator flows covered by LiveView + context tests.

## Self-Check: PASSED
