# Phase 15 — Run comparison — Technical research

**Status:** Ready for planning  
**Date:** 2026-04-22  
**Question answered:** What do we need to know to *plan* **PARA-02** well?

---

## 1. Requirement & boundary

**PARA-02 (REQUIREMENTS.md):** Operator opens a **run comparison** for **two** runs (metadata, stage outcomes, artifact/diff pointers, cost summary) **without leaving the dashboard**.

**Locked in `15-CONTEXT.md`:** Canonical route **`/runs/compare?baseline=&candidate=`**; router **static segment before** `/runs/:run_id`; read model in **`Kiln.Runs`** (or adjacent module); **union on `workflow_stage_id`**; artifact rows = logical key + size + digest + coarse equality + **deep-link** to `RunDetailLive` diff — **no** merged workspace diff.

**Out of scope:** Replay (16), fairness (14), saved-comparison tokens, second diff highlighter.

---

## 2. Code anchors

| Area | File / API | Reuse |
|------|------------|--------|
| Board | `lib/kiln_web/live/run_board_live.ex` | PubSub `runs:board`; stream keys per state; add compare strip / events without breaking streams |
| Detail | `lib/kiln_web/live/run_detail_live.ex` | `Ecto.UUID.cast/1` in mount; `handle_params` pane/stage; `Artifacts.read!/1` + 512 KiB cap for diff — **link targets** |
| Router | `lib/kiln_web/router.ex` | `live_session :default` — insert **`live "/runs/compare", RunCompareLive, :index`** **immediately before** `live "/runs/:run_id", RunDetailLive, :show` |
| Runs API | `lib/kiln/runs.ex` | `get/1`, `get!/1`; extend with **bounded** compare loader (new public functions) |
| Stages | `lib/kiln/stages.ex` + `StageRun` | `workflow_stage_id`, `cost_usd`, `tokens_used`, `state`, `attempt` — drive union rows |
| Artifacts | `Kiln.Artifacts.Artifact` | `name`, `sha256`, `size_bytes`, `run_id`, `stage_run_id` — **SELECT only**, no blob paths in LV assigns beyond what’s needed for links |

---

## 3. Data model strategy

1. **Two `Runs.get/1`** (or one query `where id in ^pair`) — tolerate **one nil** per CONTEXT D-06.
2. **Stage union:** Fetch **`Stages.list_for_run/1`** (or equivalent) for **each** run. In Elixir, build a **`MapSet`** of all `workflow_stage_id` values, sort with **deterministic ordering** (graph order from `Kiln.Workflows.graph_for_run/1` when checksums match **baseline** run, else **alphabetical** `workflow_stage_id` as v1 fallback — planner picks one rule and documents in `@moduledoc`).
3. **Per-row cells:** For each key, attach **latest attempt** `StageRun` per side (reuse `Workflows.latest_stage_runs_for/1` pattern from detail).
4. **Artifacts:** Single query per run: `from a in Artifact, where: a.run_id == ^id, select: map(a, [:id, :name, :sha256, :size_bytes, :stage_run_id, :content_type])` — join in memory to stage keys for grouping; **digest compare** only (same `sha256` → same; one nil → one-sided).

---

## 4. Security & abuse notes (solo v1)

- **UUIDs in query string** are shareable inside the operator trust zone — no additional token in v1.
- **No user-supplied HTML** — all render via HEEx escapes; artifact names are **display truncated** if long.
- **Read-only** — compare LiveView must not expose transition events unless explicitly inherited from a shared layout hook (default: **none**).

---

## 5. Risks

| Risk | Mitigation |
|------|------------|
| N+1 on artifacts | One query per run, max 2 queries for artifacts + 2 for stage lists + 2 for runs |
| Huge stage cardinality | CONTEXT allows future collapse — v1 renders full union with scroll |
| Router shadowing | **Order** `/runs/compare` before `/runs/:run_id` (D-02) |

---

## Validation Architecture

> Nyquist / Dimension 8 — sampling contract for execution agents.

**Primary automated signals**

1. **`mix test test/kiln_web/live/run_compare_live_test.exs`** — happy path: mount compare URL with two valid run ids → `#run-compare` + `data-baseline-id` + `data-candidate-id` present; at least one `[data-stage-key]` when fixture runs have stages.
2. **Same file** — malformed `baseline` UUID → redirect to `/` with flash (grep: `put_flash` + `push_navigate` **or** assert on rendered flash via `conn` test pattern used elsewhere).
3. **`mix test test/kiln/runs/run_compare_test.exs`** (or module name chosen in implementation) — pure function tests for **union key ordering** + **digest equality** helper if extracted.

**Sampling policy**

- After **each** task commit touching `lib/kiln/` compare logic: `mix test test/kiln/runs/run_compare_test.exs --max-failures 1` (when file exists).
- After **each** LiveView task: `mix test test/kiln_web/live/run_compare_live_test.exs --max-failures 1`.
- End of phase: **`mix precommit`** (project alias per `AGENTS.md`).

**Wave 0**

- Existing **Phoenix + LiveViewTest + LazyHTML** infrastructure covers this phase — no new test framework.

---

## RESEARCH COMPLETE

Phase 15 planning may proceed with **router-first** delivery, then **read model**, then **UI + tests**.
