# Phase 12: Local Docker / dev environment DX - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `12-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 12-local-docker-dx
**Areas discussed:** Plans gate; strategy fork (devcontainer vs Compose app vs task runner); README/audit IA; ship depth; CI; synthesis + user approval to write context

---

## Plans gate

| Option | Description | Selected |
|--------|-------------|----------|
| Continue and replan after | Capture context, then `/gsd-plan-phase 12` | ✓ |
| View existing plans | Inspect `12-01-PLAN.md` before deciding | |
| Cancel | Stop discuss-phase | |

**User's choice:** Continue and replan after (`1`).

---

## Primary DX strategy (devcontainer vs Compose `app` vs wrapper)

| Option | Description | Selected |
|--------|-------------|----------|
| Task runner + host Phoenix | `justfile` (preferred) or `Makefile` wrapping compose + `kiln_owner` setup + `mix phx.server` | ✓ |
| Compose `app` service | Phoenix in Compose | |
| Devcontainer | VS Code/Cursor dev container | |

**User's choice:** Deferred explicit per-area picks; user requested deep research + one-shot cohesive recommendations. Synthesis locked **task runner + host Phoenix** as Phase 12 strategy; devcontainer and Compose app explicitly **not** shipped in Phase 12 per **D-1201a**.

**Notes:** Research emphasized Kiln’s **host `docker` CLI** for sandboxes, **no socket mounts**, **dual DB roles**, and **Phase 10 README-as-canonical** — Compose-hosted Phoenix and devcontainer ranked higher risk / maintenance for **solo** v0.2 optional DX.

---

## README vs LOCAL-DX-AUDIT placement

| Option | Description | Selected |
|--------|-------------|----------|
| README-first tiering | Subordinate optional section; audit = pointer only | ✓ |
| Long doc split | `docs/local-optional-dx.md` only if README subsection would exceed ~15 lines | ✓ (conditional) |

**User's choice:** Aligned with Phase 10 **D-1001a** — **D-1202**, **D-1202a**, **D-1202b** in CONTEXT.

---

## Ship depth

| Option | Description | Selected |
|--------|-------------|----------|
| Checked-in justfile/Makefile + docs | Minimum reproducible optional path | ✓ |
| Docs-only | Rejected for Phase 12 (drift risk) | |

**User's choice:** **D-1203** — checked-in task runner file.

---

## CI

| Option | Description | Selected |
|--------|-------------|----------|
| Host `mix check` remains canonical | Ubuntu + `erlef/setup-beam` + existing caches | ✓ |
| Full duplicate `mix check` in dev image | Rejected for default PR path | |
| Path-filtered `docker build` smoke | Conditional future if dev image exists — **D-1204a** | |

**User's choice:** **D-1204**, **D-1204a**.

---

## Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Cold clone / second machine | Same `/onboarding` outcome for default or optional path | ✓ |

**User's choice:** **D-1205**.

---

## Claude's Discretion

- Exact `just` target names; optional `mix` alias as one-line delegate; `just` vs `make` if maintainer prefers `make`.

---

## Deferred ideas

- **Devcontainer** and **Compose `app`** — deferred with rationale (see CONTEXT `<deferred>`).
- **gsd-2** (`https://github.com/gsd-build/gsd-2`) — user aside: possible future GSD tooling integration / research; **not** started in Phase 12; recorded in CONTEXT `<deferred>`.
