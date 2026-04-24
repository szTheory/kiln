# Phase 27: Local first-run proof - Research

**Researched:** 2026-04-23
**Domain:** Local first-run proof orchestration for the setup-ready operator path
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Proof harness ownership

- **D-2701:** Phase 27 should expose **one dedicated thin Mix task** as the canonical proof command. It should be explicit about intent, memorable for operators and contributors, and suitable for exact citation in `27-VERIFICATION.md`.
- **D-2702:** The Mix task should be a **wrapper only**. It must delegate to existing proof layers rather than re-implement shell/bootstrap/test logic inside a new task.
- **D-2703:** The canonical proof command should run **exactly two layers in order**:
  1. the existing local-topology smoke via `mix integration.first_run`
  2. the focused operator-path proof via `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`
- **D-2704:** Do **not** cite `mix shift_left.verify` / `just shift-left` as the owning Phase 27 proof command. That command is broader than the requirement and would blur what this phase actually proves.
- **D-2705:** Do **not** make `test/integration/first_run.sh` the only owning proof surface. Shell is correct for the local-machine bring-up boundary, but not for the detailed Phoenix operator journey.

### Environment realism

- **D-2706:** The milestone proof must include the **real local topology** that Kiln documents and expects operators to run: **Compose data plane + host Phoenix + `.env` contract**.
- **D-2707:** The existing `mix integration.first_run` / `test/integration/first_run.sh` path remains the **SSOT for machine-level readiness proof**. Phase 27 should reuse it rather than cloning its Docker/bootstrap logic.
- **D-2708:** Purely test-seeded readiness or LiveView-only proof is **insufficient alone** for `UAT-04`. Those layers remain necessary support coverage, but they do not honestly prove the local-first machine story by themselves.
- **D-2709:** Full browser E2E is **not** the default ownership layer for this phase. It may remain as broader acceptance coverage elsewhere, but it should not become the phase's primary proof harness.
- **D-2710:** The Phase 27 proof should stay **deterministic and local**. Do not widen it to depend on live external vendors, real provider success, or unrelated network conditions beyond the existing local stack contract.

### Journey depth

- **D-2711:** The owning proof should cover the **setup-ready operator happy path**, not just a backend seam and not the blocked detour. The intended story is:
  1. `/settings` as the readiness SSOT
  2. `/templates` with `hello-kiln` as the recommended first run
  3. `Start run`
  4. `/runs/:id` as the first proof-of-life surface
- **D-2712:** The proof should be explicitly framed as **setup-ready**. Missing-readiness redirect/recovery remains valuable supporting coverage, but it should not be the centerpiece of the phase-owned proof command.
- **D-2713:** Do **not** reduce Phase 27 to a rerun of Phase 24's `/templates` happy path alone. Phase 27 must step up one level by tying the path back to the milestone's canonical readiness surface and real local machine story.
- **D-2714:** Do **not** deepen the phase into broad dashboard, browser, or multi-branch journey coverage. One coherent first-success path is more valuable than a wide but fuzzy proof story.

### Verification strictness

- **D-2715:** The primary proof contract should remain **stable routes + stable DOM ids** at operator-visible state boundaries.
- **D-2716:** Minimal text assertions are acceptable only when they disambiguate a meaningful branch or user-facing meaning. **Copy is not the primary contract.**
- **D-2717:** Do **not** make deep domain-state assertions, screenshot/visual snapshots, or raw HTML blob matching the top-level proof contract. Those are too brittle or duplicate lower-layer tests.
- **D-2718:** Shell assertions are appropriate only for the **outer integration boundary**: command success, local service health, and boot reachability. UI meaning should still be proven in Phoenix tests.
- **D-2719:** The verification artifact must cite the **single explicit Mix task command** and then transparently list the delegated layers underneath so the claim remains precise and honest.

### DX and architecture guardrails

- **D-2720:** Favor **principle of least surprise**: one command, two delegated SSOT layers, no hidden extra suites.
- **D-2721:** Keep the proof path aligned with existing repo idioms:
  - thin Mix wrappers for memorable project commands
  - `Phoenix.LiveViewTest` for routed LiveView behavior
  - shell integration only for real local stack bring-up
