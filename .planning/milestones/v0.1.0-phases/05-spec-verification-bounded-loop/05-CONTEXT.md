# Phase 5: Spec, Verification & Bounded Loop - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning (`/gsd-research-phase 5` — HIGH flag per ROADMAP → then `/gsd-plan-phase 5`)

<domain>
## Phase Boundary

The dark-factory loop closes on **truth in Postgres + deterministic checks in the sandbox**: an operator authors a **versioned markdown spec** with embedded **structured** scenarios in LiveView; each revision **compiles** to an **ExUnit-backed** (or `mix test` entrypoint) bundle whose **process exit code** is the **sole** pass/fail oracle (UAT-01). The Verifier stage runs that bundle inside the existing **ephemeral Docker sandbox** contract; an optional **LLM explanation** runs **after** the machine verdict is persisted and **cannot** override it—including the mandatory disagreement case (runner fail + LLM “pass” → still `failed`). **Holdout scenarios** (SPEC-04) live behind **DB privilege + CAS hydration allowlist + provenance tests** so Planner/Coder/Reviewer never receive holdout bodies or digests at compile or execution time. **Bounded autonomy** (ORCH-06) uses **orthogonal budgets** (wall clock, governed stage attempts, spend) with explicit **precedence** and **idempotent replay** rules; **stuck-run detection** (OBS-04) keys a **sliding window** on stable `(stage, failure_class)` tuples in **Postgres**, updated in the **same transaction** as run transitions—**separate** from the **global** `FactoryCircuitBreaker`. **Zero-human-QA** enforcement is completed by tightening `mix check_no_manual_qa_gates` and running the full scenario suite (including holdouts) in CI. Git/PR/Actions, polished run board, and intake/onboarding remain **out of scope** (Phases 6–8).

</domain>

<decisions>
## Implementation Decisions

### Scenario format & deterministic runner (D-S01)

- **D-S01a — Canonical author format:** Spec body remains **markdown**; executable scenarios live in **fenced blocks** (e.g. fenced as `kiln-scenario`) whose inner payload is **structured** (YAML or JSON), **JSV-validated** at parse time. Human-readable `Given` / `When` / `Then` lines may appear inside step `description` fields for readability, but **semantics** are data—not regex-matched Gherkin step tables (avoids Cucumber-style drift and flake).
- **D-S01b — Oracle process:** Compile each `spec_revision` to **ExUnit** modules (or a single `mix test` target) under a **deterministic path** keyed by revision id; the Verifier stage runs **`mix test`** (or an equivalent single command) **inside the sandbox** and treats **only** `exit_code == 0` as pass. Same command shape in **CI** and in **Kiln** for least surprise.
- **D-S01c — Revision linkage:** Persist **`scenario_manifest_sha256`** (or equivalent) on the spec revision row so every verifying stage joins **exact bytes verified** to audit/run metadata.
- **D-S01d — DX:** Parser errors return **line:column** into the editor; tags (`@moduletag :kiln_scenario`, `:smoke`, etc.) gate fast vs full CI slices.

### Holdout isolation & provenance (D-S02)

- **D-S02a — Storage:** `holdout_scenarios` table (+ large bodies as **CAS** blobs referenced only from holdout rows if needed). Never place holdout digests on `artifacts` rows visible to non-verifier stage inputs.
- **D-S02b — DB privilege:** `REVOKE SELECT` on `holdout_scenarios` (and holdout-only CAS keys if modeled separately) from **`kiln_app`**. Introduce or use a **narrow DB role** available **only** on the verifier worker code path for `SELECT` of holdouts.
- **D-S02c — CAS manifest:** Sandbox `/workspace` hydration uses an **explicit allowlist of artifact SHAs** built from **non-holdout** inputs only; holdout digests are **ineligible** for mount/hydration.
- **D-S02d — Provenance tests (three layers):** (1) integration test: session as `kiln_app` **must fail** `SELECT` from holdouts; (2) manifest closure: compiled bundle / env / `docker inspect` path must **not** contain holdout text or digests; (3) optional **xref or compile-time allowlist**: only `Kiln.Specs.Verification*` (exact module set TBD in plan) may reference `HoldoutScenario` schema/modules.
- **D-S02e — Oban/telemetry:** Job args carry **ids + hashes**, never scenario bodies; redact span attributes and logs.

### Verifier result struct & LLM explain-only (D-S03)

