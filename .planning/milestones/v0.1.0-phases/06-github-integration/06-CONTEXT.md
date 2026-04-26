# Phase 6: GitHub Integration - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Kiln **closes the loop in git and GitHub** with **durable, idempotent** side-effects: **`System.cmd("git", …)`** for commit/push with **`git ls-remote` preconditions**, **`gh`** for PR creation, and **checks observation** so the Verifier can drive **`merged`** vs **loop-back to Planner with CI diagnostics** — all through **`external_operations`** (GIT-01..03), **typed blocks** for auth/permission failures (GIT-01 / BLOCK-01), and **no silent infinite retry**. UI polish and onboarding live in later phases; this phase ships **`Kiln.Git`**, **`Kiln.GitHub`**, and the **Oban workers** wired to the existing intent table and audit taxonomy.

</domain>

<decisions>
## Implementation Decisions

### Merge gate: Actions → `merged` (D-G01..D-G04)

- **D-G01 — Primary predicate:** Transition to **`merged` only when all checks GitHub marks as **required** for the **PR base branch** (branch protection / rulesets) have completed successfully on the **exact PR head SHA** (or merge-group SHA if the workflow explicitly opts into merge-queue semantics later). This matches **least surprise** with the GitHub merge bar and ROADMAP SC3 (pass → `merged`).
- **D-G02 — Not the default:** Do **not** use “every check run is green” as the sole rule — optional/flaky/informational apps must not block shipping. **Allowlists** of workflow/check names (from workflow YAML or Kiln config) are an **optional supplement**: “also require X” or “only trust these” for advanced repos — never the only source of truth unless the operator documents **no** branch protection (discouraged).
- **D-G03 — Skipped / neutral / stale:** **Required** checks must be **`success`**. For **non-required** checks: **`skipped` / `neutral` / `cancelled`** do not block `merged`. **`action_required`** (e.g. pending manual approval app) blocks `merged` if that check is **required**; if optional, ignore. Persist the **check run IDs + conclusions** used for the decision in the same Postgres transaction as the transition (replay-stable predicate).
- **D-G04 — Draft PRs:** **Do not** transition the run to **`merged` while the PR is **draft** unless the workflow sets **`allow_merge_while_draft: true`** (default **`false`**). CI may still run for signal; the merge predicate is false until **ready for review** (or the explicit override).

### PR creation defaults (D-G05..D-G08)

- **D-G05 — Artifact-first `gh` args:** **`gh pr create` arguments are a pure function of persisted inputs**: workflow PR-stage config + **frozen run artifacts** (title/body/base/reviewers/draft flag). Matches **GIT-02** and auditability; idempotency uses **stored GitHub PR number/URL** after first success, not title search.
- **D-G06 — Defaults:** **`--draft` default `true`** (operator explicitly flips to ready when comfortable). **`--base`**: workflow field, else **`gh repo view --json defaultBranchRef`** (or equivalent) once per op and cache in intent payload. **Reviewers:** empty unless **explicit list** in workflow (no surprise pings).
- **D-G07 — Title/body:** **Structured template** with slots resolved from artifacts (e.g. run id, spec revision id, verifier summary link, artifact CAS refs). **No LLM-in-the-loop** at `gh` invocation in v1; any narrative is produced **upstream**, **materialized as artifacts**, then consumed here (optional later “hybrid YAML templates” without changing idempotency shape).
- **D-G08 — Audit:** Record **intent payload hash**, **`gh` JSON output** on success, exit code, and stable ids — never secrets (SEC-01). PR body includes **opaque ids + links** to Kiln-held artifacts, not raw env or tokens.

### Check observation / polling (D-G09..D-G12)