- **D-2722:** The phase should improve **developer ergonomics** by making the proof command obvious without hiding what it actually does. Convenience must not come at the cost of misleading scope.

### Claude's Discretion

- Exact naming of the new proof command, as long as it is explicit and memorable.
- Whether the command is implemented as a `Mix.Task` or alias-backed `Mix.Task`, as long as it remains a thin delegator.
- Exact decomposition of any new supporting test file, if a small Phase 27-specific happy-path test is needed to make the `/settings` -> `/templates` -> `/runs/:id` story more explicit.
- Exact wording of `27-VERIFICATION.md`, as long as the proof claim stays narrow and transparent.

### Deferred Ideas (OUT OF SCOPE)

- Making Playwright/browser E2E the owning Phase 27 proof harness
- Expanding `test/integration/first_run.sh` into a pseudo-browser or HTML-scraping UI harness
- Using `mix shift_left.verify` as the phase-owned command
- Making the blocked `/settings` recovery path the main Phase 27 proof story
- Deep domain-state or screenshot-based ownership for the top-level proof
- External-provider/live-vendor realism in the phase-owned proof command
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UAT-04 | The repository contains one explicit automated proof path for setup-ready operator flow -> first live run, and the exact verification command is cited in the phase verification artifact. [VERIFIED: .planning/REQUIREMENTS.md] | Add one thin proof-owning Mix task, delegate first to `mix integration.first_run`, then to focused LiveView tests, and cite that single command in `27-VERIFICATION.md`. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: mix.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs] |
</phase_requirements>

## Summary

Phase 27 does not need a new harness, new browser strategy, or new topology logic. The repo already has the two proof layers this requirement needs: `mix integration.first_run` for the real local machine story and focused LiveView tests for the operator-visible `/templates` -> `/runs/:id` story. The missing piece is ownership: one memorable Mix entrypoint that delegates to those layers in a narrow, honest order and one verification artifact that cites that command exactly. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs]

Current proof coverage is close but not perfectly story-shaped. `SettingsLiveTest` proves `/settings` as the readiness SSOT, `TemplatesLiveTest` proves blocked recovery and the happy path into run detail, and `RunDetailLiveTest` proves the proof-of-life shell. What is not explicit today is one setup-ready cross-screen assertion that starts from `/settings` as ready and then resumes the recommended template path. That is the main seam the planner should evaluate; if Phase 27 wants the proof story to read exactly like the requirement, one small additional LiveView test file is the cleanest way to do it. [VERIFIED: test/kiln_web/live/settings_live_test.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs] [ASSUMED]

The focused UI proof command already runs cleanly on this workstation: `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs` passed with 19 tests and 0 failures during this research session. `mix integration.first_run` is structurally correct and repo-aligned, but it did not finish within this research window, so runtime confirmation of the full two-layer wrapper on this specific workstation should stay in the execution plan. [VERIFIED: terminal command] [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh]

**Primary recommendation:** Ship one dedicated proof-owning Mix task, keep it as a strict two-step delegator, add at most one small setup-ready LiveView proof seam if needed, and cite only that top-level Mix command in `27-VERIFICATION.md`. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]

## Project Constraints (from CLAUDE.md)

