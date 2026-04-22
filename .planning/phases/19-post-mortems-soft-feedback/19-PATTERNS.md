# Phase 19 — Pattern Map (PATTERNS.md)

**Purpose:** Closest analogs in the Kiln codebase for files Phase 19 will touch or mirror.

---

## Audit taxonomy & migrations

| New / target | Analog | Excerpt / rule |
|--------------|--------|----------------|
| Append `EventKind` | `lib/kiln/audit/event_kind.ex` | `@kinds` list; Phase 18 `:budget_threshold_crossed` append block |
| CHECK migration | `priv/repo/migrations/20260421224335_extend_audit_event_kinds_p8_follow_up_drafted.exs` | `DROP CONSTRAINT` + `CHECK (event_kind IN (...))` from **`Kiln.Audit.EventKind.values_as_strings/0`** |
| Audit JSON schema | `priv/audit_schemas/v1/budget_threshold_crossed.json` | Draft 2020-12; string keys; `additionalProperties` policy |

---

## Transactions & post-commit side effects

| Concern | Analog | Rule |
|---------|--------|------|
| PubSub after commit | `lib/kiln/runs/transitions.ex` (`transition/3`) | Never broadcast inside `Repo.transact` closure |
| Oban + idempotency | `lib/kiln/oban/base_worker.ex` + `lib/kiln/stages/stage_worker.ex` | `use Kiln.Oban.BaseWorker`; `fetch_or_record_intent/2` for side effects |

---

## Operator UI on run detail

| Concern | Analog | Rule |
|---------|--------|------|
| LiveView + PubSub | `lib/kiln_web/live/run_detail_live.ex` | Subscribe `"run:#{run.id}"`; assign-driven panels |
| Budget hints (compose, don’t fork) | Phase 18 patterns in same file | Separate assign for post-mortem; reuse topic |

---

## Stage execution

| Concern | Analog | Rule |
|---------|--------|------|
| Stage dispatch | `lib/kiln/stages/stage_worker.ex` | `stub_dispatch/3` today — planning hook **before** dispatch for nudge consumption |

---

## PATTERN MAPPING COMPLETE
