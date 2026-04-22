# Phase 14: Fair parallel runs - Context

**Gathered:** 2026-04-22  
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver **PARA-01**: multiple concurrent runs make forward progress under load **without starvation**, while **ORCH-06** (bounded autonomy / caps / halt semantics) and **ORCH-07** (idempotency, intent rows, Oban uniqueness) remain authoritative. Observable success: **no run stays `queued` forever** while others advance only because of unfair ordering, and **telemetry** exposes **per-run scheduling wait** so regressions are visible in CI or integration tests.

Out of scope: run comparison UI (Phase 15), replay (16), templates (17), cost alerts (18), post-mortems (19).

</domain>

<decisions>
## Implementation Decisions

### Fairness definition (v1)

- **D-01 — Fair-share = equal-share scheduling at published grain:** Among runs **eligible** for the same scarce **Kiln-scheduled** unit (see D-05), use **round-robin** with a **stable tie-break** (`inserted_at` ascending, then `run_id` lexicographic) so ordering is **reproducible** in tests and **least surprise** in ops. This matches FIFO-by-creation for a **single** contended resource only when RR degenerates to that ordering; once multiple runs compete for **forward progress** while `queued` or for **stage worker slots**, RR is the explicit policy, not “whatever `Repo.all` returned.”
- **D-02 — Defer weighted fair-share (WFQ):** No tenant weights or cost-based weights in v1. Revisit when a real **weight source** exists (product tiers, credits); until then equal weights = RR anyway.
- **D-03 — Optional aging only if proven:** If integration tests show **head-of-line** pathology under realistic workloads, add a **single** aging rule (e.g. boost runs whose **scheduling wait** exceeds threshold **T**) documented in operator-facing copy. Do not ship implicit priority without metrics.

### Enforcement architecture (OTP / Oban / Postgres)

- **D-04 — Split enforcement (Kubernetes-style lesson):** **Admission / run-level** policy decides **which runs may consume the next unit of forward progress** (especially escaping `queued` and/or being **eligible** for saturated stage execution). **Oban** remains the **durable executor** with **per-queue isolation** (`:stages`, `:github`, `:dtu`, `:audit_async`, etc.) and the existing **aggregate worker budget** aligned with the **Repo pool** (see BootChecks / D-68 pattern). **One scheduling key** end-to-end: `run_id` on jobs and transitions.
- **D-05 — Do not duplicate incompatible masters:** Policy lives in **one module** (pure functions + tests) invoked from the **smallest set of choke points** (transitions that leave `queued`, and/or a thin scheduler next to `RunDirector` — planner picks concrete module names). Oban config uses **args/meta** so **per-run** fairness is **observable** and **testable**, not “mailbox order of a GenServer.”
- **D-06 — Idiomatic OTP:** **No selective receive** for scheduling. **DynamicSupervisor.max_children** (if used) is a **capacity** bound, not fairness. **Registry** maps `run_id` → pid for coordination only; **not** the fairness algorithm.
- **D-07 — ORCH-06 / ORCH-07 trump fairness:** Caps, blocks, idempotency keys, and `external_operations` semantics **short-circuit** scheduling — fairness never bypasses halt, budget exhaustion, or insert-time uniqueness.

### Bottleneck hierarchy (what “load” means)

- **D-08 — Layered caps, one story for the operator:** Treat fairness as a **small number of intentional layers**, not a single magic throttle:
  1. **Stability envelope (non-negotiable):** Oban aggregate concurrency + Ecto pool behavior stay consistent (existing `queues:` sum + BootChecks pattern — **verify** current ceiling in `lib/kiln/boot_checks.ex` when implementing).
  2. **Run-level product fairness:** Prevent one run from **monopolizing** shared `:stages` (and related) capacity — use **per-run tags/keys** in Oban jobs + the RR admission policy so **N concurrent runs** each get **forward progress**.
  3. **Isolation (already aligned):** `:github`, `:dtu`, `:audit_async` remain **separate blast radii** (Sidekiq/BullMQ lesson: multi-queue for isolation, not one global mush).
- **D-09 — Provider / Docker / GitHub are orthogonal:** Rate limits (429), sandbox host limits, and GitHub secondary limits get **separate** backoff and caps where needed; **do not** conflate “fair HTTP” with “fair runs.” Instrument **per-layer wait** (D-10..D-12) so the next tuning knob is **evidence-based** (Celery-prefetch / k8s requests-limits lesson: wrong layer = wrong fixes).
- **D-10 — DB transactions:** Never hold **row locks** (`FOR UPDATE`) across LLM, Docker, or HTTP — short transactions only (double-counting and deadlock footgun).

### Telemetry (CI + operator clarity)

