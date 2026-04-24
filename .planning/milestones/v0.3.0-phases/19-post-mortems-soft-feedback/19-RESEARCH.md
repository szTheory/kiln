# Phase 19 — Technical Research: Post-mortems & soft feedback

**Question:** What do we need to know to PLAN this phase well?

**Status:** Ready for planning  
**Sources:** `19-CONTEXT.md`, `REQUIREMENTS.md` (SELF-01, FEEDBACK-01), `lib/kiln/runs/transitions.ex`, `lib/kiln/audit/event_kind.ex`, `lib/kiln/stages/stage_worker.ex`, `lib/kiln_web/live/run_detail_live.ex`, `lib/kiln/oban/base_worker.ex`, Phase 18 cost/budget patterns.

---

## 1. Merge boundary & async materialization

- **`Kiln.Runs.Transitions.transition/3`** wraps state changes in **`Repo.transact/2`** and performs **PubSub only after** `{:ok, run}` (see moduledoc ~L121–L134). Any **Oban insert for post-mortem materialization MUST mirror that pattern**: enqueue **outside** the transaction closure, keyed on committed `run_id`, when `to == :merged`.
- **Heavy aggregation** (stage metrics, audit tail walk, JSONB assembly) must **not** run inside the merge transaction — violates D-1910/D-1911 and risks lock hold time.
- **Idempotency:** Reuse **`Kiln.Oban.BaseWorker`** + **`external_operations`** with op_kind like `post_mortem_materialize` and args `idempotency_key: "post_mortem_materialize:<run_id>"` so retries and duplicate merges collapse (D-44, D-1914).
- **Watermark:** Snapshot should record **`source_watermark`** (e.g. max **`occurred_at`** ISO8601 plus optional last **`audit_events.id`** UUID string — **`audit_events.id` is binary_id v7**, not bigint) so UI can explain fixed cut vs tail (D-1912).

---

## 2. Storage model (`run_postmortems`)

- **1:1 `run_id`** with **`unique_index(:run_id)`** — CONTEXT D-1901. Typed filter columns + **`schema_version`** + **JSONB** for nested sections keeps **hot `runs` row small** (D-1903).
- **Upsert:** Worker uses **`INSERT ... ON CONFLICT (run_id) DO UPDATE`** (or `DO NOTHING` when complete + unchanged watermark) per D-1914.
- **CAS optional:** `artifact_id` nullable — export path only (D-1902). Phase 19 can ship **row-only** if JSONB size acceptable in dogfood.

---

## 3. Audit taxonomy extension

- **`Kiln.Audit.EventKind`** uses a single **`@kinds` list**; migrations **regenerate CHECK** from **`EventKind.values_as_strings/0`** — same append-only discipline as **`:budget_threshold_crossed`** (Phase 18).
- New kinds from CONTEXT: **`:operator_feedback_received`** (required for FEEDBACK-01); **`:post_mortem_snapshot_stored`** optional ledger echo (D-1917) — planner may ship atom + schema in one migration or defer snapshot kind to fast-follow; **both listed in CONTEXT D-1940**.
- **JSON schemas** live under **`priv/audit_schemas/v1/<kind>.json`** with string keys; **`Audit.append/1`** validates against registered schema (verify in `Kiln.Audit`).

---

## 4. Operator nudge write path

- **SoT = Postgres:** LiveView **`phx-submit`** → **`Repo.transact`** → **`Audit.append`** with `:operator_feedback_received` + optional **`operator_nudges`** row (CONTEXT leaves table vs audit-only to planner).
- **Rate limits:** Server-enforced cooldown + hourly cap (D-1932); **`phx-disable-with`** on button.
- **Validation:** Strip controls, normalize whitespace, **hard max graphemes** ~140–200 (executor picks exact number); reject empty-after-trim (D-1925).
- **Telemetry:** **`[:kiln, :operator, :nudge, :received]`** — metadata only, **no raw body** (D-1926).
- **PII/secrets:** Payload must not echo secrets (D-1906 symmetry).

---

## 5. Consumption at planning boundary (D-1921–D-1924)