- **D-S03a — Two-phase pipeline:** **Phase A** runs machine, normalizes output to a map, validates with **JSV** (`machine_result_v1` schema TBD in plan). **Phase B** (LLM) runs **only after** machine verdict + checkpoint are **persisted** (append-only fact or row update in same txn as transition rules allow).
- **D-S03b — `%VerifierResult{}`:** Fields at minimum: `verdict` (`:pass | :fail | :error`), `machine` (exit_code, failing test ids, summary), `artifacts` (refs to log/junit/diff CAS), `llm` (status, optional `structured` map, optional `narrative`, `disagreement?`). Invariant: **`allow_override: false`** enforced in code and tests.
- **D-S03c — LLM I/O:** Require **JSON mode** for machine-consumed fields; schema **forbids** any field that could be read as overriding `verdict`. Free-form `narrative` allowed but not parsed for branching.
- **D-S03d — Disagreement case:** If LLM structured output implies pass when machine failed → set `llm_disagreement: true`, **`verdict` remains fail**, UI shows explicit banner (“Runner failed; model narrative disagrees”).
- **D-S03e — Audit:** Append audit in the **same Postgres transaction** as the stage transition; machine fields **immutable** after insert; large LLM payloads → **CAS** + ref in payload.

### Bounded autonomy caps (D-S04)

- **D-S04a — Three budgets (do not collapse):** (1) **Wall:** `max_elapsed_seconds` from run start using **DB `now()`** semantics; (2) **Governed attempts:** increments on **terminal failure or timeout** of a stage execution that triggers **retry or loop-back** (align with workflow `retry_policy` + ORCH-05 planner loop); (3) **Spend:** confirmed tokens/USD from provider usage (extends BudgetGuard philosophy).
- **D-S04b — Precedence:** Global halt → **wall** → **governed attempts** (`max_retries` / dedicated cap fields) → **USD/tokens**.
- **D-S04c — Idempotency:** Stripe-style: **no** cap decrement for duplicate idempotent replays of the same logical attempt; advance counters only when `external_operations` / stage-attempt moves **ambiguous → terminal** or usage is **confirmed**—under **`SELECT … FOR UPDATE`** on `runs`.
- **D-S04d — Escalation artifact:** On cap breach, transition to **`escalated`** (per roadmap) with diagnostic artifact: which cap, counter snapshot, last N `(stage, failure_class)`, `correlation_id`, artifact links—never silent continue.

### Stuck detector vs global circuit breaker (D-S05)

- **D-S05a — Failure class:** Small **versioned enum** / atom set derived at classification boundaries (provider family, verifier outcome, sandbox OOM, etc.)—**never** raw exception strings or model prose as keys.
- **D-S05b — Window:** Maintain last **K** `(stage_ref, failure_class)` events per run in **Postgres** (jsonb on `runs` or adjunct table), updated **inside the same transaction** as `Kiln.Runs.Transitions`. If count of same tuple **≥ N** (default **3**, overridable per workflow in `spec.caps` extension TBD in plan) within window → **`escalated`** + `stuck_detector_alarmed` audit + `:telemetry`.
- **D-S05c — Reset policy:** Decay/reset window on meaningful progress: successful stage advance, verifier pass, and/or transition to a **different** high-signal failure class (exact table TBD in plan).
- **D-S05d — Global breaker:** `FactoryCircuitBreaker` remains **cross-run** (provider/cost/infra); **gates enqueue or backoff**, does **not** subsume per-run stuck logic.
- **D-S05e — Orphan intents:** On terminal `failed`/`escalated`, mark stranded `external_operations` as **`abandon`** per Phase 1 D-16 so Oban does not fight a finished run.

### Spec editor LiveView UX (D-S06)

- **D-S06a — Route:** Dedicated **`/specs/:id/edit`** (full page), not a modal primary editor.
- **D-S06b — Save model:** Debounced autosave **2–4s** + blur + **Cmd/Ctrl+S** flush; visible states: **Saved / Saving / Unsaved / Error** + `last_saved_at`.
- **D-S06c — Versions:** Append-only **revision rows**; timeline + read-only snapshot + **diff** between revisions; restore = **new** revision copying old content (history immutable).
- **D-S06d — Validation gate:** Primary “Run verify” (or equivalent) **disabled** until parser + JSV pass; preview pane uses the **same** parse module as the compiler (**one grammar**).
- **D-S06e — Brand:** Inter + IBM Plex Mono in editor; microcopy per brand book (“Saved”, “Syntax error at line N”, “Unsaved changes”).

### Claude's Discretion

- Exact fenced delimiter string (`kiln-scenario` vs generic), JSV file names for `machine_result_v1`, default K window size (10–20) for stuck deque, and whether codegen writes one file vs many under `priv/generated/scenarios/`.
- Fine-grained `failure_class` enum list beyond the taxonomy principle above.

### Folded Todos

- None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements

- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, research flags (bounded autonomy, holdout access control), pitfalls P1/P2/P7/P10.
- `.planning/REQUIREMENTS.md` — SPEC-01..SPEC-04, ORCH-05, ORCH-06, OBS-04, UAT-01, UAT-02 (normative IDs).
- `.planning/PROJECT.md` — Core value, zero-human-QA, bounded autonomy principles, out-of-scope boundaries.

### Prior phase decisions (carry-forward)

- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — Audit taxonomy including `scenario_runner_verdict`, `stuck_detector_alarmed`, `external_operations` states (`abandon` for Phase 5), `mix check_no_manual_qa_gates` stub (D-26).
- `.planning/phases/02-workflow-engine-core/02-CONTEXT.md` — Workflow `spec.caps`, `StuckDetector` hook in `Transitions`, stage contracts `holdout_excluded`, verifying-stage loop edges, Oban maintenance queue for StuckDetector cron placeholder.
- `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md` — Sandbox CAS hydration/harvest, `FactoryCircuitBreaker` scaffold, `BudgetGuard`, `QAVerifier` stub, DTU deferrals for Phase 5 chaos.

### Operator experience

- `prompts/kiln-brand-book.md` — Typography, palette, voice, microcopy for spec editor surfaces.

### Optional research anchors

- `.planning/research/STACK.md` — Elixir/Phoenix/Ecto/Oban versions if implementation touches new deps (only if plan requires).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/kiln/runs/transitions.ex` — `StuckDetector.check/1` hook point; extend with cap checks + stuck window evaluation inside existing transaction discipline.
- `lib/kiln/policies/stuck_detector.ex` — GenServer scaffold; Phase 5 replaces no-op body with policy fed by DB facts / telemetry triggers per D-S05.
- `lib/kiln/policies/factory_circuit_breaker.ex` — Global breaker; keep orthogonal to per-run stuck (D-S05d).
- `lib/kiln/agents/roles/qa_verifier.ex` — Stub role module; Phase 5 implements Verifier orchestration (sandbox invoke + result persistence).
- `lib/kiln/stages/next_stage_dispatcher.ex` — Sets `holdout_excluded` on stage inputs; compiler must never attach holdout refs for non-verifier kinds.
- `lib/kiln/agents/budget_guard.ex` — Precedent for spend checks before LLM calls; extend pattern to cap orchestration for D-S04c.
- `lib/kiln/specs.ex` — Placeholder context to be replaced by real `Kiln.Specs` + scenarios modules.
- `lib/kiln/artifacts/*` — CAS for logs, diffs, generated test bundles, LLM explanation blobs.
- `lib/kiln/external_operations.ex` — `abandon_op/2` and intent lifecycle for cap + stuck coordination.

### Established Patterns

- **Postgres transaction + audit append** for every state transition (Phases 1–2); Verifier and cap/stuck outcomes must follow the same pattern.
- **JSV at boundaries** (audit, workflow load, stage contracts); scenario IR and `VerifierResult` payloads should use the same validation style.
- **Sandbox invocation** via `MuonTrap` + Docker driver (Phase 3); scenario runner executes as another sandboxed command with identical egress and tmpfs rules.

### Integration Points

- `KilnWeb` router — mount `SpecEditorLive` (names TBD) at `/specs/:id/edit`.
- `Kiln.Application` — optional Oban cron for maintenance-queue stuck scan if not purely transition-driven.
- `mix check` / `.check.exs` — wire full scenario suite + flesh `mix check_no_manual_qa_gates` beyond stub.

</code_context>

<specifics>
## Specific Ideas

- Subagent research consensus: prefer **`mix test` exit code** as the industry-familiar oracle over a bespoke runner binary unless sandbox constraints force a thin wrapper.
- CI must not treat “retry until green” as truth; caps and stuck detector exist to catch retry storms (Kubernetes `backoffLimit` / Temporal limits lessons).
- UI explicitly surfaces **LLM vs runner disagreement** without implying the LLM can unblock the run.

</specifics>

<deferred>
## Deferred Ideas

- **Crypto envelope for holdouts at rest** — defer unless multi-tenant or hosted runtime appears on roadmap.
- **Raw Gherkin + step-definition layer** — optional future import only; not v1 core per D-S01a.
- **Cross-provider scenario runner binary** (Rust/Go) — only if ExUnit-in-sandbox proves insufficient for non-Elixir language targets; revisit with workflow `metadata.language`.

### Reviewed Todos (not folded)

- None from `todo.match-phase` (tool unavailable in capture session).

</deferred>

---

*Phase: 05-spec-verification-bounded-loop*
*Context gathered: 2026-04-21*