- **D-G09 — v1 transport:** **Polling only** via **`CheckPoller`** (no GitHub webhooks in v1 — avoids public ingress; upgrade path documented). Combine REST calls efficiently (suite → runs); optionally respect **ETag** where helpful.
- **D-G10 — Schedule shape:** **Hybrid + jitter**: shorter intervals early (e.g. 15–20s first few polls), then backoff toward a **cap** (e.g. 60–120s) with **jitter** to desync concurrent runs. **Self-reschedule** via Oban `schedule_in` while checks are pending and run policy allows — do not burn **`max_attempts`** for “CI still running”; reserve Oban retries for **crashes / transient 5xx / 429** with clear payload distinction.
- **D-G11 — Absolute deadline:** Every run in **`verifying`** has a **max wall-clock for CI observation** tied to **bounded autonomy** (ORCH-06) / workflow caps. When exceeded → **typed block** or **`escalated`** with diagnostic (last poll snapshot, deadline) — **never** unbounded poll loops. **`external_operations` `gh_check_observe`**: one logical intent per `(run, suite_or_sha key)`; terminal completion when predicate satisfied or policy stops; **401/403 auth** → immediate **typed block**, no reschedule until remediation.
- **D-G12 — Rate limits:** On **403 secondary limits** or low **`x-ratelimit-remaining`**, widen interval and/or coordinate with **factory-level backoff** (`FactoryCircuitBreaker` pattern); do not per-run spin faster.

### Git commit identity & messages (D-G13..D-G15)

- **D-G13 — Identity:** **Stable Kiln bot** for **both author and committer** (e.g. `Kiln Bot <kiln@users.noreply.github.com>` or project-configured **noreply** address). **Do not** impersonate the operator’s personal email for autonomous commits (avoids false “human wrote this” and DCO theater). Optional **future** `KILN_GIT_AUTHOR_EMAIL` override remains **explicit opt-in**, not default.
- **D-G14 — Message shape:** **Conventional Commits** subject: `feat|fix|chore(kiln): …` scoped by workflow. **Body:** short human summary line + **trailers**: `X-Kiln-Run-Id`, `X-Kiln-Stage-Id`, `X-Kiln-Spec-Revision` (or equivalent fixed set). **No** `Signed-off-by` / `Co-authored-by` unless a **human** actually co-authored (never auto-injected). **No secrets** in subject/body (SEC-01); rich detail stays in **Postgres audit + CAS artifacts**.
- **D-G15 — Signing:** **Unsigned commits in v1** unless a later phase adds **dedicated bot signing keys** with a clear threat model (signing proves possession, not correctness — avoid operational drag for solo v1).

### Push races & non-fast-forward (D-G16..D-G19)

- **D-G16 — Preconditions:** Every push path uses **`git ls-remote`** + **compare-and-swap** intent: record **expected remote tip SHA** in `external_operations` metadata; if remote already equals **target branch → desired commit**, **no-op success** (idempotent). Push only when CAS matches.
- **D-G17 — Default integration policy:** **`fail_fast`** — on **non-fast-forward** or unexpected remote movement → **typed terminal** (`:git_non_fast_forward` / `:git_remote_advanced` / `:git_push_rejected`) with **remediation playbook** (fetch, rebase locally, or reset run workspace) — **no automatic rebase** by default (least surprise + avoids “verified the wrong parent”).
- **D-G18 — Optional bounded autonomy (workflow opt-in):** Workflow may set **`git.integration_strategy: :rebase_with_retry`** with **`max_integration_attempts`** default **2**, hard cap **3**. Each attempt: **fetch → rebase** (only if working tree clean) → **re-run applicable verification gate** for the new parent set before push — if **conflict** → **`:git_rebase_conflict`** typed block. Count attempts against **bounded autonomy**; exhaustion → **`:git_autonomy_budget_exhausted`** or escalation per ORCH-06.
- **D-G19 — Oban vs semantics:** **Never** rely on Oban **`max_attempts`** alone for semantic retry loops; **attempt counters live in DB** (`external_operations` payload or run row) with **monotonic state** so killed workers cannot spawn unbounded pushes.

### Cross-cutting: coherence with Phases 1–5

- **D-G20 — Checks + legacy status:** If a repo still uses **commit statuses** without Checks, either **document “Checks-only v1”** and surface **typed block** with playbook, or implement a **thin adapter** that ORs required **combined status** with required **check runs** — pick one in plan and test; avoid silent “merged” with unseen red legacy status.
- **D-G21 — GitHub merge queue / Mergify:** If the repo uses **merge queue** or **auto-merge bots**, treat **external merged** events as **reconciliation inputs** in a later plan slice if needed; v1 predicate remains **required checks on head** + **draft policy** above — document **known race** if GitHub merges before Kiln transitions (audit + polling reconciliation).
- **D-G22 — DX surfaces:** Operator sees **next poll time**, **deadline**, **merge predicate explanation** (“2/2 required checks passed”), and **copy-paste `gh`/`git` hints** in typed blocks — aligns Phase 8 unblock panel without blocking Phase 6 APIs.

