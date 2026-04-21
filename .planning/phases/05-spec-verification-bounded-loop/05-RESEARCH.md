# Phase 5 — Research: Spec, Verification & Bounded Loop

**Mode:** ecosystem (implementation-oriented)  
**Date:** 2026-04-21  
**Inputs:** `.planning/REQUIREMENTS.md` (SPEC-01..04, ORCH-05/06, OBS-04, UAT-01/02), `05-CONTEXT.md`, `.planning/STATE.md`, existing `Kiln.Runs.Transitions`, `Kiln.Policies.StuckDetector`, sandbox/CAS patterns from Phases 1–3.

**Confidence legend:** **High** = aligned with project decisions + primary docs; **Medium** = standard practice with one implementation choice to lock in plan; **Low** = needs product/ops input.

---

## Standard Stack

Use these; do not swap for parallel stacks without an ADR.

| Area | Prescriptive choice | Confidence |
|------|---------------------|------------|
| Scenario IR + validation | **YAML (or JSON) inside markdown fenced blocks**, validated at parse time with **JSV** (same boundary style as workflow + audit payloads). | **High** (matches `STACK.md`, Phase 2 JSV usage, `05-CONTEXT` D-S01a). |
| Deterministic oracle | **`mix test`** as the single command inside the sandbox workspace; treat **non-zero exit** as fail. Same invocation shape in **CI** (`mix check` → `mix test`) and in Kiln Verifier. | **High** ([Mix.Tasks.Test](https://hexdocs.pm/mix/Mix.Tasks.Test.html): failures default to exit status **2**; `--exit-status`, `--warnings-as-errors`, and `--cover` change codes — document the exact flags Kiln pins so UI and audits map exit codes consistently). |
| Unit / property tests around compilation | **ExUnit** for parser/compiler tests; **StreamData** optional for IR fuzzing. | **High** |
| Spec storage | **Ecto + Postgres** for `spec` / `spec_revision` (names TBD), append-only revisions, `scenario_manifest_sha256` (or equivalent) on revision. | **High** (`05-CONTEXT` D-S01c) |
| Holdout storage | **`holdout_scenarios` table** + **CAS** for large bodies; references only from holdout rows. | **High** (D-S02a) |
| DB enforcement for SPEC-04 | **`REVOKE` / narrow role** so runtime `kiln_app` cannot `SELECT` holdouts; verifier path uses **separate DB role** (dedicated Repo or `SET ROLE` in a narrowly scoped connection) — **not** “trust the app layer alone.” | **High** (PostgreSQL privilege model; matches D-S02b) |
| Verifier narrative | **Anthropic via existing `Kiln.Agents.Adapter`**, **`temperature: 0`, `top_p: 1`** for any model call that could influence structured fields; JSON-only for machine-consumed shapes. | **High** (roadmap + `05-CONTEXT` D-S03e) |
| Caps + idempotency | **`external_operations`** intent table + **`SELECT … FOR UPDATE`** on `runs` (existing Phase 1–2 pattern). | **High** |
| Stuck signal visibility | **`:telemetry` event** for stuck detector alarm (OBS-04) + **audit** row in same transaction as state. | **High** |
| Zero-manual-QA lint | Extend **`mix check_no_manual_qa_gates`** (currently stub) and keep it in **`.check.exs`**. | **High** |

**Explicit non-stack for v1:** full Cucumber/Gherkin runtime with regex step bindings; cross-language custom scenario binaries (defer until `metadata.language` forces it).

---

## Architecture Patterns

1. **Postgres transaction is the choke point**  
   Every run state change continues through `Kiln.Runs.Transitions.transition/3`: lock run → allow matrix → **policy hooks** → update → audit → commit; PubSub **after** commit. Verifier outcomes, cap breaches, and stuck detection that change `runs.state` must either complete inside this discipline or call `transition/3` with a clearly defined `meta` payload — never silent side updates.

2. **Verifier: deterministic-first, LLM second (SPEC-03)**  
   - **Phase A:** Sandbox runs `mix test` (or pinned equivalent); persist machine result (exit code, junit/log CAS refs) and **commit** pass/fail as the only verdict input to transitions.  
   - **Phase B:** Optional LLM call **after** machine verdict is durable; structured LLM output validated with JSV; **no field** may override machine `verdict`; set `llm_disagreement?: true` when narrative implies pass on machine fail — run still **`failed`**, never **`merged`**.  
   Matches D-S03a–d in `05-CONTEXT.md`.

3. **Holdout isolation (SPEC-04) — defense in depth**  
   Combine **(a)** DB privileges, **(b)** CAS hydration **allowlist** built only from non-holdout artifact SHAs for Planner/Coder/Reviewer stages, **(c)** job args / telemetry carry ids+hashes only, **(d)** provenance tests (connection role + manifest closure + optional xref allowlist for `HoldoutScenario` modules). Matches D-S02a–e.

4. **Bounded autonomy (ORCH-06) — orthogonal counters**  
   Maintain separate notions (D-S04): **wall clock** (DB time vs run start), **governed attempts** (terminal fail/timeout on stages that trigger retry / loop-back), **spend** (confirmed usage). **Precedence:** global halt → wall → governed attempts → spend (D-S04b). Advance counters only on idempotency-safe boundaries (D-S04c).

5. **Stuck detector (OBS-04) vs circuit breaker**  
   **Per-run** sliding window over **stable** `(stage, failure_class)` keys (small versioned enum), stored on `runs` or adjunct row, updated in **same transaction** as the transition that records the failure class — **orthogonal** to `FactoryCircuitBreaker` (cross-run). On terminal `failed` / `escalated`, **abandon** stranded `external_operations` per Phase 1 D-16 (D-S05e).

6. **ORCH-05 loop**  
   Verifier failure transitions back to **planning** with a structured `%VerifierResult{}` (or map coercible to it) attached to audit/work-unit context so the planner is diagnostic-driven, not chat-driven.

---

## Don't Hand-Roll

| Topic | Use instead |
|-------|----------------|
| Natural-language Gherkin matcher + step registry | Structured IR in fenced blocks + codegen to ExUnit (D-S01a). Optional **import** from Gherkin later, not v1 core. |
| Custom mini test runner / JSON “assertions” | `mix test` + exit code; capture junit/xml to CAS if needed. |
| LLM as pass/fail oracle | Machine-only verdict; LLM explain/disagree flags only. |
| “Security” of holdouts via Elixir module visibility only | Postgres **`REVOKE`** + narrow role + hydration allowlist + tests. |
| Collapsing retry caps, token caps, and wall time into one counter | Three budgets + explicit precedence (D-S04). |
| Stuck detection keyed on raw exception strings or model prose | Versioned `failure_class` atoms/enums at classification boundaries (D-S05a). |
| Relying on Oban **unique** for execution-time idempotency | Intent rows + “ambiguous → terminal” rules; Oban unique is insert-time only (existing project invariant). |

---

## Common Pitfalls

1. **`StuckDetector.check/1` inside `Repo.transact` + `GenServer.call`**  
   Today `Transitions` holds **`FOR UPDATE`** on `runs` and then calls `StuckDetector.check/1`, which **`GenServer.call`s** another process. If Phase 5 `handle_call` runs **any** `Repo` query that locks the **same** run row, you risk **self-deadlock** (holding lock in txn process while waiting on GenServer that waits on lock).  
   **Mitigation (pick one in plan):** (a) implement window math as a **pure function** on fields already loaded / passed in `ctx` (no second lock), (b) store deque in **jsonb on `runs`** updated only from the transitioning process, or (c) remove GenServer from the hot `check/1` path and keep singleton only for cron/auxiliary. **Do not** add blind `Repo.get(..., lock: :for_update)` inside `StuckDetector` without proving pool/lock ordering.

2. **`with` + `{:halt, _, _}` not wired in `Transitions`**  
   `StuckDetector` documents `{:halt, :stuck, payload}` → same-tx `:escalated`, but `transition/3` currently matches only `:ok` on that step. Phase 5 must extend the `with`/helper so `{:halt, reason, payload}` routes to an **allowed** `:escalated` transition + audit payload — without double-commit or PubSub-before-commit bugs.

3. **`mix test` exit code semantics**  
   Document pinned flags: e.g. `--warnings-as-errors` shifts failure codes ([Mix.Tasks.Test](https://hexdocs.pm/mix/Mix.Tasks.Test.html)); “no tests” is exit **1** since Elixir 1.7. Verifier must map **exactly** the configured command to `machine.verdict` and never assume “nonzero === 2”.

4. **Programmatic `Mix.Tasks.Test.run/1` inside release**  
   Mix is not loaded in a default **release**; Verifier runs tests **in the sandbox** via **`System.cmd`/MuonTrap** invoking `mix test` with dev/test toolchain in the workspace image — not by calling Mix from the Kiln app node unless you explicitly accept Mix as a runtime dependency (usually **no**). Align with Phase 3 sandbox driver.

5. **Holdout leakage via logs, errors, and crash dumps**  
   Redact holdout bodies from Logger metadata, span attrs, and Oban args (D-S02e). Tests should grep serialized job args / audit payloads for absence of holdout digests.

6. **Flaky “LLM agrees with runner” tests**  
   Disagreement tests should **stub** adapter to return structured “pass”; do not depend on live model behavior.

7. **`check_no_manual_qa_gates` false positives**  
   When expanding beyond stub, scope greps to **code paths that gate automation** (e.g. `Blockers`, LiveView “manual review” copy, `raise` sites), not documentation strings — or maintain an explicit allowlist file to avoid blocking on `TODO` in comments in `priv/`.

---

## Code Examples

### Verdict pipeline (conceptual)

```elixir
# Phase A — machine (authoritative)
{:ok, exit_code, cas_refs} = Sandboxes.run_verifier_tests(run, revision)

machine_verdict = if(exit_code == 0, do: :pass, else: :fail)

{:ok, _} =
  persist_machine_checkpoint(run, %{
    exit_code: exit_code,
    verdict: machine_verdict,
    artifacts: cas_refs
  })

# Only after machine row + audit are durable:
llm = maybe_explain_failure(run, machine_verdict, cas_refs)

verifier_result =
  VerifierResult.build(
    machine_verdict,
    machine: %{exit_code: exit_code},
    llm: llm,
    allow_override: false
  )

# JSV.validate!(verifier_result, "verifier_result_v1.json")
# transition(..., :failed | :merged | :planning, %{verifier_result: ...})
```

### Cap increment (sketch — idempotent edge)

```elixir
Repo.transact(fn ->
  run = Repo.one!(from r in Run, where: r.id == ^run_id, lock: "FOR UPDATE"))

  if governed_attempt_exhausted?(run) do
    {:error, {:escalate, :max_governed_attempts, snapshot(run)}}
  else
    # Only bump when external_op / stage attempt moves to terminal failure — not on duplicate enqueue
    {:ok, run}
  end
end)
```

### Mix task exit convention (existing project pattern)

Custom gates use `exit({:shutdown, 1})` on violation (see Phase 1/2 plan notes for `check_no_*` tasks). Keep **`mix check`** green only when scenarios + lint pass.

---

## Requirement crosswalk (normative IDs)

| ID | Research takeaway |
|----|-------------------|
| SPEC-01 | LiveView editor + revision model + debounced save — use Phoenix **streams** only if listing many child entities; revisions fit **normal assigns** + `stream` for large event lists if needed later. |
| SPEC-02 | Compiler emits **deterministic paths** under workspace; `mix test` target path passed to sandbox. |
| SPEC-03 | Two-phase verifier + JSV + disagreement flag; contract test for runner fail + LLM “pass”. |
| SPEC-04 | DB role split + CAS allowlist + three-layer tests. |
| ORCH-05 | `%VerifierResult{}` in planner input channel (work unit or audit payload). |
| ORCH-06 | Three budgets + `escalated` + diagnostic artifact row in audit. |
| OBS-04 | Sliding window in Postgres + telemetry; watch StuckDetector deadlock note above. |
| UAT-01 | `mix check` runs full suite including holdouts; same tests addressable in sandbox. |
| UAT-02 | Typed blockers only; anything else is Kiln bug — align `BLOCK-01` docs with scenario gates. |

---

## Validation Architecture

Phase 5 validation is **machine-oracle first**: the scenario runner’s **process exit code** (via `mix test` with pinned flags documented in `05-VALIDATION.md`) is the acceptance signal for SPEC-02/UAT-01. **JSV** validates structured artifacts at compile time (scenario IR, `VerifierResult` maps) and at REST/LiveView boundaries where applicable. **ExUnit** covers parser/compiler, cap/stuck pure functions, transition wiring, DB privilege tests for holdouts, and the **runner-fail + LLM-pass** disagreement case (adapter stub). **Integration tests** use the existing `SandboxCase` / Docker patterns from Phase 3 for the Verifier command shape (non-release node invoking sandbox). CI runs the **full** scenario slice including holdouts under the same command family as `mix check`. Nyquist sampling: after each plan wave, run the scoped test globs listed in `05-VALIDATION.md`; before phase sign-off, `mix check` must be green.

---

## Open items for `/gsd-plan-phase 5` (not blockers for research)

- Exact fence token (`kiln-scenario` vs generic `yaml`).
- JSV schema filenames: `machine_result_v1`, `verifier_result_v1`.
- Default **K** (window length) for deque before “same class × N” triggers — `05-CONTEXT` suggests 10–20 with **N=3** matches.

---

## RESEARCH COMPLETE

Phase **5** is validated on the roadmap; **`05-RESEARCH.md` did not exist** — this file is the initial research artifact.  

**Suggested next steps:** `/gsd-plan-phase 5` (integrates this doc). If you want a second pass: **Dig deeper** on sandbox image contents for `mix test`, or **Comparison** mode for holdout enforcement (RLS vs role-only).  

**Note:** The attached skill names a `gsd-phase-researcher` subagent type that is not available in this Cursor agent router; research was performed directly in the orchestrator with the same file targets and quality gate.
