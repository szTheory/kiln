---
phase: 08-operator-ux-intake-ops-unblock-onboarding
plan: "02"
subsystem: api
tags: [req, github, intake]

requires:
  - plan: "01"
    provides: spec_drafts + create_draft/1

provides:
  - Kiln.Specs.GitHubIssueImporter with slug/url parsing and Req-based fetch
  - Delegates on Kiln.Specs for import + refresh
  - Req.Test unit tests including If-None-Match / etag refresh path

key-files:
  created:
    - lib/kiln/specs/github_issue_importer.ex
    - test/kiln/specs/github_issue_importer_test.exs
  modified:
    - lib/kiln/specs.ex

requirements-completed: [INTAKE-01]

completed: 2026-04-21
---

# Phase 8 Plan 08-02 Summary

**GitHub issue references resolve to validated API paths and upsert into open inbox rows, with a tested `If-None-Match` refresh path.**

## Self-Check: PASSED

- `mix test test/kiln/specs/github_issue_importer_test.exs`
