# Phase 2: Workflow Engine Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `02-CONTEXT.md` — this log preserves the alternatives considered
> and the research path taken to the final recommendations.

**Date:** 2026-04-19
**Phase:** 02-workflow-engine-core
**Areas discussed:** Workflow YAML shape + signing, Oban queue taxonomy, Stage input-contracts + artifact storage, Run state machine + RunDirector rehydration, Stuck-detector hook point

---

## Area selection

| Option | Description | Selected |
|--------|-------------|----------|
| Workflow YAML shape + signing | Dialect paradigm + signing defer/now call | ✓ |
| Oban queue taxonomy | Per-concern vs per-provider + pool budget | ✓ |
| Stage input-contract + artifacts | Contract location + CAS vs path-based | ✓ |
| State machine + RunDirector rehydration | Matrix scope, API shape, rehydration strategy, stuck-detector hook | ✓ |

**User directive:** "research using subagents, what is pros/cons/tradeoffs of each considering the example for each approach, what is idiomatic for elixir/plug/ecto/phoenix for this type of lib and in this ecosystem, lessons learned from other libs in same space even from other languages/frameworks if they are popular successful, what did they do right that we should learn from, what did they do wrong/footguns we can learn from, great developer ergonomics/dx emphasized... think deeply one-shot a perfect set of recommendations so i dont have to think, all recommendations are coherent/cohesive with each other and move us toward the goals/vision of this project... using great software architecture/engineering, principle of least surprise and great UI/UX where applicable great dev experience."

**Research execution:** Four parallel Opus-4 general-purpose subagents, one per area. Each was briefed with the exact files to read, the decision scope, locked constraints from Phase 1, and a strict return format (executive summary, comparison table, concrete artifact, and deferred questions).

---

## Area 1: Workflow YAML shape + signing

### Dialect options considered

| Paradigm | Pros | Cons | Complexity | Elixir fit | Selected |
|---|---|---|---|---|---|
| **Temporal/Argo-inspired flat `stages: [...]` array with `depends_on: [id]`** | Operator reads top-to-bottom; `depends_on` → adjacency list 1:1 for topological sort; idiomatic for Oban + Ecto; validates cleanly in JSV | Fan-out conditionals need explicit nodes (feature, not bug) | Low | Excellent | ✓ (D-54) |
| GitHub Actions `jobs.<id>: {needs: [...]}` map | Operator-familiar | `${{ }}` expression language = CVE-class injection trap; `if:` drives config-as-code; `strategy.matrix` is a second DAG | Medium | Poor | |
| Tekton/Argo `Pipeline` + `PipelineRun` + `Task` + `TaskRun` | CRD-style separation | 4-kind split for solo-op is pure overengineering; Ecto already owns execution half | High | Poor | |
| Airflow Python DSL | Turing-complete branching | Airflow literally abandoned YAML; proves YAML IS sufficient for fixed-per-version DAGs | — | — | (anti-pattern) |
| Dagster asset-graph / Prefect flows | Elegant for data pipelines | Kiln's unit is agent invocation, not materialized asset | Medium | Poor | |

### Signing options considered

**User's question (verbatim from ROADMAP):** "defer-or-now decision."

| Approach | Selected |
|---|---|
| **Defer to v2 (WFE-02); reserve `signature: null` + `mix check_no_signature_block` CI guard** | ✓ (D-65) |
| sigstore cosign in v1 | Rejected — targets OCI artifacts; shoehorning onto YAML is disproportionate for solo-op |
| GPG detached sigs in v1 | Rejected — every contributor needs GPG configured; v1.1 multi-user would rip it out for sigstore anyway |
| In-YAML `signature:` block in v1 | Rejected — duplicates `git commit -S` + gitsign which we already get for free since workflows live in git |

**Decisive reasoning:** Solo-op local-first means `priv/workflows/` IS the distribution channel — workflows live in the operator's own git repo. Git commit signatures + branch protection + CI is a stronger chain-of-custody than in-YAML signatures. Requirements doc explicitly places WFE-02 in v2.

### Example workflow decision

| Option | Selected |
|---|---|
| Ship one realistic 5-stage workflow + one minimal 2-stage test fixture | ✓ (D-64) |
| Ship only a minimal fixture | Rejected — doesn't exercise the engine's real job |
| Ship only a realistic workflow | Rejected — forces unit tests to carry full workflow overhead |

### Outcome
D-54..D-66 + spec upgrades D-97..D-100. Canonical YAML shape shipped as the artifact.

---

## Area 2: Oban queue taxonomy

### Paradigm options considered

