# Phase 35 Verification

Phase 35 closes `TRUST-04` and `UAT-06` by synchronizing reviewer-visible draft PR handoff copy with the single owning attached proof command.

## Commands Run

- `MIX_ENV=test mix test test/kiln/attach/delivery_test.exs test/integration/github_delivery_test.exs test/mix/tasks/kiln.attach.prove_test.exs`
- `MIX_ENV=test mix kiln.attach.prove`

## Proof Owner

- `mix kiln.attach.prove`
  - `test/integration/github_delivery_test.exs`
  - `test/kiln/attach/delivery_test.exs`
  - `test/kiln/attach/continuity_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln/attach/brownfield_preflight_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs`

## What It Proves

- Draft PR title/body are frozen from durable attached-request facts (`spec_revision`) instead of generic placeholder copy.
- Reviewer-visible body includes scoped summary, acceptance criteria, conditional out-of-scope, explicit verification citations, branch/base context, and one `kiln-run:` footer.
- Visible PR copy omits raw internal identifiers such as `attached_repo_id`.
- The owning proof command remains singular and file-scoped while covering delivery contract, continuity, safety gate, brownfield preflight, and `/attach` truth-surface checks.
- Proof-layer order and rerun stability are locked by `test/mix/tasks/kiln.attach.prove_test.exs`.

## Requirement Closure

- `TRUST-04` — complete
- `UAT-06` — complete
