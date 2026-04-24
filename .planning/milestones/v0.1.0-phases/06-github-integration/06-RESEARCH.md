# Phase 6 — GitHub Integration — Technical Research

**Phase:** 06 — GitHub Integration  
**Question:** What do we need to know to PLAN this phase well?  
**Date:** 2026-04-21

---

## Summary

Phase 6 closes the **git + GitHub** loop using **shell-first** integration (`System.cmd("git", …)`, `System.cmd("gh", …)`) behind **`external_operations`** (D-18), **Oban** on the existing `:github` queue, and **`Kiln.Runs.Transitions`** for `verifying → merged | planning | blocked`. No webhooks in v1; **REST/checks polling** via `gh api` (or equivalent) matches `06-CONTEXT.md` D-G09–D-G12. **Required checks on PR head SHA** (D-G01) is the merge bar; **draft PRs** do not satisfy merge predicate by default (D-G04).

---

## Idempotency & Two-Phase Pattern

- **Authoritative dedupe:** `external_operations.idempotency_key` UNIQUE + `fetch_or_record_intent/2` → action → `complete_op/2` / `fail_op/2` (see `lib/kiln/external_operations.ex`, `docker_driver.ex` reference).
- **Keys (align with 02-CONTEXT):** e.g. `"run:#{run_id}:stage:#{stage_id}:git_push"`, `"run:#{run_id}:stage:#{stage_id}:gh_pr_create"`, `"run:#{run_id}:pr:#{pr_number}:gh_check_observe"` — exact spelling fixed in PLAN tasks.
- **Never use Oban `max_attempts` as CI-wait loop** (D-G10, D-G19): poll scheduling = `schedule_in` / self-reschedule with DB-backed attempt counters for integration retries only.

---

## Git Semantics (GIT-01)

- **Pre-push:** `git ls-remote origin <ref>` captures remote tip; CAS in intent `intent_payload` (`expected_remote_sha`, `local_commit_sha`); if remote already at desired commit → **no-op complete** (D-G16).
- **Non-FF:** default **fail_fast** with typed atoms `:git_non_fast_forward`, `:git_remote_advanced`, `:git_push_rejected` (D-G17); optional workflow `git.integration_strategy: :rebase_with_retry` is **explicit opt-in** (D-G18).
- **Identity / messages:** D-G13–D-G15 — stable bot identity, Conventional Commits + `X-Kiln-*` trailers, unsigned v1.

---

## GitHub CLI & Checks (GIT-02 / GIT-03)

- **`gh pr create`:** JSON output (`--json number,url,…`) for stable idempotency storage in `result_payload`; **draft default true** (D-G05–D-G06).
- **Checks:** `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` (and/or combined status) — map to **required** set vs **optional** per D-G01–D-G03; persist **check_run id + conclusion + name** in audit-friendly payload.
- **Auth errors:** map stderr / exit codes to **`:gh_auth_expired`** and **`:gh_permissions_insufficient`** with playbooks `priv/playbooks/v1/gh_auth_expired.md`, `gh_permissions_insufficient.md` (BLOCK-01).

---

## Integration Points

- **`Kiln.Runs.Transitions`:** `verifying` → `merged` when merge predicate true; → `planning` with verifier-style diagnostic when CI fails (reuse `meta[:reason]` atom discipline from `transitions.ex`).
- **`Kiln.Audit.EventKind`:** `:git_op_completed`, `:pr_created`, `:ci_status_observed`, `:block_raised` already in taxonomy — wire JSV schemas under `priv/audit_schemas/v1/` if payloads extend.
- **`Kiln.GitHub`:** replace placeholder `lib/kiln/github.ex` with real boundary module(s) under `lib/kiln/github/` (keep `Kiln.GitHub` namespace for `check_bounded_contexts`).

---

## GIT-03 vs LiveView

**REQUIREMENTS.md** mentions run-board surfacing for GIT-03; **ROADMAP Phase 6** scopes **checks API + verifier drive**. Resolution: Phase 6 **persists** a `github_delivery_snapshot` (or equivalent) on `runs` for Phase 7 to render; optional thin **PubSub** broadcast on snapshot update — no LiveView in Phase 6.

---

## Validation Architecture

**Dimension 8 — feedback sampling**

| Layer | Approach |
|-------|----------|
| **Unit** | Pure functions: merge predicate from fixture JSON; stderr classifier; idempotency key builders |
| **Module** | `Mox` or stub `cmd/3` callback for `Kiln.Git` / `Kiln.GitHub` without real network |
| **Integration** | Single test: simulate `ExternalOperations` row completed + worker idempotency short-circuit; optional `tag :github_integration` gated on `KILN_TEST_GITHUB=1` |
| **CI default** | All tests hermetic — no `gh auth` required in GHA |

**Nyquist sampling**

- After each task merge: `mix test` scoped to touched test paths (see `06-VALIDATION.md`).
- After each wave: `mix test test/kiln/git/ test/kiln/github/ test/integration/github_delivery_test.exs` (paths TBD in execution).
- **Before verify-work:** `mix check` green.

**Manual-only (documented)**

- Real `gh pr create` against a test repo — operator dogfood; not CI-gated in v1.

---

## RESEARCH COMPLETE

Findings consolidated with `06-CONTEXT.md` (D-G01–D-G22). Proceed to PLAN authoring with pattern map and validation matrix.
