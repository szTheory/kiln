# Phase 5: Spec, Verification & Bounded Loop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `05-CONTEXT.md` — this log preserves alternatives, research path, and rationale.

**Date:** 2026-04-21
**Phase:** 05-spec-verification-bounded-loop
**Areas discussed:** Scenario format & runner; Holdout isolation; Verifier + LLM explain-only; Bounded autonomy caps; Stuck detector vs circuit breaker; Spec editor LiveView UX

---

## Session shape

| Item | Detail |
|------|--------|
| **User directive** | Discuss **all** gray areas in one shot; spawn subagents for pros/cons, idioms, prior art, footguns, DX; produce a single coherent recommendation set aligned with Kiln vision (Postgres truth, deterministic oracle, append-only audit, solo operator UX). |
| **Follow-up** | User confirmed: persist to `05-CONTEXT.md` + this log + git commit. |
| **Research execution** | Six parallel `generalPurpose` subagents (Cursor Task tool), one per gray area; parent synthesized cross-cutting coherence (single grammar, single oracle path, privilege+manifest+tests for holdouts, two-phase verifier, orthogonal caps, Postgres-backed stuck vs global breaker, dedicated LiveView editor). |

---

## Area 1: Scenario format & deterministic runner

| Option | Description | Selected |
|--------|-------------|----------|
| A | Native Gherkin + step definitions | Rejected as **primary** — regex coupling, second codebase, flake |
| B | **Markdown fenced blocks → structured IR → codegen ExUnit → `mix test` in sandbox** | ✓ (D-S01) |
| C | External binary runner only | Rejected for v1 — extra language boundary unless non-Elixir targets force later |
| D | YAML IR only (no markdown narrative) | Rejected — poor author UX; markdown stays human-canonical |

**User's choice:** Structured scenarios inside markdown; **ExUnit / mix test** as authoritative process; **exit code** = verdict bit.

**Notes:** Aligns with Elixir ecosystem norms (`mix test`, tags, CI). Absorbs lessons from Cucumber/RSpec/Playwright: avoid LLM-as-oracle, avoid retry-masking, keep git-diffable sources.

---

## Area 2: Holdout isolation (SPEC-04)

| Option | Description | Selected |
|--------|-------------|----------|
| A | DB table + Ecto only | Partial — needs privilege hardening |
| B | Filesystem separation only | Insufficient — symlink/bind-mount risk |
| C | **DB `REVOKE` + CAS allowlist + provenance tests** | ✓ (D-S02) |
| D | Crypto envelope / KMS | Deferred — overkill for solo v1 |

**User's choice:** Defense in depth: **`kiln_app` cannot SELECT holdouts**; verifier-only role; manifest closure tests; optional xref allowlist on modules.

**Notes:** Oban args = ids/hashes only; redact telemetry. Lessons from eval contamination / RAG indexing holdouts.

---

## Area 3: Verifier + LLM explain-only

| Option | Description | Selected |
|--------|-------------|----------|
| A | Single-phase “judge model” verdict | Rejected — violates SPEC-03 / UAT-01 |
| B | **Machine verdict persisted first; optional LLM JSON+narrative; no override** | ✓ (D-S03) |

**User's choice:** `%VerifierResult{}` with immutable machine fields; LLM disagreement is a **flag**, not a state change; JSV on structured slices.

**Notes:** Absorbs RLHF “judge bias” lessons; Elixir immaturity favors explicit structs + same-txn audit.

---

## Area 4: Bounded autonomy caps

| Option | Description | Selected |
|--------|-------------|----------|
| A | Single “step” counter for everything | Rejected — confuses operator vs billing |
| B | **Wall + governed stage attempts + spend** with precedence table | ✓ (D-S04) |

**User's choice:** Precedence: global halt → wall → attempts → USD/tokens; idempotent replays do not double-charge; DB clock for wall.

**Notes:** Stripe idempotency, K8s `backoffLimit`, Temporal limits cited as analogues; Oban insert-time uniqueness is not the cap source of truth.

---

## Area 5: Stuck detector vs global circuit breaker

| Option | Description | Selected |
|--------|-------------|----------|
| A | Raw exception string dedup | Rejected — unstable keys |
| B | **Stable `failure_class` + sliding window in Postgres txn** | ✓ (D-S05) |
| C | Conflate stuck with global breaker | Rejected — different scope and operator narrative |

**User's choice:** Per-run stuck halts **that** trajectory; `FactoryCircuitBreaker` handles **shared** resource storms; orphan `external_operations` → `abandon` on terminal run.

**Notes:** Sentry fingerprinting analogy; avoid flaky-test quarantine culture (silent retry without classification).

---

## Area 6: Spec editor LiveView UX

| Option | Description | Selected |
|--------|-------------|----------|
| A | Modal-first editor | Rejected — truncates context |
| B | **Dedicated `/specs/:id/edit`, debounced autosave + Cmd-S, revision timeline + diff** | ✓ (D-S06) |

**User's choice:** Same parser for preview and compile; visible save states; restore creates new revision (append-only history).

**Notes:** Notion/GitHub/Obsidian lessons: visible save semantics beat flashy collaboration for solo operator; brand book voice.

---

## Claude's Discretion

- Minor file layout under `priv/generated/scenarios/`, exact fence delimiter string, default deque length K for stuck window (bounded 10–20 range noted in CONTEXT).

## Deferred Ideas

- Crypto at rest for holdouts (multi-tenant future).
- Optional Gherkin import path.
- Non-Elixir scenario runner binary if language matrix demands.

---

*Phase: 05-spec-verification-bounded-loop*
*Discussion logged: 2026-04-21*
