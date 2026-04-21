---
status: issues
phase: "04"
phase_name: agent-tree-shared-memory
reviewed_at: 2026-04-21
depth: standard
files_reviewed: 39
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
scope_note: "File list from 04-01..04-04 *-SUMMARY.md key-files (gsd-sdk unavailable in review environment; commit step not run)."
---

# Phase 04 — Code review

## Summary

Phase 04 delivers the work-unit Postgres floor, transactional `Kiln.WorkUnits` API with post-commit PubSub, per-run session supervision with seven role workers, and integration coverage. Immutability for `work_unit_events` mirrors the D-12 pattern (REVOKE + trigger + RULE). No **critical** security defects surfaced in scoped files; the main gaps are **API/state-machine strictness**, **export fidelity**, and **operability** (silent error swallowing / global PubSub semantics).

---

### WR-01 — `complete_and_handoff/3` does not guard source state

**Severity:** Warning  
**Where:** `lib/kiln/work_units.ex` (`complete_and_handoff/3`)

The function locks the row and checks `agent_role == role`, then transitions to `:completed` and `:closed` without requiring `state == :in_progress` (or another expected pre-state). A buggy or malicious caller could append `:completed`/`:closed` ledger events from `:open` or `:blocked`, weakening the coordination invariant.

**Recommendation:** Assert `wu.state == :in_progress` (and optionally `wu.claimed_by_role == role`) before updates, or push valid transitions into a dedicated command/changeset layer.

---

### WR-02 — `JsonlAdapter` export omits event payloads (and unit payloads)

**Severity:** Warning  
**Where:** `lib/kiln/work_units/jsonl_adapter.ex`

`encode_events/1` serializes only identifiers, kind, actor, and timestamps — not `payload`. `encode_unit/1` also omits `input_payload` / `result_payload` / `external_ref`. For anything marketed as a forensic or federation snapshot, the export is incomplete relative to the DB.

**Recommendation:** Include `payload` (and decide redaction policy for secrets), or rename/document as a **summary** export only.

---

### WR-03 — Mayor swallows planner seed failures

**Severity:** Warning  
**Where:** `lib/kiln/agents/role.ex` (`maybe_seed_planner/1`)

`WorkUnits.seed_initial_planner_unit/1` errors become `{:error, _} -> :ok` with no log or `:telemetry` event. Persistent DB or constraint failures can leave a run without a seeded planner while appearing healthy.

**Recommendation:** Log at `:error` or emit telemetry on `{:error, reason}`, and consider whether `:mayor` should crash or enter a degraded state on hard failures.

---

### WR-04 — Global PubSub topic fans out all runs

**Severity:** Warning (multi-tenant / future); Info (strict single-tenant v1)  
**Where:** `lib/kiln/work_units/pubsub.ex`

`broadcast_change/1` always publishes to the global `"work_units"` topic as well as per-unit and per-run topics. Any process subscribed globally receives events for **every** run; payloads include `run_id` but consumers must self-filter.

**Recommendation:** Document the contract (who may subscribe globally), or drop the global fan-out if unused; for future SaaS, treat this as a data-exposure footgun.

---

### IN-01 — Steady poll load from role workers

**Severity:** Info  
**Where:** `lib/kiln/agents/role.ex` (`@poll_interval_ms 100`, seven roles per run)

Each role ticks every 100ms and may call `claim_next_ready/2`, producing a baseline query rate per active run even when idle.

**Recommendation:** Back off when `:none_ready` repeatedly, jitter, or event-only wakeups once the system is stable.

---

### IN-02 — `close_work_unit/2` is a sharp generic transition

**Severity:** Info  
**Where:** `lib/kiln/work_units.ex` (`close_work_unit/2`)

Any matching role can close a unit from (almost) any state if the row exists and locks — useful for abort paths but easy to misuse from higher layers without explicit policy.

**Recommendation:** If not intentional, narrow with state guards or a dedicated `:cancel`/`:fail` path with explicit audit semantics.

---

## Files in scope

39 paths from plan summaries `04-01` … `04-04` (`key-files.created` / `key-files.modified`), excluding planning artifacts per workflow D-03.

---

## Tooling note

`gsd-sdk query init.phase-op` / `gsd-sdk query commit` were not executable in this environment (`asdf`: no `gsd-sdk` version). Phase directory resolved to `.planning/phases/04-agent-tree-shared-memory/`. Install/configure `gsd-sdk` to automate commits and re-run `/gsd-code-review 04` for parity with the full workflow.