- **Stage entry:** **`Kiln.Stages.StageWorker.perform/1`** today uses **`stub_dispatch/3`** for all kinds — real planner wiring is Phase 3+, but **FEEDBACK-01 requires** a **durable consumption cursor** advanced in the **same transaction** as “applied to planner context” (D-1924).
- **Practical v1 hook:** Before **`stub_dispatch`** when **`stage_kind == :planning`**, call **`Kiln.OperatorNudges.consume_pending_for_run/2`** (name TBD) that:
  1. `SELECT … FOR UPDATE` on run row or dedicated cursor row.
  2. Lists `audit_events` with kind `:operator_feedback_received` and `id > cursor`.
  3. Persists **`operator_nudge_cursor_audit_id`** (new column on `runs` or side table).
  4. Returns **`[%{seq: …, body: …, …}]`** for injection.
- **Injection without breaking JSV stage contracts:** Prefer **Logger metadata forbidden**; options: (a) merge into **stub artifact** body for planning only as provenance trail until real adapter exists, or (b) pass via **process dictionary** ❌ — **reject**; (c) store last-consumed bundle on **`stage_runs`** metadata JSON if schema allows — verify **`stage_runs` schema**. Safest short-term per CONTEXT: **structured context module** read by **future** `Kiln.Agents` adapter; for stub era, **append YAML block to `planning.md` artifact** so operators/tests see consumption happened (grep-verifiable).
- **Double-delivery:** Cursor monotonicity prevents replays on Oban retry of same stage job after partial failure — align with **intent table** semantics.

---

## 6. `RunDetailLive` integration

- Already subscribes **`"run:#{run.id}"`** and assigns **budget** hints (Phase 18). **Post-mortem panel** and **nudge composer** should reuse **same PubSub topic** (D-1941).
- **Partial state before row exists:** Assign **`postmortem: nil | %PostMortem{}`**; template shows **“Summary generating…”** when merged + nil (D-1913).
- **Accessibility:** label **“Operator note (nudge)”**, `aria-describedby` for limits (D-1935).
- **Blocked runs:** Composer allowed but visually distinct from BLOCK remediation (D-1934).

---

## 7. Pitfalls

| Pitfall | Mitigation |
|---------|------------|
| Enqueue inside merge tx | Oban insert after `Repo.transact` returns `{:ok, _}`. |
| Logging raw nudge | Tests assert capture **excludes** body substring. |
| Prompt injection into coding | Never pass raw string into codegen prompts — planner-only advisory context (D-1922). |
| CHECK constraint drift | Migration uses **only** `EventKind.values_as_strings/0`. |
| Thundering herd on first view | Do not rely on lazy full recompute as sole persistence (D-1916). |

---

## Validation Architecture

Nyquist-aligned validation strategy for Phase 19 (Elixir / ExUnit):

| Dimension | Strategy |
|-----------|------------|
| **1. Contract** | JSV audit schemas for new kinds; Ecto changesets for `run_postmortems` + optional nudge table; `changeset` tests reject oversize bodies. |
| **2. Durability** | Transaction tests: nudge accept + audit append atomic; cursor advance + visibility. |
| **3. Idempotency** | Oban `unique` + `external_operations` for materialize job; duplicate merge enqueue no-ops. |
| **4. Security** | No secrets in post-mortem JSON; redaction helpers unit-tested; STRIDE register in each PLAN `<threat_model>`. |
| **5. Observability** | Telemetry events emitted with counts only; LiveView tests refute raw text in log assigns. |
| **6. Performance** | Materialize job **not** in hot tx; benchmark not required v1 — assert job enqueued async. |
| **7. UX** | LiveView tests: disabled submit, cooldown flash, post-mortem empty/generating/ready states. |
| **8. Sampling** | After each task: targeted `mix test` files; wave end: `mix test test/kiln/runs/ test/kiln/audit/ test/kiln_web/live/run_detail_live_test.exs` (paths adjusted to files created). |

**Wave 0:** Not required — ExUnit already present.

**Manual-only:** None planned; operator smoke optional.

---

## RESEARCH COMPLETE

Proceed to `19-VALIDATION.md` + PLAN authoring.