- Use `just precommit` or `bash script/precommit.sh` when implementation is done; plain `mix precommit` is only acceptable when the shell already exports the needed env vars. [VERIFIED: AGENTS.md]
- Before `/gsd-plan-phase N --gaps`, use `just shift-left` or `mix shift_left.verify`; `just planning-gates` / `mix planning.gates` is the narrower `mix check`-only gate. [VERIFIED: AGENTS.md]
- Reuse the existing `Req` HTTP client and avoid `:httpoison`, `:tesla`, and `:httpc`. [VERIFIED: AGENTS.md]
- LiveView templates must start with `<Layouts.app ...>` and pass `current_scope`; this matters if Phase 27 touches any HEEx surface for missing ids or proof affordances. [VERIFIED: AGENTS.md] [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/settings_live.ex] [VERIFIED: lib/kiln_web/live/run_detail_live.ex]
- LiveView tests should use stable DOM ids plus `has_element?/2`, `element/2`, `render_submit/2`, and `follow_redirect/3` rather than raw HTML matching. [VERIFIED: AGENTS.md] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/settings_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs]
- Phase 27 should preserve the existing Phoenix/LiveView form and routing idioms rather than inventing browser-only hooks or inline scripts. [VERIFIED: AGENTS.md] [VERIFIED: lib/kiln_web/live/templates_live.ex] [VERIFIED: lib/kiln_web/live/settings_live.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical proof entrypoint | API / Backend | Browser / Client | The owning surface is a Mix task in the Elixir app, not a UI control; it orchestrates proof layers but does not present operator state itself. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: lib/mix/tasks/shift_left/verify.ex] |
| Local topology readiness proof | Frontend Server (SSR) | Database / Storage | `test/integration/first_run.sh` boots Compose DB, runs `mix setup`, starts host Phoenix, and asserts `/health`; this is machine/server proof, not browser proof. [VERIFIED: test/integration/first_run.sh] |
| Readiness SSOT | Frontend Server (SSR) | API / Backend | `/settings` is the operator-facing readiness surface, backed by readiness probes and return-context logic in LiveView. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: lib/kiln_web/live/settings_live.ex] |
| First-run template happy path | Frontend Server (SSR) | API / Backend | `/templates` owns the recommended first-run hero and triggers backend run start with deterministic redirects. [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md] [VERIFIED: lib/kiln_web/live/templates_live.ex] |
| Proof-of-life destination | Frontend Server (SSR) | API / Backend | `/runs/:id` is the first proof surface after launch; the UI exposes stable ids for state, next action, and recent evidence. [VERIFIED: .planning/phases/26-first-live-template-run/26-CONTEXT.md] [VERIFIED: lib/kiln_web/live/run_detail_live.ex] |

## Standard Stack

No new packages are recommended for Phase 27. The phase should reuse the project’s existing proof stack and only add orchestration plus, if necessary, one small LiveView test seam. [VERIFIED: mix.exs] [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Mix task / Mix alias surface | project-local | Canonical proof command entrypoint | The repo already exposes thin memorable command wrappers such as `integration.first_run` and `shift_left.verify`; Phase 27 should follow that idiom instead of adding shell-only ownership. [VERIFIED: mix.exs] [VERIFIED: lib/mix/tasks/shift_left/verify.ex] |
| Phoenix LiveViewTest | `~> 1.1.28` project constraint | Focused routed UI proof | Existing phase-owned proof for `/templates` and `/runs/:id` already lives here, with stable ids and redirect-following. [VERIFIED: mix.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs] |
| ExUnit via `mix test` | Elixir 1.19.5 / OTP 28 on this machine | File-targeted deterministic test execution | `mix help test` confirms multi-file invocation, and the current proof command passed locally in this session. [VERIFIED: mix help test] [VERIFIED: terminal command] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `test/integration/first_run.sh` | repo script | Real local topology proof | Use first in the wrapper to prove Compose DB + host Phoenix + `.env` + `/health`. [VERIFIED: test/integration/first_run.sh] |
| `mix integration.first_run` | project-local alias | Thin Elixir delegate to the shell SSOT | Use instead of calling the script directly from docs or the top-level proof task. [VERIFIED: mix.exs] |
| `SettingsLiveTest` | repo test file | Readiness SSOT seam | Use as supporting coverage or as the basis for one small Phase 27-specific story test if the planner wants an explicit setup-ready leg. [VERIFIED: test/kiln_web/live/settings_live_test.exs] [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated proof Mix task | `mix shift_left.verify` | Broader than `UAT-04`; it adds `mix check` and Playwright scope that the phase explicitly must not claim as its owning proof. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: script/shift_left_verify.sh] |
| Two-layer wrapper | `mix integration.first_run` alone | Honest about machine boot, but insufficient for operator-path proof. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] |
| LiveView proof + integration smoke | Playwright E2E | Wider acceptance coverage exists already, but it is the wrong ownership layer for this narrow phase. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: README.md] |
| New custom bootstrap shell | Reuse `mix integration.first_run` | Reuse preserves the SSOT for `.env`, compose bring-up, and `/health`; hand-rolled bootstrap logic would drift. [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh] |