### Claude's Discretion

- Exact default numeric constants (initial poll interval, max interval, jitter fraction, CI observe wall-clock as fraction of run cap) — set in plan from staging profile + one integration test timing budget.
- Whether to ship **legacy status adapter** in v1 or Phase 6.1 — default **document + block** unless dogfood repo needs it on day one.

### Folded Todos

- None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements

- `.planning/ROADMAP.md` — Phase 6 goal, success criteria (idempotent push/PR, checks → merged, typed failures), artifacts list.
- `.planning/REQUIREMENTS.md` — GIT-01, GIT-02, GIT-03, BLOCK-01 (`:gh_auth_expired`, `:gh_permissions_insufficient`), ORCH-07, SEC-01, UAT-02.
- `.planning/PROJECT.md` — Core value, solo operator, Postgres truth, no human in the loop, bounded autonomy.

### Prior phase context

- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — `external_operations` op_kind (`git_push`, `git_commit`, `gh_pr_create`, `gh_check_observe`), idempotency key shape, audit event kinds (`git_op_completed`, `pr_created`, `ci_status_observed`, `block_raised`).
- `.planning/phases/05-spec-verification-bounded-loop/05-CONTEXT.md` — GitHub deferred to Phase 6; orphan `external_operations` → `abandon` on terminal run; bounded autonomy precedence.

### Stack & ops

- `.planning/research/STACK.md` — Elixir/Oban/Req versions if HTTP used alongside `gh`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `lib/kiln/external_operations.ex` and `lib/kiln/external_operations/operation.ex` — two-phase intent pattern for all side effects.
- `lib/kiln/sandboxes/docker_driver.ex` — example `fetch_or_record_intent` / `complete_op` / `fail_op` usage with telemetry.
- `lib/kiln/github.ex` — placeholder module to replace with real `Kiln.GitHub` boundary.
- `lib/kiln/boot_checks.ex` — already references `Kiln.GitHub` in boot checklist.

### Established Patterns

- **Oban** + **insert-time uniqueness** + **handler-level idempotency** — must extend to `PushWorker`, `OpenPRWorker`, `CheckPoller` without using `max_attempts` as “CI wait loop.”
- **Typed blocks** from Phase 3 contract — map `gh`/`git` stderr patterns to `:gh_*` / `:git_*` atoms with remediation text.

### Integration Points

- `Kiln.Runs.Transitions` — merge predicate satisfied → same-transaction audit + state to `merged`; CI fail diagnostic → transition back per ORCH-05.
- `Kiln.Audit.append/1` — JSV payloads for new event shapes if expanded.

</code_context>

<specifics>
## Specific Ideas

Research synthesis (2026-04-21) consolidated **required-checks-on-SHA** merge semantics, **artifact-first draft-by-default PRs**, **hybrid+jitter+deadline polling**, **stable bot + conventional commits + trailers**, and **CAS push with fail-fast default + optional bounded rebase** — chosen for mutual consistency: **no semantic “green” without the same object set that GitHub would require to merge**, **no nondeterministic PR text at `gh`**, **no webhook dependency in v1**, **no false human attribution**, **no silent push/rebase loops**.

</specifics>

<deferred>
## Deferred Ideas

- **GitHub App webhooks** for checks (reduce polling, faster transitions) — post-v1 optional module.
- **LLM-authored PR descriptions** — only as upstream artifact generation, never inline at `gh pr create` without frozen artifact.
- **GPG / Sigstore signing** for Kiln commits — when threat model justifies key lifecycle.
- **Merge-queue / Mergify deep integration** — explicit reconciliation job if dogfood hits double-merge semantics.

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 06-github-integration*
*Context gathered: 2026-04-21*
