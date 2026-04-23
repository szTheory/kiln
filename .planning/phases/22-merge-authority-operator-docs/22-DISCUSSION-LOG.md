# Phase 22: Merge authority & operator docs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `22-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 22 — Merge authority & operator docs
**Areas discussed:** SSOT placement; row granularity; optional vs merge table; Phase 12 PARTIAL narrative

**Mode:** User selected **all** areas and requested **parallel subagent research** + one-shot synthesized recommendations (no per-question interactive passes).

---

## 1. Matrix SSOT (README vs PROJECT.md)

| Option | Description | Selected |
|--------|-------------|----------|
| Duplicate full table in README + PROJECT | Maximum skim convenience; high drift risk |  |
| README-only pointer (matrix elsewhere only) | Thin README; weaker if target is deep `.planning/` only |  |
| PROJECT SSOT + README summary + anchor | One normative table; README orients + links | ✓ |

**User's choice:** All areas + delegate to research-backed cohesive default → **PROJECT.md SSOT + README summary** (see **D-2201** in CONTEXT).

**Notes:** Cross-ecosystem pattern (Phoenix/Ecto README vs guides, Rails CONTRIBUTING, Rust handbook) favors **one authoritative matrix** + thin entrypoints. Kiln’s `PROJECT.md` lives at `.planning/PROJECT.md` (no root file).

---

## 2. Row granularity (per CI job vs tiers)

| Option | Description | Selected |
|--------|-------------|----------|
| One row per CI job / step | High fidelity to Checks UI; high maintenance / table rot |  |
| Semantic tiers + workflow/job references | Intent-first; survives refactors; needs accurate links | ✓ |

**User's choice:** Research-backed default → **3–5 semantic tiers** mapping to current `ci.yml` jobs (**D-2202**).

**Notes:** Accounts for future path-filtered jobs (document behavior when check absent). Inspired by Elixir core CONTRIBUTING + ultimate-elixir-ci style separation.

---

## 3. Optional local commands placement

| Option | Description | Selected |
|--------|-------------|----------|
| Same table as merge gates | Single scan; blurs required vs recommended |  |
| Secondary “recommended / shift-left” block | Clear merge bar; optional discoverability | ✓ |
| README-only for all optional detail | Risk of README bloat + drift from PROJECT | Partially — README stays short; list lives in PROJECT |

**User's choice:** **Merge table = CI-blocking only**; **optional commands in labeled subsection** under same PROJECT section (**D-2203**).

---

## 4. Phase 12 PARTIAL + local vs CI tone

| Option | Description | Selected |
|--------|-------------|----------|
| Short README callout + deep link only | Minimal above-fold cost | ✓ (README layer) |
| Large dedicated README section | Room for failure modes; risks wall of caveats | Partially — **deep detail in PROJECT** |
| Dedicated PROJECT “Local vs CI” subsection | Calm engineering tone; single update locus | ✓ |

**User's choice:** **Two-layer doc**: README one calm paragraph + links to `12-01-SUMMARY.md` and PROJECT merge section; PROJECT holds **Local vs CI** bullets (**D-2204**).

---

## Claude's Discretion

- PR template pointer, exact anchors, CONTRIBUTING cross-link — optional at implementation (**CONTEXT** discretion block).

## Deferred Ideas

- CONTRIBUTING as co-SSOT; auto-generated workflow docs — see `<deferred>` in `22-CONTEXT.md`.