**Installation:**
```bash
# No new dependencies. Reuse the existing project stack.
```

## Architecture Patterns

### System Architecture Diagram

```text
operator/prover
  |
  v
mix kiln.first_run.prove [ASSUMED name]
  |
  +--> mix integration.first_run
  |      |
  |      v
  |    test/integration/first_run.sh
  |      |
  |      +--> load .env if present
  |      +--> docker compose up -d db
  |      +--> KILN_DB_ROLE=kiln_owner mix setup
  |      +--> mix phx.server
  |      '--> curl /health == ok
  |
  '--> mix test templates_live_test.exs run_detail_live_test.exs [plus one small phase test if needed]
         |
         +--> /settings readiness surface (supporting seam)
         +--> /templates hello-kiln recommended path
         '--> /runs/:id proof-of-life shell
```

The critical planning rule is sequencing: prove the real local machine contract first, then prove operator-visible route semantics second. Reversing that order weakens the trust story because UI tests can pass under seeded readiness without proving the documented local topology. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: test/integration/first_run.sh] [VERIFIED: test/kiln_web/live/templates_live_test.exs]

### Recommended Project Structure

```text
lib/
└── mix/
    └── tasks/
        └── kiln/
            └── first_run/
                └── prove.ex        # Thin wrapper task that delegates to the two SSOT layers

test/
├── kiln_web/live/
│   ├── templates_live_test.exs     # Existing template -> run happy path
│   ├── run_detail_live_test.exs    # Existing proof-of-life surface
│   └── first_run_proof_test.exs    # Optional narrow setup-ready story seam [ASSUMED]
└── mix/tasks/
    └── kiln_first_run_prove_test.exs  # Optional task-level delegation assertions [ASSUMED]
```

### Pattern 1: Thin Mix Wrapper With No Bootstrap Logic
**What:** Add a single memorable Mix task that performs only ordered delegation. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
**When to use:** For the canonical phase proof command and `27-VERIFICATION.md` citation. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
**Example:**
```elixir
# Source: lib/mix/tasks/shift_left/verify.ex and mix.exs
def run(_) do
  Mix.Task.run("integration.first_run")
  Mix.Task.run("test", [
    "test/kiln_web/live/templates_live_test.exs",
    "test/kiln_web/live/run_detail_live_test.exs"
  ])
end
```
[VERIFIED: lib/mix/tasks/shift_left/verify.ex] [VERIFIED: mix help test] [ASSUMED]

### Pattern 2: Stable Route + Stable ID Proof
**What:** Follow navigation and assert route-visible state boundaries with ids instead of text-heavy assertions. [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs]
**When to use:** For the proof-owned UI layer and for any one-file Phase 27 seam. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
**Example:**
```elixir
# Source: test/kiln_web/live/templates_live_test.exs
result =
  view
  |> form("#templates-start-run-form")
  |> render_submit()

{:ok, run_view, _html} = follow_redirect(result, conn)
assert has_element?(run_view, "#run-detail")
```
[VERIFIED: test/kiln_web/live/templates_live_test.exs]

### Pattern 3: Keep `/settings` As Supporting SSOT, Not A New Harness
**What:** Reuse the readiness surface and its return-context seam instead of building a second proof surface. [VERIFIED: lib/kiln_web/live/settings_live.ex] [VERIFIED: test/kiln_web/live/settings_live_test.exs]
**When to use:** If planners decide the proof needs one explicit setup-ready test before the existing `/templates` happy path. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]
**Example:**
```elixir
# Source: test/kiln_web/live/settings_live_test.exs
{:ok, view, _html} =
  live(conn, "/settings?return_to=%2Ftemplates%2Fhello-kiln&template_id=hello-kiln#settings-item-anthropic")

assert has_element?(view, "#settings-return-to-template[href=\"/templates/hello-kiln\"]")
```
[VERIFIED: test/kiln_web/live/settings_live_test.exs]

### Anti-Patterns to Avoid

