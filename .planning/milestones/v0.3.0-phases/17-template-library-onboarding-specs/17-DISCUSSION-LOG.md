# Phase 17: Template library & onboarding specs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.  
> Decisions are captured in `17-CONTEXT.md`.

**Date:** 2026-04-22  
**Phase:** 17 — Template library & onboarding specs  
**Areas discussed:** (1) Template layout & indexing, (2) Instantiate semantics, (3) Operator IA, (4) Metadata & estimates  
**Mode:** User selected **all** areas and requested **parallel subagent research** + **one-shot cohesive recommendations** (delegated to synthesis into CONTEXT).

---

## Synthesis method

| Step | Detail |
|-------|--------|
| Research | Four `generalPurpose` subagents ran in parallel (Elixir/release idioms, Specs/Intents boundaries, IA prior art, pricing/metadata footguns). |
| Integration | Lead agent merged outputs, resolved tensions (e.g. catalog **vs** inbox mental model → **`/templates` + inbox triage**), aligned with **Phase 8** promotion invariant and **WFE-01/ONB-01**. |

---

## (1) Template layout & indexing

| Option | Description | Selected |
|--------|-------------|----------|
| A | `priv/templates/<id>/` + root manifest + `Application.app_dir` + CI exhaustive load | ✓ |
| B | Compile-time codegen / `@external_resource` for index | Optional later |
| C | Single monolithic manifest only (no per-template dirs) | |
| D | Postgres-seeded template bodies | ✗ |
| E | Convention-only filename matching without manifest | ✗ |

**User's choice:** Delegated — **A** (directory per template + authoritative manifest, CI verify, release-safe paths).  
**Notes:** Subagent flagged **cwd vs release** drift risk; locked **app_dir-only** for shipped reads.

---

## (2) Instantiate semantics

| Option | Description | Selected |
|--------|-------------|----------|
| A | Open draft only | Secondary path (“Edit first”) |
| B | Promote immediately (no long-lived draft) | ✓ (primary default for vetted templates) |
| C | Promote + enqueue in one DB transaction | Optional single control when gates green |
| D | Draft + optional promote & run | ✓ (shapes product: secondary + explicit run) |

**User's choice:** Delegated — **B** as default materialization with **D**-shaped UX (secondary edit path, explicit **Start run**; optional combined CTA when safe).  
**Notes:** **Phase 8** promotion invariant preserved; **idempotency** at instantiate + enqueue.

---

## (3) Operator IA

| Option | Description | Selected |
|--------|-------------|----------|
| 1 | Full catalog tab inside `/inbox` | ✗ |
| 2 | Top-level `/templates` | ✓ |
| 3 | Templates only inside `/onboarding` | Partial — bridge CTA only |
| 4 | Hybrid `/templates` + deep links to inbox/spec | ✓ |

**User's choice:** Delegated — **Hybrid (4)** with **`/templates` canonical (2)** and **onboarding bridge (3)**; inbox not the catalog home.

---

## (4) Metadata & estimates

| Option | Description | Selected |
|--------|-------------|----------|
| A | Static manifest fields (bands + disclaimer + last_verified) | ✓ |
| B | Global-only index without per-template files | ✗ (avoid dual-write drift) |
| C | Derive UX solely from `Kiln.Pricing` | ✗ as sole display; ✓ optional CI guardrail |
| D | Postgres for canonical built-in metadata | ✗ |

**User's choice:** Delegated — **A** + optional **C** for CI sanity; reject **D** for v1 built-ins.

---

## Claude's Discretion

Exact manifest format (JSON vs YAML), ephemeral draft vs direct spec insert audit kind, post-success redirect default, whether `mix templates.verify` is ExUnit-only or a Mix task.

## Deferred Ideas

See `<deferred>` in `17-CONTEXT.md` (marketplace, WFE-02, remote catalogs, operator-local packs).
