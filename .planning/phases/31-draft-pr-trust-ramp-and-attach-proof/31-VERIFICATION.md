# Phase 31 Verification

Phase 31 closes `TRUST-01`, `TRUST-03`, `GIT-05`, and `UAT-05` with one explicit owning proof path and focused supporting suites.

## Commands Run

- `mix test test/kiln/attach/delivery_test.exs test/kiln/github/push_worker_test.exs test/kiln/github/open_pr_worker_test.exs test/integration/github_delivery_test.exs test/mix/tasks/kiln.attach.prove_test.exs`
- `MIX_ENV=test mix kiln.attach.prove`

## Proof Owner

- `mix kiln.attach.prove`
  - `test/integration/github_delivery_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs`

## What It Proves

- Ready attached repos freeze one deterministic run-scoped branch and reuse it on retry.
- Attached-repo delivery reuses the existing durable push and draft-PR workers with frozen payloads.
- First push of a missing remote attach branch is allowed intentionally through the push worker contract.
- The attach path remains single-repo and draft-PR-first, with no synchronous approval gate added.
- The `/attach` operator surface still distinguishes ready and blocked states honestly.

## Requirement Closure

- `TRUST-01` — complete
- `TRUST-03` — complete
- `GIT-05` — complete
- `UAT-05` — complete
