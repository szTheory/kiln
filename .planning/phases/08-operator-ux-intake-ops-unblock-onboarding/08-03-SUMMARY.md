---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "03"
subsystem: ui
tags: [liveview, intake, specs, streams]

requires:
  - phase: 08
    provides: SpecDraft model, GitHubIssueImporter, Specs draft APIs
provides:
  - /inbox triage UI with streams and imports
affects: [operator-ux]

tech-stack:
  added: []
  patterns: [LiveView uploads for markdown; Application env :inbox_github_import_opts for Req.Test in CI]

key-files:
  created:
    - lib/kiln_web/live/inbox_live.ex
    - test/kiln_web/live/inbox_live_test.exs
  modified:
    - lib/kiln/specs.ex
    - lib/kiln_web/router.ex
    - lib/kiln_web/components/layouts.ex

key-decisions:
  - "GitHub import merges opts from Application.get_env(:kiln, :inbox_github_import_opts, []) so tests can inject Req.Test plugs without live tokens."

patterns-established:
  - "Every handle_event starts with unless allow?/1 guard (solo v1 stub true)."

requirements-completed: [INTAKE-01, INTAKE-02]

duration: 35min
completed: 2026-04-21
---

# Phase 08 — Plan 03 Summary

**Operators can triage inbox drafts at `/inbox` with promote/archive/edit, freeform create, markdown upload, and GitHub import.**

## Self-Check: PASSED

- `mix test test/kiln_web/live/inbox_live_test.exs` — green

## Deviations

- Added `Specs.update_open_draft/2` (not listed in plan `files_modified`) to persist Edit without leaking Repo into the LiveView.