- **D-11 — Primary PARA-01 signal = run-level queue dwell:** Emit `[:kiln, :run, :scheduling, :queued, :stop]` on transition **out of** `queued` (measurement `duration` in **documented** time base, prefer **monotonic** for dwell). Metadata: `run_id`, `next_state` (+ existing correlation patterns via `Kiln.Telemetry` — do not put secrets or full job args in metadata). **Do not** use `run_id` as a **Prometheus metric label** (cardinality); event/span/log field is fine.
- **D-12 — Secondary / breakdown signals (same phase if cheap):** Keep Oban’s built-in `[:oban, :job, :stop|exception]` `queue_time` for **infrastructure** queue wait; keep Ecto pool queue metrics separate. **Naming in docs:** `run_queued` vs `oban_queue` vs `db_pool_queue` so operators never confuse them.
- **D-13 — OpenTelemetry:** Continue `OpentelemetryOban.setup()` for **trace linkage**; domain dwell remains **:telemetry**-first for stable ExUnit attachment (defer OTel-as-primary-metric-store if immature).

### Verification & DX

- **D-14 — Golden test:** One **`async: false`** integration-style module (if Oban + shared sandbox + singletons require it) that starts **N** runs (fixed small **N**), attaches a `:telemetry` handler for `[:kiln, :run, :scheduling, :queued, :stop]`, drives contention **deterministically** (no `Process.sleep`), and asserts **max dwell** or **all dwells** below a generous ceiling — plus optional Oban `queue_time` ceiling for a known worker/queue.
- **D-15 — Anti-patterns:** No N-repeat loops as the only fence; no proving fairness via log grep; no property tests that boot the full app per case; use `Sandbox.allow/3` wherever supervised code hits `Repo`.
- **D-16 — Operator doc snippet:** One short section in README or ops doc: **what “fair” means in Kiln** (grain, tie-break, layers, metrics to watch, “stuck but fair” vs bug).

### Claude's Discretion

- Exact module names for the **scheduler** vs extending **`Kiln.Runs.Transitions`** only.
- Whether `[:kiln, :run, :scheduling, :queued, :start]` pair is needed vs DB timestamps for dwell (prefer **single emission point** to avoid double count).
- Whether `list_active/0` ordering (`inserted_at` asc) remains sufficient for **rehydration-only** paths once admission fairness exists (likely yes for **spawn**, separate for **queued → planning**).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap

- `.planning/REQUIREMENTS.md` — PARA-01, ORCH-06, ORCH-07
- `.planning/ROADMAP.md` — Phase 14 goal and success criteria
- `.planning/PROJECT.md` — Postgres SoT, bounded autonomy, idempotency principles

### Current implementation anchors

- `lib/kiln/runs/run_director.ex` — boot/periodic scan, subtree spawn, `start_run/1`
- `lib/kiln/runs.ex` — `list_active/0` (ordering: `inserted_at` asc)
- `config/config.exs` — `config :kiln, Oban, queues:` taxonomy
- `lib/kiln/boot_checks.ex` — aggregate Oban concurrency vs pool ceiling
- `lib/kiln/telemetry.ex` / `lib/kiln/telemetry/otel.ex` — pack_meta, Oban handler, OTel setup
- `lib/kiln_web/telemetry.ex` — `Telemetry.Metrics` summaries (Ecto queue_time etc.)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Oban six-queue taxonomy** — reuse for isolation; extend with **per-run** metadata for fairness tests.
- **`Kiln.Telemetry.pack_meta/0` + `ObanHandler`** — propagate correlation into workers without new ad-hoc globals.
- **`Runs.list_active/0`** — partial index `runs_active_state_idx`; today **FIFO by `inserted_at`** for scan order; admission policy may add **RR pointer** or alternate ordering for **fair** progress while keeping DB cheap.

### Established Patterns

- **Postgres + same-tx audit** on transitions — any new “dequeue” or admission step must stay **transactionally paired** with `Audit.Event` per project conventions.
- **BootChecks** — any change to aggregate concurrency must stay aligned with **Repo pool_size**.

### Integration Points

- **`RunDirector.start_run/1` → `Transitions.transition(run.id, :planning)`** — likely hook for **dwell end** telemetry and ordering guarantees when leaving `queued`.
- **Oban workers** (`Kiln.Oban.BaseWorker` and stage workers) — attach **run_id** consistently for per-run Oban `queue_time` filtering in tests.

</code_context>

<specifics>
## Specific Ideas

Research synthesis (Celery/RQ/Sidekiq/BullMQ/Temporal/k8s scheduler; BEAM idioms): **RR + stable tie-break at a published grain**, **split admission vs executor**, **layered caps**, **:telemetry-first CI contract** for run dwell, **no selective receive**, **no metric label explosion on run_id**.

</specifics>

<deferred>
## Deferred Ideas

- **Weighted fair-share** when product provides weights (tiers, credits).
- **Gini / Jain fairness index** across runs for research-grade dashboards.
- **Cross-node** global fairness (single-node v1 is sufficient for solo/local-first).
- **LiveView fairness chart** before underlying events + tests exist.

### Reviewed Todos (not folded)

None — `todo.match-phase` returned no matches.

</deferred>

---

*Phase: 14-fair-parallel-runs*  
*Context gathered: 2026-04-22*
