# Phase 8: Operator UX (Intake, Ops, Unblock, Onboarding) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `08-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 8 — Operator UX (Intake, Ops, Unblock, Onboarding)
**Areas discussed:** Routes & cost intel, Onboarding gate, Intake & inbox, Factory header & agent ticker (all four gray areas)
**Method:** User requested **all** areas + deep parallel research via subagents; lead agent synthesized into single coherent CONTEXT.

---

## Routes, layout shell, cost intel vs `/costs`

| Option | Description | Selected |
|--------|-------------|----------|
| A — Tab/segment on `/costs` | Single `CostLive` owns dimensions + OPS-04 intel; optional `/costs/intel` same LV | ✓ |
| B — `/ops/costs` or standalone `CostIntelLive` | Splits mental model; violates Phase 7 `/ops` rule | |
| C — Intel only in header/cards | Weak forensics; duplicate logic | Partial ✓ as **funnel** into A |

**User's choice:** Research-backed synthesis — **primary intel on `/costs`**, sparse header/card callouts linking in; **`/ops` untouched**.

**Notes:** Compared to GitHub Billing, AWS Cost Explorer+Recommendations, Datadog fragmentation lessons, Grafana annotation spam. Phoenix: one `live_session`, `push_patch` for tabs, avoid duplicate subscribers.

---

## Onboarding wizard (BLOCK-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `/onboarding` | Explicit URL, bookmarkable, matches CLI-tool flows | ✓ |
| Blocking modal only | Hostile to refresh/deep links | |
| Checklist drawer primary | Easy to ignore for first-run | Secondary ✓ for re-entry |

**User's choice:** **`/onboarding` + Plug redirect + run preflight module**; probes not one-shot boolean; **`gh`/Docker verify** not Kiln-owned OAuth; bypass aligns **D-33** style.

**Notes:** VS Code soft onboarding vs Docker Desktop heaviness; Stripe CLI / `fly auth` delegate-verify pattern; BootChecks vs onboarding orthogonal split.

---

## Intake + inbox (INTAKE-01..03)

| Option | Description | Selected |
|--------|-------------|----------|
| Drafts under `Kiln.Specs` | Raw material → promote → `spec_revisions` | ✓ |
| Overload `Kiln.Intents` for drafts | Conflicts with run-intent stub | ✗ |
| `gh` shell for core import | Injection + parsing risk as sole path | Optional dev only |
| Req + GitHub API | Structured, ETag, testable | ✓ core |

**User's choice:** **Separate draft rows**, promotion transaction + audit; **artifact refs + summary** on follow-up; **external_operations** idempotency.

**Notes:** GitHub Projects / Linear dedupe lessons; partial unique index on open imports.

---

## Factory header + agent ticker

| Option | Description | Selected |
|--------|-------------|----------|
| Single parent PubSub subscriber | Header assigns fed to layout | ✓ |
| LiveComponent per page each subscribes | Process fan-out | ✗ |
| Ticker every page | Attention theft + CPU | ✗ |
| Ticker on `/` only + optional link | Matches roadmap + Phase 7 quiet detail | ✓ |

**User's choice:** **`factory:summary`** (low rate) + **`agent_ticker`** (token bucket + batch + coalesce + stream cap); board stays D-725..728.

**Notes:** Slack grouping, Argo CD in-place health, GHA logs in one panel, Grafana sparse markers.

---

## Claude's Discretion

- Micro-labels, exact debounce cap integers, final path string `/providers` vs `/health/providers`.

## Deferred Ideas

- New BC `Kiln.Inbox` if Specs grows too large.
- v1.1 email/webhook notifications.
