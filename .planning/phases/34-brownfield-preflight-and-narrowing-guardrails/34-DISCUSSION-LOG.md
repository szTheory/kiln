# Phase 34: Brownfield preflight and narrowing guardrails - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 34-brownfield-preflight-and-narrowing-guardrails
**Areas discussed:** conflict coverage, block vs warn policy, scope-collision heuristic, narrowing guidance UX

---

## Conflict coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Extend hard gate only | Put all new repo-state and overlap logic into `SafetyGate` as blockers | |
| Layered preflight | Keep deterministic hard gate, then add typed advisory brownfield preflight for warnings/narrowing | ✓ |
| Single unified report now | Replace binary gate immediately with one full report surface | |
| Deep predictive collision analysis | Try semantic/file-level prediction early | |

**User's choice:** Use the recommended cohesive posture across all areas rather than deciding each tradeoff manually.
**Notes:** Strong preference for least surprise, strong defaults, good architecture, and low operator interruption unless the choice materially affects risk or outcome.

---

## Block vs warn policy

| Option | Description | Selected |
|--------|-------------|----------|
| Binary block-or-pass | Keep only ready vs blocked | |
| Typed severity findings | Use `:fatal`, `:warning`, and `:info` while blocking only on unsafe/ambiguous conditions | ✓ |
| Score/confidence-first model | Lead with numeric confidence or risk scoring | |

**User's choice:** Adopt the recommended typed-severity model.
**Notes:** Warnings should remain visible and actionable, but should not block unless the repo state or mutation target is unsafe or ambiguous.

---

## Scope-collision heuristic

| Option | Description | Selected |
|--------|-------------|----------|
| Exact structural match only | Catch near-identical requests with low false positives | |
| Same-repo lexical + state-aware heuristic | Compare normalized request text against recent same-repo drafts/requests/runs and boost concern for active/open work | ✓ |
| Deep semantic/LLM overlap analysis | Infer true intent equivalence across repo history | |

**User's choice:** Use the recommended same-repo bounded heuristic.
**Notes:** The heuristic must stay explainable, avoid semantic bravado, and never widen beyond one `attached_repo_id`.

---

## Narrowing guidance UX

| Option | Description | Selected |
|--------|-------------|----------|
| Inline warning only | Show a small warning above the form | |
| Dedicated narrowing panel | Show a distinct non-fatal state with suggested narrower request and edit path | ✓ |
| Multi-step remediation wizard | Force a guided multi-step narrowing flow | |

**User's choice:** Use the recommended dedicated narrowing state.
**Notes:** The default should be one recommended narrower request. The operator can edit manually, but Kiln should not make them infer what to do next.

---

## the agent's Discretion

- Final module/report names
- Exact heuristic normalization details
- Exact wording/layout of the warning panel
- Exact test slice boundaries, as long as the deterministic-vs-heuristic split stays intact

## Deferred Ideas

- Broader GSD-wide default/interaction tuning beyond this attach-phase scope
- Deep semantic overlap analysis
- Cross-repo collision detection
- Approval-gate UX
- Draft PR handoff polish owned by Phase 35
