---
phase: 31-draft-pr-trust-ramp-and-attach-proof
plan: "01"
subsystem: attach
tags: [attach, git, github, oban]
requires:
  - phase: 30-attach-workspace-hydration-and-safety-gates
    provides: "Persisted attached-repo facts plus ready-state workspace contract"
provides:
  - "Frozen run-scoped attach branch identity"
  - "Attach delivery orchestration over existing push and draft-PR workers"
  - "Worker coverage for missing remote branch creation and frozen PR attrs"
affects: [attach, github delivery, oban, trust ramp]
completed: 2026-04-24
---

# Phase 31 Plan 01 Summary

Phase 31-01 added `Kiln.Attach.Delivery` as the thin orchestration layer over persisted attached-repo facts. Delivery now freezes one deterministic `kiln/attach/<slug>-r<short_run_id>` branch per run on `runs.github_delivery_snapshot`, reuses that frozen identity across retries, switches the managed workspace to the frozen branch, and produces durable push plus draft-PR payloads for the existing GitHub workers.

The supporting git surface now validates branch names with `git check-ref-format --branch`, can switch or create the local branch safely, and exposes a missing-remote sentinel so `PushWorker` can handle first-push branch creation without treating an absent remote ref as an immediate error. Focused tests cover branch freezing, frozen payload reuse, attached-repo branch creation in `PushWorker`, and frozen draft attrs in `OpenPRWorker`.

Verification for this plan ran through:

- `mix test test/kiln/attach/delivery_test.exs`
- `mix test test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs`