| Paradigm | Pros | Cons | Phase-2 Fit | Selected |
|---|---|---|---|---|
| Per-worker-class (one queue per Worker) | Maximum isolation | GitLab-documented Sidekiq/Redis CPU burn; Oban Web unreadable; poller overhead per queue | Kills debuggability, wastes pool | Reject |
| **Per-concern (stages / github / audit_async / dtu / maintenance / default)** | Sidekiq/GitLab-endorsed; small fixed N; concurrency tuned to downstream resource (Postgres/Docker/gh CLI); clean ORCH-07 mapping | A provider outage inside `:stages` could slow siblings (but OPS-02 fallback handles this first-line) | Best fit for P2 | ✓ (D-67) |
| Per-provider stages queues (`stages_anthropic` / `_openai` / `_google` / `_ollama`) | True HOL isolation | No adapters exist in P2; impossible to test; split with zero payoff; OPS-02 already handles 429 via fallback | Defer to P3 | Defer (D-71) |
| Priority-lane (`critical` / `default` / `low`) | Sidekiq recommended naming | Kiln has one operator, no SLA tiers | Over-engineering for solo | Reject |

### Concurrency math

| Consumer | Peak concurrent checkouts |
|---|---|
| Oban aggregate (P2): stages 4 + audit_async 4 + default 2 + github 2 + dtu 2 + maintenance 2 | **16** |
| Oban plugin overhead (Cron leader election, Pruner) | **2** |
| LiveView + `/ops/*` dashboards | **~2** |
| `RunDirector` boot scan + `StuckDetector` tick | **1** |
| Headroom | **~3** |
| **Total** | **~24** |

**Decision:** `pool_size: 20` (D-68) — defensible because `:stages` wall-clock is dominated by LLM calls, not DB checkouts. Revisit to 28 when provider-split triggers in P3.

### Idempotency key shape options

| Shape | Selected |
|---|---|
| **Business-intent-only (e.g., `"run:#{run_id}:stage:#{stage_id}"`)** — relies on handler-level `SELECT FOR UPDATE` + state assertion for real dedup | ✓ (D-70) |
| Attempt-inclusive (`"run:#{run_id}:stage:#{stage_id}:attempt:#{attempt}"`) | Rejected — defeats retry semantics that BaseWorker already provides |

### Outcome
D-67..D-72. Six queues, `pool_size: 20`, canonical idempotency-key shapes locked.

---

## Area 3: Stage input-contracts + artifact storage

### Part A — Contract location options

