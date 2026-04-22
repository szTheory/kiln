# Phase 14 — Fair parallel runs — Technical research

**Status:** Ready for planning  
**Date:** 2026-04-22  
**Question answered:** What do we need to know to *plan* PARA-01 well?

---

## 1. Problem framing (PARA-01)

**Requirement (REQUIREMENTS.md):** PARA-01 — multiple concurrent runs with **fair-share scheduling** so no single run starves others under load; **ORCH-06** (caps / halt) and **ORCH-07** (idempotency, Oban uniqueness, `external_operations`) stay authoritative.

**Two distinct “queues” (CONTEXT D-11..D-12):**

| Signal | Meaning | Primary consumer |
|--------|---------|-------------------|
| **Run queued dwell** | Wall-clock (or monotonic) time a run spends in `:queued` before first transition out | Product fairness / PARA-01 CI |
| **Oban `queue_time`** | Time job waited in Oban’s internal queue | Infra saturation |
| **Ecto pool queue** | Connection checkout wait | DB pressure |

Mixing these in operator copy causes wrong tuning (Celery prefetch / k8s scheduler lesson from CONTEXT).

---

## 2. Current implementation anchors

### 2.1 Run lifecycle

- **`Kiln.Runs.RunDirector.start_run/1`** — after readiness + provider key checks, calls **`Kiln.Runs.Transitions.transition(run.id, :planning)`** (only production callsite in `lib/` today for `queued → :planning`).
- **`Kiln.Runs.Transitions.transition/3`** — single sanctioned path: `Repo.transact`, `FOR UPDATE` on run, matrix guard, caps / stuck hooks, `update_state`, paired **`Audit.Event`**, PubSub after commit.
- **`Kiln.Runs.list_active/0`** — `WHERE state IN active` **`ORDER BY inserted_at ASC`** — drives boot / periodic **subtree spawn** order (FIFO by creation).

### 2.2 Stage execution

- **`Kiln.Stages.NextStageDispatcher.enqueue_next!/2`** — inserts **`Kiln.Stages.StageWorker`** jobs on **`:stages`** queue with args `run_id`, `idempotency_key`, etc., and **`meta: Kiln.Telemetry.pack_meta()`** (logger ctx, not a dedicated top-level `run_id` meta key).
- **`config :kiln, Oban, queues:`** — `default: 2, stages: 4, github: 2, audit_async: 4, dtu: 2, maintenance: 2` → **aggregate 16** workers, aligned with **BootChecks** `oban_queue_budget` vs **Repo pool_size** (see `lib/kiln/boot_checks.ex`).

### 2.3 Fairness gap (v1 diagnosis)

1. **Admission:** If multiple runs are `:queued` and something repeatedly promotes “favorite” runs, others can starve. Today **`start_run/1` is explicit per `run_id`** — fairness policy must clarify **orchestrator-of-record** when multiple starts compete (tests will drive N runs).
2. **Executor interleaving:** Oban **Basic** engine is **FIFO on available jobs** — if one run enqueues bursts faster, another run’s `:stages` jobs can wait disproportionately. Mitigations: **per-run in-flight caps** (future), **enqueue discipline** (round-robin scheduling at producer), or **documented** limitation for v1 + telemetry to prove where wait accumulates.
3. **Subtree spawn:** `RunDirector.do_scan/1` walks **`Runs.list_active()`** order — purely **`inserted_at` ASC**. For “equal chance to attach supervisor when capacity-constrained (`RunSupervisor` max_children)”, a **stable RR rotation** of the *scan batch* (CONTEXT D-01 tie-break: `inserted_at`, then `run_id` lexicographic) matches locked decisions.

---

## 3. Recommended architecture (aligns with 14-CONTEXT.md)

### 3.1 Policy module (pure + unit-tested)

- New module under **`Kiln.Runs.*`** (exact name planner discretion — e.g. `FairRoundRobin` / `Scheduling`) exposing **pure** functions:
  - **`order_runs/2`** — input: enumerable of `%Run{}` (or `{id, inserted_at}`), optional **cursor** (`last_served_run_id | nil`); output: **permutation** sorted per **D-01** (RR with stable tie-break).
  - **No** selective receive, **no** fairness in `Registry` itself (D-06).

