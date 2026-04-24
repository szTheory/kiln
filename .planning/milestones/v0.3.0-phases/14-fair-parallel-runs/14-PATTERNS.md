# Phase 14 — Pattern map (PATTERNS.md)

Analogs and copy-ready anchors for PARA-01 implementation.

---

## 1. Transactional transition + audit (do not bypass)

**Analog:** `lib/kiln/runs/transitions.ex` — `Repo.transact`, `lock_run/1`, `transition_ok/4`, `append_audit/4`.

**Rule:** Any new “admission” or scheduling side effect that mutates run rows or audit **must** stay inside the **existing** `Transitions` transaction boundaries — **never** hold locks across HTTP/Docker/LLM.

---

## 2. Singleton GenServer state extension

**Analog:** `lib/kiln/runs/run_director.ex` — `init/1` → `:boot_scan`, `handle_info(:periodic_scan, _)`, `%{monitors: %{pid => {ref, run_id}}}`.

**Pattern:** Add a **serializable** field to director state, e.g. `fair_cursor: String.t() | nil`, updated **only** after a successful subtree spawn decision path. **No** selective receive.

---

## 3. Telemetry execute + attach

**Analog:** `lib/kiln/telemetry.ex` (`pack_meta/0`), `Kiln.Telemetry.ObanHandler` pattern for Oban job lifecycle.

**Pattern:** `:telemetry.execute([:kiln, :subsystem, :event, :stop], %{duration: n}, %{run_id: ..., ...})` with **string** metadata keys where JSON/logging parity matters; **attach** in `Application.start/2` or existing Kiln telemetry boot.

---

## 4. Oban job meta for operators

**Analog:** `lib/kiln/stages/next_stage_dispatcher.ex` — `StageWorker.new(..., meta: Telemetry.pack_meta())`.

**Extension:** Merge **`%{"run_id" => run_id}`** (string key) into `meta` at enqueue time so logs / Oban Web / JSONL pipelines can filter **without** parsing nested `kiln_ctx` — complements D-46 logger metadata.

---

## 5. Active-run listing query

**Analog:** `lib/kiln/runs.ex` — `list_active/0` with `order_by: [asc: r.inserted_at]`.

**Pattern:** Keep **DB query** cheap; apply **fair permutation** in memory in `RunDirector` on the **small** active set (bounded by `RunSupervisor` + ops reality), not via expensive SQL `ORDER BY` expressions.

---

## PATTERN MAPPING COMPLETE
