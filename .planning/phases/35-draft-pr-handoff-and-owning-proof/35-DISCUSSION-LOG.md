# Phase 35 Discussion Log

**Phase:** 35 — Draft PR handoff and owning proof  
**Date:** 2026-04-24  
**Mode:** Research-backed discuss pass with parallel advisor subagents  
**Status:** Complete

## User Direction

The user selected all remaining gray areas and asked for:

- one-shot research-backed recommendations
- pros/cons and tradeoffs for each viable approach
- idiomatic guidance for Elixir/Plug/Ecto/Phoenix and adjacent ecosystems
- lessons from successful tools in the same space
- strong emphasis on principle of least surprise, software architecture, DX, and user-friendly review UX
- low-impact decisions shifted left by default inside GSD and the product, with explicit interruptions reserved only for high-impact choices

## Areas Discussed

### 1. Verification citations

**Question:** What should the PR `Verification` section cite?

**Approaches considered**
- Generic prose only
- Owning proof command only
- Exact proof-layer citations only
- Hybrid: owning proof command plus exact delegated proof-layer citations

**Recommendation**
- Use the hybrid form.
- Cite `MIX_ENV=test mix kiln.attach.prove`.
- Also cite the exact delegated proof layers:
  - `test/integration/github_delivery_test.exs`
  - `test/kiln/attach/safety_gate_test.exs`
  - `test/kiln_web/live/attach_entry_live_test.exs`

**Why**
- Strongest balance of auditability, compactness, and operator confidence
- Most idiomatic fit for Mix-based Elixir repos
- Avoids vague “verified” prose and avoids premature artifact/run-link product expansion

**Rejected defaults**
- Generic prose only
- Artifact/run-linked PR-body citations as the primary proof mechanism in this phase

**External ecosystem lessons captured**
- Dependabot, Renovate, and Mergify keep PR bodies compact and let deeper evidence live in canonical check/proof surfaces.
- Footgun to avoid: stale or uninspectable PR-body assurance text.

### 2. Request framing in the PR body

**Question:** How much of the bounded request should appear in the visible PR body?

**Approaches considered**
- Change summary only
- Summary plus acceptance criteria
- Summary plus acceptance criteria plus out-of-scope
- Full request markdown dump

**Recommendation**
- Render a compact `Summary`.
- Render `Acceptance criteria`.
- Render `Out of scope` only when non-empty and materially clarifying.

**Why**
- Best fit for brownfield trust: reviewable, bounded, compact
- Uses durable attached-request fields already stored by Kiln
- Keeps the PR feeling like a normal feature or bugfix handoff instead of an automation dump

**Rejected defaults**
- Full attached request markdown dump
- Always-on empty `Out of scope` sections
- Giant acceptance/spec blocks that turn the PR into a second spec document

**External ecosystem lessons captured**
- GitHub PR template guidance favors compact purpose/description over pasting full issue content.
- Renovate and Dependabot expose bounded PR-body sections instead of raw source dumps.

### 3. Repo-fitting context

**Question:** What extra operational context belongs in the PR handoff?

**Approaches considered**
- Minimal branch/base only
- Compact repo-fitting context
- Warning/narrowing context in body
- Rich machine metadata

**Recommendation**
- Keep the body human-first.
- Include branch/base facts.
- Keep exactly one lightweight provenance marker, preferably `kiln-run: <run_id>`.
- Do not expose `attached_repo_id` as a naked internal identifier.
- Only mention warning/narrowing context when it materially explains the final narrowed result or links to a concrete related object.

**Why**
- Highest reviewer usability with enough auditability
- Avoids machine-noise and privacy/leakage clutter
- Matches Phase 31’s “one marker, no bot wall” posture

**Rejected defaults**
- Rich machine metadata blocks
- Dedicated warning/preflight section in the PR body
- Duplicate run context plus footer duplication

**External ecosystem lessons captured**
- Human-readable PR summaries outperform metadata-heavy automation comments.
- Good bots keep provenance lightweight and place detailed machine state elsewhere.

### 4. Owning proof contract

**Question:** Should Phase 35 keep the existing proof command or create a new proof entrypoint?

**Approaches considered**
- Extend existing `mix kiln.attach.prove`
- New Phase-35-specific proof command
- Multiple direct test invocations with docs as orchestration
- Command plus generated proof artifact/report

**Recommendation**
- Keep `mix kiln.attach.prove` as the sole owning proof contract.
- Extend it only with the minimum additional locked proof layer or layers needed for `TRUST-04` and `UAT-06`.

**Why**
- One obvious path is the best DX
- Most idiomatic Mix/Phoenix fit
- Preserves the repo’s existing attach-proof contract and avoids ownership split

**Rejected defaults**
- New Phase-35 proof command
- Shell-snippet ownership path
- Artifact-owned verification contract

**External ecosystem lessons captured**
- Mix tasks, cargo `xtask`, and npm script ecosystems all reward one stable top-level entrypoint over proliferating near-duplicate commands.
- Footgun to avoid: docs becoming the source of truth instead of code.

## Coherent Recommendation Set

The recommendations were intentionally synthesized to work together:

- The PR body stays compact and human-first.
- The request framing is explicit enough to bound review without turning the PR into a spec dump.
- Proof is concrete and rerunnable through one obvious Mix command.
- Repo context remains useful, but machine noise stays out of the visible handoff.
- Defaults are pushed left; operator interruptions remain reserved for high-impact trust, scope, or safety changes.

## Locked Defaults Captured For CONTEXT.md

- `Verification` cites `MIX_ENV=test mix kiln.attach.prove` plus exact delegated proof layers.
- PR body uses `Summary` + `Acceptance criteria` + conditional `Out of scope`.
- PR body includes branch/base facts and one `kiln-run:` provenance marker.
- `attached_repo_id` stays out of the visible PR body unless replaced by a meaningful operator-facing link in a future phase.
- Phase 34 warning/narrowing context is not replayed into the PR unless it materially explains the final narrowed result.
- `mix kiln.attach.prove` remains the sole owning proof command and may be minimally extended, not replaced.

## Deferred Ideas

- Artifact/run-linked verification citations in PR text
- A dedicated Phase-35-specific proof command
- Full request markdown dumps in the PR body
- Rich metadata blobs or generated machine-state sections in the visible PR
- PR-body replay of advisory preflight details as a default

---

*Generated from research-backed discuss-phase synthesis on 2026-04-24*