- **Scope creep to `shift_left.verify`:** It turns a narrow UAT proof into a broader release gate and breaks verification honesty. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: script/shift_left_verify.sh]
- **Rewriting `first_run.sh` inside a new task:** That duplicates the `.env`, Docker, and `/health` contract already owned by the shell SSOT. [VERIFIED: test/integration/first_run.sh] [VERIFIED: mix.exs]
- **Claiming LiveView-only proof satisfies `UAT-04`:** It misses the real local topology the milestone explicitly wants. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
- **Making copy the contract:** Existing tests and decisions favor stable ids and stable routes; copy assertions should stay minimal. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: test/kiln_web/live/templates_live_test.exs]

## Don’t Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Machine-level first-run bootstrap | New shell/bootstrap logic in the proof task | `mix integration.first_run` -> `test/integration/first_run.sh` | The script already owns `.env` loading, Docker bring-up, port conflict handling, `mix setup`, host server boot, and `/health` assertions. [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh] |
| UI proof harness | New browser/E2E ownership layer | `Phoenix.LiveViewTest` on the existing files | The current route/DOM-id proof already exists and passed locally in this session. [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs] [VERIFIED: terminal command] |
| Readiness proof surface | New template-page-only readiness logic | Existing `/settings` + return-context seam | `/settings` is the locked readiness SSOT and already encodes the return path. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: lib/kiln_web/live/settings_live.ex] |
| Verification wording | Broad suite claims | One exact top-level command plus delegated subcommands listed underneath | Phase 27 explicitly requires exact-command honesty. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] |

**Key insight:** Phase 27 is an orchestration-and-proof-shaping task, not a new testing-technology task. Almost every hard part already exists; the planner should spend effort on command ownership, gap-tightening, and proof honesty, not on new infrastructure. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: mix.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs]

## Common Pitfalls

### Pitfall 1: Making The Wrapper Bigger Than The Requirement
**What goes wrong:** The proof command starts running `mix check`, Playwright, or other unrelated suites. [VERIFIED: script/shift_left_verify.sh]
**Why it happens:** `shift_left.verify` already exists and looks convenient. [VERIFIED: lib/mix/tasks/shift_left/verify.ex]
**How to avoid:** Keep the new command to exactly two delegated layers, in the locked order. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
**Warning signs:** The command description starts reading like “full local acceptance” instead of “local first-run proof.” [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]

### Pitfall 2: Claiming `/templates` Happy Path Alone Proves The Milestone
**What goes wrong:** The phase effectively rebrands Phase 24 plus a better name. [VERIFIED: .planning/phases/24-template-run-uat-smoke/24-CONTEXT.md]
**Why it happens:** `TemplatesLiveTest` already reaches `#run-detail`, so it is tempting to stop there. [VERIFIED: test/kiln_web/live/templates_live_test.exs]
**How to avoid:** Preserve the local topology smoke and, if needed, add one small setup-ready story seam tied back to `/settings`. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]
**Warning signs:** The plan never mentions `/settings`, `mix integration.first_run`, or the real local machine contract. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]

### Pitfall 3: Hand-Rolling Brittle Proof Assertions
**What goes wrong:** The test asserts long copy blocks, screenshots, or raw HTML blobs and becomes noisy to maintain. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
**Why it happens:** The planner tries to make the proof “feel more end to end” without respecting the repo’s selector contract. [VERIFIED: AGENTS.md] [ASSUMED]
**How to avoid:** Reuse stable ids like `#settings-return-to-template`, `#templates-start-run`, and `#run-detail`. [VERIFIED: test/kiln_web/live/settings_live_test.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs] [VERIFIED: test/kiln_web/live/run_detail_live_test.exs]
**Warning signs:** New tests mostly assert prose, not ids or redirects. [VERIFIED: test/kiln_web/live/templates_live_test.exs] [ASSUMED]

