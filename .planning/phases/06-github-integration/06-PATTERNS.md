# Phase 6 — Pattern Map (PATTERNS.md)

**Purpose:** Closest analogs in-repo for GitHub/git execution work.

---

## external_operations two-phase

| Role | Analog file | Excerpt pattern |
|------|-------------|-----------------|
| intent → complete | `lib/kiln/sandboxes/docker_driver.ex` | `fetch_or_record_intent/2` with `op_kind`, then `complete_op/2` / `fail_op/2` outside long-running section |
| Oban + unique | `lib/kiln/oban/base_worker.ex` | `use Kiln.Oban.BaseWorker, queue: :stages` — use `queue: :github` |

---

## Worker shape

| Role | Analog file | Notes |
|------|-------------|-------|
| Stage side-effect | `lib/kiln/stages/stage_worker.ex` | `unpack_ctx`, idempotency short-circuit when op `:completed` |
| Telemetry | `lib/kiln/agents/adapter/anthropic.ex` | correlation_id from Logger metadata |

---

## State transitions

| Role | Analog file | Notes |
|------|-------------|-------|
| Command module | `lib/kiln/runs/transitions.ex` | `verifying: [:merged, :planning, :blocked]` — new callers must use `Transitions.transition/3` only |

---

## Audit / taxonomy

| Role | Analog file | Notes |
|------|-------------|-------|
| Event kinds | `lib/kiln/audit/event_kind.ex` | `:git_op_completed`, `:pr_created`, `:ci_status_observed`, `:block_raised` pre-declared |
| JSV payload | `priv/audit_schemas/v1/*.json` | Add/update schemas when new payload shapes ship |

---

## Typed blocks

| Role | Analog file | Notes |
|------|-------------|-------|
| Playbooks | `priv/playbooks/v1/gh_auth_expired.md`, `gh_permissions_insufficient.md` | Reference from `Kiln.Policies.BlockCatalog` or equivalent when raising `:blocked` |

---

## PATTERN MAPPING COMPLETE
