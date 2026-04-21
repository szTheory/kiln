# Phase 6: GitHub Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `06-CONTEXT.md`.

**Date:** 2026-04-21
**Phase:** 6 — GitHub Integration
**Areas discussed:** Merge gate (Actions → merged), PR defaults, Check polling, Git commit identity & messages, Push races & non-fast-forward

---

## Session shape

User selected **all** gray areas and requested **parallel research (subagents)** plus a **single cohesive recommendation set** (minimal further operator decisions). The principal agent synthesized five research packets into **`06-CONTEXT.md`** decisions **D-G01–D-G22**.

---

## Merge gate (Actions → `merged`)

| Approach | Description | Selected |
|----------|-------------|----------|
| All checks green | Every check run must succeed | |
| Required checks on head SHA | Align with GitHub branch protection / rulesets | ✓ (primary) |
| Allowlist-only | YAML-driven check name allowlist as sole gate | |
| Hybrid + draft/skipped semantics | Required + explicit non-required / draft rules | ✓ (layered on primary) |

**User's choice:** Delegated to synthesized policy — **required checks on exact SHA** + **draft default blocks merged** + **skipped/neutral on non-required do not block**.

**Notes:** Incorporates lessons from Mergify/Bors/merge-queue footguns (predicate stability, SHA pinning).

---

## PR defaults

| Approach | Description | Selected |
|----------|-------------|----------|
| Artifact-first deterministic | `gh` args from persisted artifacts | ✓ |
| LLM-heavy at PR time | Model generates title/body inline | |
| YAML templates + slots | Template engine over artifacts | Deferred (v1.1+) |
| Minimal ops defaults | Thin body + deep links | ✓ (combined with artifact-first) |

**User's choice:** **Artifact-first** + **draft by default** + **explicit base/reviewers**; LLM only upstream as frozen artifacts if ever used.

---

## Check polling

| Approach | Description | Selected |
|----------|-------------|----------|
| Fixed interval only | Simple, risk under load | |
| Backoff without deadline | Reduces QPS, can hide stalls | |
| Hybrid + jitter + deadline | Early fast polls, backoff, hard stop | ✓ |
| Webhooks v1 | Instant updates | Deferred |

**User's choice:** **Polling-only v1** with **hybrid + jitter + absolute deadline**; auth failures → **typed block**, not Oban spin.

---

## Git identity & messages

| Approach | Description | Selected |
|----------|-------------|----------|
| Operator-forwarded identity | Human author on autonomous commits | |
| Split bot/human author/committer | Forensic clarity | Optional future |
| Stable bot + trailers | Conventional subject + `X-Kiln-*` trailers | ✓ |
| Minimal pointer-only messages | Ultra-short git, detail in DB | Partially (trailers + short body) |

**User's choice:** **Stable Kiln bot** author+committer, **Conventional Commits** + **trailers**, **unsigned v1**, **no auto DCO**.

---

## Push races

| Approach | Description | Selected |
|----------|-------------|----------|
| Fail-fast typed block | No auto-rebase | ✓ (default) |
| Bounded rebase retry | fetch/rebase capped, re-verify | ✓ (opt-in per workflow) |
| CAS push loop | Optimistic concurrency with lost-race handling | ✓ (combined with ls-remote) |
| Serialized merge-queue writer | Queue holds merge slot | Deferred / high contention only |

**User's choice:** **`git ls-remote` + CAS**; **default fail-fast**; **optional `rebase_with_retry`** capped (2 default, 3 max) with **re-verify** after integration.

---

## Claude's Discretion

Numeric tuning for poll intervals, jitter, and CI observe wall-clock fractions — left to plan/implementation within bounded-autonomy framework.

## Deferred Ideas

See `<deferred>` in `06-CONTEXT.md` (webhooks, signing, merge-queue reconciliation, LLM PR bodies).