### Pitfall 4: Forgetting Operator Environment Fallbacks
**What goes wrong:** Docs or tests assume `just` is available or assume the DB host port is always `5432`. [VERIFIED: README.md] [VERIFIED: justfile] [VERIFIED: terminal command]
**Why it happens:** Convenience wrappers are present in docs, but not required on this workstation; `just` is currently missing here. [VERIFIED: terminal command]
**How to avoid:** Cite the Mix command as canonical, list delegated subcommands explicitly, and let the existing `.env` contract and integration script own port customization. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: test/integration/first_run.sh] [VERIFIED: README.md]
**Warning signs:** The plan depends on `just shift-left` or hard-codes `5432` into the new wrapper logic. [VERIFIED: AGENTS.md] [VERIFIED: test/integration/first_run.sh] [ASSUMED]

## Code Examples

Verified patterns from repository sources:

### Existing Thin Wrapper Pattern
```elixir
# Source: lib/mix/tasks/shift_left/verify.ex
script = Path.expand("script/shift_left_verify.sh", File.cwd!())

case System.cmd("bash", [script], cd: File.cwd!(), stderr_to_stdout: true) do
  {out, 0} -> :ok
  {out, code} -> Mix.raise("shift_left.verify failed (exit #{code})")
end
```
[VERIFIED: lib/mix/tasks/shift_left/verify.ex]

### Existing Shell SSOT Pattern
```bash
# Source: test/integration/first_run.sh
docker compose up -d db
KILN_DB_ROLE=kiln_owner mix setup
mix phx.server &
curl -sf localhost:4000/health
```
[VERIFIED: test/integration/first_run.sh]

### Existing Focused UI Proof Pattern
```elixir
# Source: test/kiln_web/live/templates_live_test.exs
view
|> form("#template-use-form-hello-kiln")
|> render_submit()

result =
  view
  |> form("#templates-start-run-form")
  |> render_submit()

{:ok, run_view, _html} = follow_redirect(result, conn)
assert has_element?(run_view, "#run-detail")
```
[VERIFIED: test/kiln_web/live/templates_live_test.exs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Focused proof only on `/templates` -> `/runs/:id` | Milestone now requires one proof that ties local topology and operator path together | Phase 27 context, 2026-04-23 | The proof owner must compose integration smoke with focused UI proof rather than claiming either layer alone. [VERIFIED: .planning/phases/24-template-run-uat-smoke/24-CONTEXT.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] |
| Readiness as supporting context | `/settings` is now the readiness remediation SSOT | Phase 25, 2026-04-23 | The setup-ready story should anchor back to `/settings`, not invent a second readiness surface. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: test/kiln_web/live/settings_live_test.exs] |
| Broad local confidence via shift-left only | Narrow phase-owned proof plus broader shift-left remaining separate | Phase 27 boundary, 2026-04-23 | Verification docs can stay honest about what the phase command proves. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: script/shift_left_verify.sh] |

