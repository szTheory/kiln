# Phase 9: Dogfood & Release (v0.1.0) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `09-CONTEXT.md` — this log preserves alternatives considered.

**Date:** 2026-04-21
**Phase:** 9 — Dogfood & Release (v0.1.0)
**Mode:** User requested **all** gray areas + parallel **subagent research** synthesis (no interactive per-question turns).

**Areas discussed:** Dogfood run contract; OpenTelemetry proof & DX; Release mechanics (`v0.1.0`); README & second-machine validation

---

## Dogfood run contract

| Option | Description | Selected |
|--------|-------------|----------|
| A1 Fixed canonical spec in repo | Single committed dogfood spec | Partial — **golden template in repo**, UI-authored for acceptance (**D-901**) |
| A3 Operator freeform only | UI spec only | Rejected as sole mechanism (repro/CI drift) |
| C1 GitHub auto-merge | Native auto-merge when checks pass | ✓ (**D-902**) |
| C2 Merge queue | Serialize merges | Deferred (**deferred**) |
| C3 PAT merge | Personal token | Rejected — use App / fine-grained token (**D-902**) |
| D1 Content-derived branch names | `kiln/dogfood/<hash>-<id>` | ✓ (**D-903**) |
| D5 Noop if already on main | Green without PR noise | ✓ (**D-904**) |

**User's choice:** Research synthesis + roadmap SC1 reconciliation (UI write + repo golden bytes).
**Notes:** Patterns borrowed from Renovate/Dependabot (idempotent PRs, labels); avoided `pull_request_target`-class footguns; path allowlists for blast radius.

---

## OpenTelemetry proof & DX

| Option | Description | Selected |
|--------|-------------|----------|
| App → Jaeger direct | Skip collector | Rejected — collector default for prod-shaped DX (**D-911**) |
| Collector → Jaeger | Local compose default | ✓ (**D-911**) |
| Metrics SDK now | Full signals | Rejected — trace-first (**D-910**) |
| Baggage for secrets | Convenience | Rejected — security footgun (**D-913**) |

**User's choice:** Subagent consensus → **D-910..D-915**.
**Notes:** Lessons from Rails/Node/Java: span explosion, PII in attrs, broken Oban propagation—addressed via naming discipline + Oban helpers + parent-based sampling.

---

## Release mechanics (`v0.1.0`)

| Option | Description | Selected |
|--------|-------------|----------|
| Tag only | No GitHub Release object | Rejected for milestone visibility (**D-921**) |
| GitHub Release + CHANGELOG | Release body from changelog | ✓ (**D-920, D-921**) |
| AGPL default | Strong copyleft | Rejected (**D-922**) |
| Apache-2.0 | Patent grant + standard | ✓ preferred (**D-922**) |

**User's choice:** Subagent synthesis.
**Notes:** CI must run on **tag push** and assert tag ↔ `mix.exs` version (**D-923**); `CHANGELOG.md` did not exist in repo at discuss time—create in execute phase.

---

## README & second-machine validation

| Option | Description | Selected |
|--------|-------------|----------|
| first_run.sh alone proves SC4 | Health JSON = done | Rejected — false confidence (**D-930**) |
| LiveView tests for onboarding | ExUnit oracle | ✓ (**D-930**) |
| Manual cold clone per milestone | Human README-only walk | ✓ required for SC4 honesty (**D-930**) |
| README `/` first | Old open order | Rejected — **`/onboarding` first** (**D-931**) |

**User's choice:** Layered validation model from subagent research.
**Notes:** Align README with onboarding gate from Phase 8; optional Playwright deferred.

---

## Claude's Discretion

- Filenames under `dogfood/`, exact Collector YAML knobs, GitHub Release create mechanism (CLI vs UI).

## Deferred Ideas

- Merge queue; Playwright E2E; OTel metrics SDK maturity; Phase 999.1 promotion.