| Option | Selected |
|---|---|
| **External JSON Schema files at `priv/stage_contracts/v1/<kind>.json`, compile-time `JSV.build!/2` into `Kiln.Stages.ContractRegistry`** (mirror of P1's `Kiln.Audit.SchemaRegistry`) | ✓ (D-73) |
| Embedded in workflow YAML as JSV sub-schema per stage | Rejected — makes YAML unreadable, `$ref` across YAML sub-schemas awkward at speed |
| Elixir modules owning the contract via `@callback input_schema/0` | Rejected — D-09 precedent is JSON-on-disk; `diff`/`gh` UX stays clean |
| Hybrid | Rejected — pick one |

### Part B — Artifact addressing options

| Option | Selected |
|---|---|
| **Pure content-addressed storage (CAS)** at `priv/artifacts/cas/<sha[0..1]>/<sha[2..3]>/<sha>` | ✓ (D-77) |
| Path-based (`priv/artifacts/<run_id>/<stage_id>/<attempt>/<name>`) | Rejected — pay sha cost anyway for durability-floor integrity-on-read without dedup/immutability benefit |
| Hybrid (path for current-attempt, CAS for retained history) | Rejected — complexity without win; CAS handles both cleanly |

**Decisive reasoning:** SAND-04 mandates immutable diffs (CAS structural). ROADMAP P19 says "content-addressing groundwork" (groundwork that isn't CAS isn't groundwork). Retries producing same bytes = free dedup. v2 object-storage migration becomes one `rsync` command. Bazel/Nix/Git/IPFS/Temporal BlobStore all converged here.

### Context placement options

| Option | Selected |
|---|---|
| **New 13th bounded context `Kiln.Artifacts`** under Execution layer | ✓ (D-79) — requires CLAUDE.md spec upgrade D-97 |
| Fold into `Kiln.Stages` as sub-module | Rejected — CAS invariants (immutability, integrity-on-read, refcounting) are orthogonal to stage execution; forcing them inside `Kiln.Stages` pollutes that context's surface |

### Storage target decision rule (D-82)

| Data shape | Goes in |
|---|---|
| State-machine facts, small structured summaries ≤4 KB | `audit_events.payload` JSONB |
| Diff, log, test output, coverage, plan markdown, any binary | `artifacts` (CAS) |
| Hot-path metrics (tokens_used, cost_usd, actual_model_used) | Dedicated column on `stage_runs`/`runs` |
| Spec body | `specs` table column (intent layer) |

### Outcome
D-73..D-85. New 13th context. Three new audit event kinds. Directory layout + API sketch locked.

---

## Area 4: State machine + RunDirector + Stuck-detector hook

### States to ship in Phase 2

| Option | Selected |
|---|---|
| **8 states: queued/planning/coding/testing/verifying/blocked/merged/failed/escalated** (includes `:blocked` now; Phase 3 adds producers) | ✓ (D-86) |
| 7-state core only, Phase 3 adds `:blocked` | Rejected — one atom in enum + 6 matrix rows; Phase 3 would otherwise need schema migration + matrix rewrite |
| Full state explosion including `:paused` | Rejected — `:paused` (FEEDBACK-01) is v1.5; not v1 scope per PROJECT.md |

### API shape

| Option | Selected |
|---|---|
| **Tuple default `{:ok, run} \| {:error, reason}` + raising `!` variant** | ✓ (D-88) |
| Raising default + non-raising variant | Rejected — raising inside Oban worker burns attempt + noisy backtrace; worker needs to decide retry vs escalate |

### RunDirector rehydration strategy

| Option | Selected |
|---|---|
| **Boot scan + `{:DOWN, ...}` reactive + 30s defensive periodic scan** (belt-and-suspenders) | ✓ (D-92) |
| Boot scan + `{:DOWN, ...}` reactive only | Rejected — node-restart race can deliver subtree collapse without DOWN reaching replacement `RunDirector` |
| Periodic scan only (no DOWN) | Rejected — up to 30s lag on subtree collapse detection |

### Concurrency knobs

| Knob | Value | Why |
|---|---|---|
| `RunSupervisor.max_children` | 10 | Matches pool budget; solo-op ceiling |
| Periodic scan interval | 30s | Imperceptible operator lag; closes DOWN race |
| Rehydration retry | 3 attempts, 5/10/15s backoff | Matches BaseWorker envelope |
| `RunDirector` restart | `:permanent` + `:one_for_one` parent | Stateless rehydration = safe to restart |

### Stuck-detector hook placement

| Option | Selected |
|---|---|
| **No-op `Kiln.Policies.StuckDetector` GenServer in P2 supervision tree; `check/1` called inside `Transitions.transition/3` after row lock, before state update** | ✓ (D-91) |
| Reserve module name only, no GenServer in P2 | Rejected — ROADMAP P2 explicitly mandates "P1 hook point wired"; the hook path IS the Phase 2 behavior-to-exercise |
| Ship full sliding-window impl in P2 | Rejected — Phase 5 owns OBS-04 |

### Workflow checksum on rehydration

| Option | Selected |
|---|---|
| **Assert `runs.workflow_checksum` matches current `priv/workflows/<id>.yaml` compiled-graph checksum; mismatch → escalate with `:workflow_changed`** | ✓ (D-94) |
| Silent re-hydration against whatever YAML is on disk | Rejected — would let an in-flight run silently execute against a mutated graph |

### Outcome
D-86..D-96. Matrix as module attribute. Tuple API. RunDirector skeleton. StuckDetector hook wired as pre-condition. Checksum integrity on rehydration.

---

## Cross-cutting cohesion decisions Claude made during synthesis

These emerged from reconciling the four independent research agents' outputs:

1. **`Kiln.Artifacts` = 13th bounded context** — Agent 3's call. Requires CLAUDE.md spec upgrade (D-97). Alternative of folding into `Kiln.Stages` was rejected because CAS invariants are orthogonal to stage execution.
2. **Schema file layout parallel to P1's `priv/audit_schemas/v1/`** — `priv/workflow_schemas/v1/workflow.json` + `priv/stage_contracts/v1/<kind>.json`. Consistent, discoverable, diffable.
3. **Stage shape `id` + `kind` + `agent_role` (no separate `input_contract:` field)** — `kind` auto-resolves the contract path. Drops Agent 1's redundant `input_contract:` field.
4. **`pool_size: 20` + `RunSupervisor.max_children: 10` compose correctly** — 10 hydrated runs × up-to-4 simultaneously-dispatched stages ≤ 20 checkouts.
5. **StuckDetector no-op GenServer sanctioned by ROADMAP P2 "hook point wired" language** — deliberate D-42 exception, documented inline.

## Claude's Discretion

Listed in `02-CONTEXT.md` under `<decisions>` § Claude's Discretion (D-87..D-100 leftovers):
- Exact file names within context directories
- YAML field ordering in example workflow
- Internal helper module sub-names
- Minimal fixture content beyond "2 stages, pass-through, one edge"
- Exact operator-facing error message text (must include from/to/allowed substrings)
- Concurrency numbers within ±1 if measurement shows a better default
- Oban plugin order in config
- Internal RunDirector state representation
- Test fixture layout
- Whether `Kiln.Artifacts.GcWorker` is a GenServer + `send_after` or an Oban Cron entry

## Deferred Ideas

Captured verbatim in `02-CONTEXT.md` `<deferred>` section. Highlights:
- Workflow YAML signing → v2 (WFE-02) with reserved key + CI guard
- Provider-split Oban queues → Phase 3 with hard trigger
- `:paused` state → v1.5 (FEEDBACK-01)
- Conditional fan-out / foreach → Phase 3+
- Compression/replication of artifacts → v2+
- PARA-01 concurrent-run scheduler → v2
- `:blocked` producers → Phase 3 (matrix edge wired in P2)
- Stuck-detector sliding-window body → Phase 5 (hook wired in P2)