**Deprecated/outdated:**
- Using `mix shift_left.verify` as the phase-owned proof command is outdated for this specific requirement because the Phase 27 context explicitly rejects that ownership model. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]
- Treating `test/integration/first_run.sh` alone as milestone proof is outdated for `UAT-04` because the requirement now includes the operator-visible first-run path. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix kiln.first_run.prove` is the best command name. | Summary / Architecture Patterns | Low — naming is discretionary; a different explicit name still satisfies the phase. |
| A2 | One small Phase 27-specific LiveView test may be needed to make the setup-ready `/settings` -> `/templates` -> `/runs/:id` story explicit. | Summary / Architecture Patterns | Medium — if existing files are judged sufficient, the planner can skip this slice; if not, omitting it leaves the proof story fuzzier than the requirement wording. |
| A3 | A task-level unit test for the new Mix task is worth adding. | Recommended Project Structure / Validation | Low — the wrapper can still work without a dedicated task test, but delegation regressions become easier to miss. |

## Open Questions (RESOLVED)

1. **Do the existing LiveView files already satisfy the setup-ready story, or should Phase 27 add one narrow story test?**
   - Resolution: Phase 27 should add one narrow stitched story seam in the existing focused LiveView proof so the setup-ready path reads explicitly as `/settings` -> `/templates/hello-kiln` -> `Start run` -> `/runs/:id`. This stays within the locked scope because it clarifies one coherent happy path without introducing a new harness or broadening into browser E2E. [RESOLVED]
   - Planning consequence: keep the work inside the existing LiveView test files unless a tiny helper seam is clearly cleaner than forcing a brand-new file. [RESOLVED]

2. **Should the wrapper use `Mix.Task.run/2` directly or shell out to `mix` subcommands?**
   - Resolution: implement the wrapper with `Mix.Task.run/2` so the task remains a thin in-process delegator with no duplicated bootstrap logic and no additional shell orchestration. Shelling out would add unnecessary indirection for a command whose only job is to call two existing Mix-owned layers in order. [RESOLVED]
   - Planning consequence: the task contract should be pinned by a focused task-level test that fails if the delegated command list or order drifts. [RESOLVED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | top-level proof task and file-targeted tests | ✓ | Erlang/OTP 28 on this machine [VERIFIED: terminal command] | — |
| Docker / Compose | `mix integration.first_run` | ✓ | Docker 29.3.1 [VERIFIED: terminal command] | None for the machine-level proof layer |
| `jq` | `/health` JSON assertions in `first_run.sh` | ✓ | 1.7.1 [VERIFIED: terminal command] | None inside the existing script |
| `curl` | `/health` reachability in `first_run.sh` | ✓ | 8.7.1 [VERIFIED: terminal command] | None inside the existing script |
| `lsof` | port-holder detection in `first_run.sh` | ✓ | present [VERIFIED: terminal command] | None inside the existing script |
| `node` / `npm` | not required for the phase-owned proof, only broader E2E | ✓ | Node 22.14.0 / npm 11.1.0 [VERIFIED: terminal command] | Skip; Phase 27 should not depend on Playwright |
| `just` | optional convenience only | ✗ | — [VERIFIED: terminal command] | Use `mix integration.first_run`, `mix shift_left.verify`, and `bash script/precommit.sh`. [VERIFIED: AGENTS.md] [VERIFIED: justfile] |

**Missing dependencies with no fallback:**
- None for the recommended Phase 27 command on this workstation, assuming `mix integration.first_run` completes successfully under the existing Docker + `.env` contract. [VERIFIED: terminal command] [ASSUMED]

**Missing dependencies with fallback:**
- `just` is missing, but the canonical Phase 27 proof should use Mix and bash entrypoints directly, so this does not block planning or execution. [VERIFIED: terminal command] [VERIFIED: justfile]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest on Phoenix LiveView `~> 1.1.28`. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`. [VERIFIED: mix help test] [VERIFIED: terminal command] |
| Full suite command | `mix shift_left.verify` or `bash script/shift_left_verify.sh`; broader than Phase 27 ownership, but still the local phase gate. [VERIFIED: AGENTS.md] [VERIFIED: script/shift_left_verify.sh] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UAT-04 | Canonical proof command exists and delegates only the two intended layers. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] | unit/task | `mix test test/mix/tasks/kiln_first_run_prove_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| UAT-04 | Setup-ready operator path reaches run detail via stable route/id seams. [VERIFIED: .planning/REQUIREMENTS.md] | liveview | `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs` | ✅ |
| UAT-04 | Setup-ready story explicitly anchors back to `/settings` as readiness SSOT. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] | liveview | `mix test test/kiln_web/live/settings_live_test.exs test/kiln_web/live/first_run_proof_test.exs` [ASSUMED] | ❌ Wave 0 |
| UAT-04 | Real local topology boots under the documented `.env` + Compose + host Phoenix contract. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] | integration | `mix integration.first_run` | ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_detail_live_test.exs`. [VERIFIED: terminal command]
- **Per wave merge:** run the new top-level proof task once it exists; until then use `mix integration.first_run` plus the focused LiveView command. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED]
- **Phase gate:** `bash script/precommit.sh` and the canonical proof command before `/gsd-verify-work`; use `mix shift_left.verify` when broader local confidence is desired, but do not cite it as the phase proof. [VERIFIED: AGENTS.md] [VERIFIED: script/shift_left_verify.sh]

### Wave 0 Gaps

