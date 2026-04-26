---
phase: 09-dogfood-release-v0-1-0
plan: "04"
subsystem: api
tags: [github, dogfood, oban, liveview]

key-files:
  created:
    - dogfood/spec.md
    - priv/dogfood/spec.md
    - lib/kiln/dogfood/template.ex
    - lib/kiln/github/dogfood.ex
    - lib/kiln/workers/dogfood_pr_worker.ex
    - test/kiln/github/dogfood_test.exs
    - test/kiln_web/live/dogfood_template_test.exs
  modified:
    - lib/kiln_web/live/inbox_live.ex
    - config/runtime.exs
---

# Plan 09-04 Summary

- Canonical dogfood markdown: `dogfood/spec.md` + identical `priv/dogfood/spec.md` for `Application.app_dir/2` reads.
- `Kiln.Dogfood.Template.read/0` loads embedded bytes.
- Inbox edit UI: **Load dogfood template** button (`#inbox-load-dogfood-template`).
- `Kiln.GitHub.Dogfood` — allowlist (`lib/kiln/version.ex`, tests, README), branch/label prefixes, `sync_pr/1` stub (live HTTP returns `:dogfood_http_not_configured` without test `sync_fun`).
- `Kiln.Workers.DogfoodPRWorker` — `external_operations` two-phase + Oban unique via `Kiln.Oban.BaseWorker`.
- Secrets: `KILN_DOGFOOD_GITHUB_TOKEN` → `:dogfood_github_token` in `runtime.exs` (values never logged).

## Operator checkpoint (Task 3)

Configure `KILN_DOGFOOD_GITHUB_TOKEN` and optional `KILN_DOGFOOD_REPOSITORY`, then extend `sync_pr/1` with real GitHub REST (PR + label `kiln-dogfood:<hash>` + auto-merge when `mix check` green).

## Self-Check: PASSED

- `mix test test/kiln/github/dogfood_test.exs test/kiln_web/live/dogfood_template_test.exs`
