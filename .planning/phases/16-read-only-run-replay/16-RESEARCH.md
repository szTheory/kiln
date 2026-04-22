# Phase 16 — Technical Research

**Phase:** 16 — Read-only run replay (REPL-01)  
**Question:** What do we need to know to plan **incident-style audit spine replay** without mutating history?

---

## Summary

MVP is **Postgres-backed**, **`audit_events`-only spine** ordered by **`occurred_at ASC, id ASC`** (tie-break documented in `Kiln.Audit.Event` / CONTEXT D-07). **Do not** naive-UNION `work_unit_events` or mutable `stages.updated_at` into the same sorted stream without a dedup contract (CONTEXT D-08–D-10). **Extend** `Kiln.Audit.replay/1` (or add a sibling API) with **keyset** pagination and an explicit **`truncated`** signal so the UI never silently clips (CONTEXT D-11). **LiveView** at **`/runs/:run_id/replay`** with **`at`** query driving **`handle_params/3`** (Phase 7 URL truth). **Terminal runs:** frozen snapshot + optional **Refresh**. **In-flight:** subscribe to existing **`run:#{id}`** and **`work_units:run:#{id}`** topics with **coalesced** refetch + **jump-to-latest** buffer (CONTEXT D-18–D-20). Optional **small** enhancement: broadcast **`{:audit_event, event}`** on `audit:run:#{run_id}` after successful insert when `run_id` is set — enables finer-grained tails without polling; gate behind “if executor needs sub–run_state cadence.”

---

## Ordering & pagination

- **Canonical:** `ORDER BY occurred_at ASC, id ASC` matches UUID v7 monotonicity assumption already in codebase comments.
- **Keyset:** `WHERE (occurred_at, id) > (^cursor_occurred_at, ^cursor_id)` for forward pages; mirror for backward if needed for “Prev window.”
- **LIMIT:** Default **500** today in `Audit.replay/1` — replay UI must surface truncation (banner), not silent clip.

---

## PubSub & live tail

- **`Kiln.Runs.Transitions`** broadcasts `{:run_state, run}` on **`run:#{run.id}`**.
- **`Kiln.WorkUnits.PubSub.broadcast_change/1`** hits **`work_units:run:#{run_id}`**.
- **Audit.insert** today does **not** broadcast — acceptable MVP to refetch on run/work-unit messages only; document **latency** vs full audit stream. **Upgrade path:** `Phoenix.PubSub.broadcast(Kiln.PubSub, "audit:run:#{run_id}", {:audit_event, struct})` post-commit in `insert_event/1` when `run_id` present (read-only subscribers; no new write paths).

---

## Router

- Add **`live "/runs/:run_id/replay", RunReplayLive, :show`** in the same **`live_session :default`**, **above** **`live "/runs/:run_id", RunDetailLive, :show`**`, grouped near **`/runs/compare`** (Phase 15 precedent).

---

## Security / abuse

- **Read-only:** no `cast`/`insert` from replay LiveView.
- **UUID validation:** `Ecto.UUID.cast/1` on path `run_id`; query `at` same.
- **Rate:** range slider must **debounce** / commit-on-release to avoid server storms (UI-SPEC D-13).

---

## Testing strategy

- **Unit:** new `Audit` replay window / keyset helpers — pure DB ordering assertions using factory inserts if present, or SQL sandbox patterns from existing `Kiln.Audit` tests.
- **LiveView:** `Phoenix.LiveViewTest` + **LazyHTML** — stable ids from UI-SPEC; invalid `run_id`, happy path patch `at`, empty list.

---

## Validation Architecture

> Nyquist / execution sampling contract for Phase 16.

### Feedback dimensions

| Dimension | What “sampled” means for REPL-01 |
|-----------|-----------------------------------|
| **D1 Ordering** | Every test that asserts event order uses **explicit** `occurred_at` + `id` tie-break fixtures — never rely on insertion order alone without timestamps. |
| **D2 Truncation** | At least one test or assertion path proves **banner or assign** when `truncated: true`. |
| **D3 Read-only** | Grep/`refute` that `RunReplayLive` contains **no** `Repo.insert`, `Repo.update`, `Transitions.`, or `Audit.append`. |
| **D4 URL truth** | LiveView test uses **`assert_patch`** or URL assertion for **`at`** param changes. |

### Continuous sampling (execute-phase)

- After each task: **`mix test`** scoped to touched test files when they exist; else **`mix compile --warnings-as-errors`**.
- After final wave: **`mix test test/kiln_web/live/run_replay_live_test.exs`** (once file exists) **+** **`mix test test/kiln/audit_test.exs`** (or equivalent audit test path created in plan **02**).
- Full gate: **`mix precommit`** (project alias) before phase sign-off.

### Wave 0

- Existing **ExUnit + LazyHTML** infrastructure covers REPL-01; no new test framework.

### Manual-only (explicit)

- **Visual scrub** timing under human drag — automated test covers **patch** contract only; optional manual check in browser for slider debounce.

---

## RESEARCH COMPLETE
