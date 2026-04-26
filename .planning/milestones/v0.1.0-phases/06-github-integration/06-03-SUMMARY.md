---
phase: 06-github-integration
plan: "03"
subsystem: infra
tags: [oban, github, elixir]

requires: []
provides:
  - PushWorker git_push idempotency
  - OpenPRWorker gh_pr_create
  - CheckPoller gh_check_observe with snooze
affects: []

tech-stack:
  added: []
  patterns:
    - "Kiln.Oban.BaseWorker queue: :github + external_operations two-phase"

key-files:
  created:
    - lib/kiln/github/push_worker.ex
    - lib/kiln/github/open_pr_worker.ex
    - lib/kiln/github/check_poller.ex
    - test/kiln/github/push_worker_test.exs
    - test/kiln/github/open_pr_worker_test.exs
    - test/kiln/github/check_poller_test.exs
  modified:
    - config/test.exs

key-decisions:
  - "CheckPoller uses {:snooze, 15} for pending CI"
  - "Auth errors on gh return {:cancel, atom}"

patterns-established:
  - "Application env :git_runner / :cli_runner hooks for hermetic Oban tests"

requirements-completed: [GIT-01, GIT-02, GIT-03]

duration: 35min
completed: 2026-04-21
---

# Phase 6 Plan 03 Summary

Added three Oban workers on the `:github` queue wrapping `external_operations` for `git_push`, `gh_pr_create`, and `gh_check_observe`.

## Self-Check: PASSED

- `mix test test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs test/kiln/github/check_poller_test.exs` — PASS