- [ ] `test/mix/tasks/kiln_first_run_prove_test.exs` — covers wrapper-task delegation and narrow scope for UAT-04. [ASSUMED]
- [ ] `test/kiln_web/live/first_run_proof_test.exs` — only if planners decide the setup-ready story needs one explicit stitched path. [ASSUMED]
- [ ] `27-VERIFICATION.md` — must cite the top-level proof command verbatim and list the delegated layers transparently. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 27 proof scope is local operator flow with no new auth surface. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no | No new session mechanism is introduced by a Mix task or these existing LiveView tests. [VERIFIED: .planning/PROJECT.md] |
| V4 Access Control | no | Phase 27 is not adding authorization branches. [VERIFIED: .planning/PROJECT.md] |
| V5 Input Validation | yes | Keep route/query validation and path scoping as already implemented in `SettingsLive.return_context/1`; do not broaden accepted redirect targets. [VERIFIED: lib/kiln_web/live/settings_live.ex] |
| V6 Cryptography | no | No crypto changes are needed for this proof-owning phase. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Proof task shells or delegates with user-controlled arguments | Tampering | Hard-code the delegated commands/files; do not accept runtime-provided file lists or shell fragments. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [ASSUMED] |
| Redirect/path confusion in readiness return flow | Spoofing | Preserve the existing `/templates/` prefix check in `SettingsLive.return_context/1`. [VERIFIED: lib/kiln_web/live/settings_live.ex] |
| Secret/config leakage in proof output | Information Disclosure | Reuse existing readiness and integration layers, which already avoid printing secret values and operate through `.env` / readiness probes. [VERIFIED: test/integration/first_run.sh] [VERIFIED: test/kiln_web/live/settings_live_test.exs] [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/27-local-first-run-proof/27-CONTEXT.md` - locked scope, proof ownership, exact command layering, and anti-scope-creep decisions.
- `.planning/REQUIREMENTS.md` - `UAT-04` wording and traceability.
- `.planning/ROADMAP.md` - Phase 27 goal and success criteria.
- `.planning/PROJECT.md` - milestone framing, merge-authority separation, and local-first constraints.
- `CLAUDE.md` and `AGENTS.md` - project constraints and verification workflow requirements.
- `mix.exs` - existing aliases, dependency constraints, and project command patterns.
- `lib/mix/tasks/shift_left/verify.ex` - existing thin task-wrapper pattern.
- `test/integration/first_run.sh` - local topology SSOT and machine-level proof contract.
- `lib/kiln_web/live/settings_live.ex`, `lib/kiln_web/live/templates_live.ex`, `lib/kiln_web/live/run_detail_live.ex` - route ownership and proof surfaces.
- `test/kiln_web/live/settings_live_test.exs`, `test/kiln_web/live/templates_live_test.exs`, `test/kiln_web/live/run_detail_live_test.exs` - existing proof seams and selector contract.
- `mix help test` - multi-file `mix test` invocation behavior.
- Terminal commands run during research - local availability of `mix`, Docker, `jq`, `curl`, `lsof`, Node, npm; focused LiveView proof passing on this workstation.

### Secondary (MEDIUM confidence)
- `README.md` - current operator-facing wording about integration smoke, shift-left, and `just` fallbacks.
- `justfile` - optional convenience wrappers around the proof-related commands.
- `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md` - prior happy-path proof seam.
- `.planning/phases/26-first-live-template-run/26-CONTEXT.md` - `/settings` -> `/templates` -> `/runs/:id` story and proof destination framing.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 27 reuses existing repo commands, tests, and dependencies rather than introducing new libraries. [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh]
- Architecture: HIGH - The locked Phase 27 context is explicit about proof ownership and sequencing, and the codebase already has matching layers. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: mix.exs] [VERIFIED: test/kiln_web/live/templates_live_test.exs]
- Pitfalls: HIGH - The main risks are directly visible from current repo surfaces and locked decisions: scope creep, SSOT duplication, and story-shape gaps. [VERIFIED: .planning/phases/27-local-first-run-proof/27-CONTEXT.md] [VERIFIED: script/shift_left_verify.sh]

**Research date:** 2026-04-23
**Valid until:** 2026-05-23