### 3.2 Choke points (D-04 / D-05)

| Concern | Choke point | Note |
|---------|--------------|------|
| Subtree spawn order | **`RunDirector.do_scan/1`** after `Runs.list_active()` | Apply `order_runs/2` before `Enum.reduce` spawn loop; persist cursor in **RunDirector state** (already a GenServer). |
| `queued → planning` | **`RunDirector.start_run/1`** (and any future batch starter) | Short-circuit **before** transition if caps/blockers fail (existing); **optional v1:** if multiple queued runs compete for **`RunSupervisor` capacity**, use same ordering helper to decide **defer vs error** — only if `max_children` errors exist today (see `RunSupervisor` / logs). |

### 3.3 Telemetry (D-11)

- **Event:** `[:kiln, :run, :scheduling, :queued, :stop]` (measurement `:telemetry.execute/3` with **`%{duration: native}`** or integer milliseconds — **document** unit in `@moduledoc` + README).
- **Emit once** on **successful** transition **out of** `:queued` (inside `Transitions` after commit succeeds, or immediately after `Repo.transact` returns `{:ok, _}` — **avoid double emit**).
- **Metadata:** `run_id`, `next_state` (string), optional `correlation_id` — **never** high-cardinality labels on Prometheus summaries; **do not** add `run_id` to `Telemetry.Metrics` reporter labels in `KilnWeb.Telemetry` (D-11).
- **Attach** handler in **`Kiln.Telemetry`** or existing attach site (`lib/kiln/application.ex` / `Kiln.Telemetry` pattern) for consistency with **ObanHandler** style.

### 3.4 ORCH-06 / ORCH-07 precedence (D-07)

Fairness code **must not** run before cap / block checks that already live on **`transition/3`**. If transition is denied, **no** “queued dwell stop” event (run never left queued).

---

## 4. Verification strategy (executor-facing)

- **Unit:** ordering function — fixed list of runs, known cursor → deterministic permutation (property or table-driven).
- **Integration (`async: false` per D-14):** N runs created `:queued`, attach **`:telemetry` handler** counting **`[:kiln, :run, :scheduling, :queued, :stop]`** emissions and **max dwell**; drive **`RunDirector.start_run/1`** (or batch API if introduced) **without `Process.sleep`** — use **`Oban.drain_queue/1`**, **`Ecto.Adapters.SQL.Sandbox.allow/3`**, or **`_ = :sys.get_state(RunDirector)`** as needed for synchronization.
- **Grep CI:** event name string present in `lib/kiln/runs/transitions.ex` (or dedicated telemetry module); README section **“Fair scheduling in Kiln”** lists event name + semantics.

---

## 5. Risks / non-goals

- **Weighted fair-share, cross-node global fairness, LiveView charts** — deferred per CONTEXT `<deferred>`.
- **Changing Oban engine** — out of scope; prefer **:telemetry** + documented Oban `queue_time` for infra.

---

## Validation Architecture

> Nyquist / Dimension 8 — sampling contract for execution agents.

**Primary automated signals**

1. **`mix test test/kiln/runs/fair_ordering_test.exs`** (or final module path) — deterministic ordering.
2. **`mix test test/kiln/runs/run_scheduling_telemetry_test.exs`** — handler receives `[:kiln, :run, :scheduling, :queued, :stop]` with `run_id` in metadata.
3. **`mix test test/kiln/runs/run_parallel_fairness_test.exs`** (integration module name planner discretion) — `async: false`, N small (3–5), asserts dwell bounds + no permanent starvation pattern under harness.

**Sampling policy**

- After each task touching **`Transitions` / `RunDirector` / telemetry attach:** run the **narrowest** test file above (`--max-failures 1`).
- Before phase sign-off:** `mix check`** (full gate).

**Wave 0**

- No new Hex deps. Reuse **`:telemetry`**, **ExUnit**, existing **`Kiln.DataCase` / `RehydrationCase`** patterns where rehydration is involved.

---

## RESEARCH COMPLETE

Next: `/gsd-execute-phase 14` after PLAN.md files are written and plan-checker passes.
