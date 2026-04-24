# Phase 24: template-run-uat-smoke - Research

**Researched:** 2026-04-23
**Domain:** Phoenix LiveView regression testing for the `/templates` -> `/runs/:id` operator path [VERIFIED: codebase grep]
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Regression seam and selector contract

- **D-2401:** Phase 24 should keep **explicit DOM ids** as the primary regression contract for the template flow. Treat the existing ids in `TemplatesLive` as the canonical test seam unless one missing transition boundary must be made explicit.
- **D-2402:** Use a **hybrid selector policy**: ids for operator actions and state transitions, route/destination assertion for completion, and only minimal text assertions for sanity. Text is not the primary contract.
- **D-2403:** Do **not** pivot this flow to text-heavy, semantic-only, or accessibility-only selectors for the owning regression. In LiveView tests, those are more brittle for this operator path and less precise than the existing ids.
- **D-2404:** Additional selector surface is allowed only if it captures a real product state boundary already visible to the operator, such as the success panel after template promotion. Avoid test-hook sprawl.

### Harness ownership

- **D-2405:** `Phoenix.LiveViewTest` is the **owning harness** for this phase. The template -> run regression belongs in the fast, deterministic `mix test` path, not in browser-first E2E.
- **D-2406:** Existing browser coverage remains **thin smoke only**. Do not duplicate the detailed happy-path proof in Playwright or similar unless the flow later gains client-side hooks or browser-only behavior that LiveView tests cannot prove.
- **D-2407:** Phase 24 should prefer a **small, auditable LiveView expansion** over introducing a new harness, new fixtures, or CI orchestration complexity.

### Happy-path proof depth

- **D-2408:** The regression should prove more than a bare redirect tuple. After starting the run, the test should follow navigation and assert a **small stable run-detail invariant** on the destination surface.
- **D-2409:** The preferred terminal invariant is the existing `#run-detail` shell in `RunDetailLive`. This is the right balance between believable user-path proof and low brittleness.
- **D-2410:** Do **not** turn the LiveView smoke into a deep domain-assertion test that re-proves queued-run internals already covered by lower-layer tests such as `Runs.create_for_promoted_template/2`.
- **D-2411:** Redirect-only proof is too weak for this milestone unless the destination shell is also proven. The goal is first-success confidence, not test theater.

### Verification artifact and command shape

- **D-2412:** The phase verification artifact should cite a **focused file-level command**, not a line-number rerun and not a vague broader suite.
- **D-2413:** Default command shape: `mix test test/kiln_web/live/templates_live_test.exs`.
- **D-2414:** The verification doc must state this command as **targeted evidence for the template -> run journey**, not as a claim that it replaces the broader merge-authority suite.
- **D-2415:** If CI is updated for this phase, prefer a dedicated named step that runs the same focused file-level command so the verification artifact and CI evidence stay aligned.

### Coherence with prior phase decisions

- **D-2416:** Preserve the Phase 17 mental model: `/templates` remains the canonical catalog, `Use template` and `Start run` stay separate but adjacent steps in one tight flow.
- **D-2417:** Preserve the Phase 22 honesty model: exact commands must map cleanly to what they prove, and CI remains merge authority for broader correctness.

### the agent's Discretion

- Exact assertion mix inside the LiveView test, as long as ids remain primary and destination proof stays shallow but real.
- Whether one additional success-state selector is needed beyond the existing `#templates-success-panel`.
- Exact wording and structure inside `24-VERIFICATION.md`, as long as the focused `mix test ...` line is cited precisely and honestly.

### Deferred Ideas (OUT OF SCOPE)

- Expanding browser/E2E ownership for the full template -> run journey — defer unless the flow gains browser-only behavior
- Broader run-detail assertions or multi-layer persistence checks inside the LiveView smoke — defer unless lower-layer run creation coverage becomes insufficient
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UAT-03 | `Phoenix.LiveViewTest` (or existing integration harness) covers template pick -> start run happy path using stable DOM ids; documents the command in the phase VERIFICATION artifact. [VERIFIED: `.planning/REQUIREMENTS.md`] | Use `test/kiln_web/live/templates_live_test.exs` as the owning file, keep existing ids from `TemplatesLive`, follow the live redirect with `follow_redirect/3`, assert `#run-detail`, and cite `mix test test/kiln_web/live/templates_live_test.exs`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
</phase_requirements>

## Summary

Phase 24 should stay entirely inside the existing Phoenix LiveView test seam. The repo already exposes the right operator-path ids in `TemplatesLive` (`#template-use-form-<id>`, `#templates-success-panel`, `#templates-start-run-form`, `#templates-start-run`) and the destination shell in `RunDetailLive` (`#run-detail`), so no new harness or browser test layer is justified for this slice. [VERIFIED: codebase grep]

The current gap is not missing selectors. The focused file `test/kiln_web/live/templates_live_test.exs` already mounts the right pages, but the whole file currently fails because `KilnWeb.Plugs.OnboardingGate` redirects `/templates` traffic to `/onboarding` until `Kiln.OperatorReadiness.ready?/0` is true. Any implementation plan that ignores readiness setup will keep failing before the template flow even starts. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs] [VERIFIED: codebase grep]

**Primary recommendation:** Keep `Phoenix.LiveViewTest` as the only harness, make `TemplatesLiveTest` explicitly satisfy readiness in setup, assert the existing success panel by id, follow the `push_navigate` into `/runs/:id` with `follow_redirect/3`, and prove success by asserting `#run-detail`; cite `mix test test/kiln_web/live/templates_live_test.exs` verbatim in `24-VERIFICATION.md`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Template flow operator actions | Frontend Server (SSR) | API / Backend | `TemplatesLive` handles form submits and renders the state transitions server-side. [VERIFIED: codebase grep] |
| Template promotion and run creation | API / Backend | Database / Storage | `Specs.instantiate_template_promoted/1` and `Runs.create_for_promoted_template/2` are server-side domain operations already covered below the UI layer. [VERIFIED: codebase grep] |
| Onboarding readiness gate | Frontend Server (SSR) | Database / Storage | `KilnWeb.Plugs.OnboardingGate` runs in the browser pipeline but depends on persisted readiness state from `Kiln.OperatorReadiness`. [VERIFIED: codebase grep] |
| Destination proof after run start | Frontend Server (SSR) | API / Backend | The regression should prove navigation to `RunDetailLive` and stop at the stable `#run-detail` shell, not re-test run internals. [VERIFIED: codebase grep] |

## Project Constraints (from CLAUDE.md)

- Use `Phoenix.LiveViewTest` and `LazyHTML` for LiveView assertions; prefer `has_element?/2` and `element/2` over raw-HTML assertions. [VERIFIED: `CLAUDE.md`] [VERIFIED: codebase grep]
- LiveView templates must keep `<Layouts.app ...>` with `current_scope` on routed pages. `TemplatesLive` and `RunDetailLive` already comply, so this phase should preserve that shape. [VERIFIED: `CLAUDE.md`] [VERIFIED: codebase grep]
- Keep explicit DOM ids on forms and buttons because tests are expected to target them directly. [VERIFIED: `CLAUDE.md`] [VERIFIED: codebase grep]
- After implementation, run `just precommit` or `bash script/precommit.sh`. [VERIFIED: `CLAUDE.md`] [VERIFIED: `AGENTS.md`] 

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.28 [VERIFIED: mix.lock] | Routed LiveView surfaces and `push_navigate` semantics for the `/templates` -> `/runs/:id` path. [VERIFIED: codebase grep] | The repo already uses LiveView for both source and destination surfaces, so Phase 24 should extend the existing routed LiveView test flow, not add another UI stack. [VERIFIED: codebase grep] |
| Phoenix.LiveViewTest | 1.1.28 docs surface [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Mount, submit forms, detect redirects, and follow navigation in tests. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Official docs explicitly support `render_submit/1` returning a redirect tuple and `follow_redirect/3` mounting the destination LiveView. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| ExUnit / `mix test` alias | Elixir 1.19.5 runtime, project alias in `mix.exs` [VERIFIED: mix help test] [VERIFIED: codebase grep] | Focused file execution for the regression artifact. [VERIFIED: mix help test] | `mix test` accepts file paths directly, and this repo’s `test` alias ensures `ecto.create --quiet` and `ecto.migrate --quiet` run first. [VERIFIED: mix help test] [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| LazyHTML | 0.1.11 [VERIFIED: mix.lock] | Existing repo-supported selector debugging for LiveView tests. [VERIFIED: `CLAUDE.md`] | Use only if selector debugging becomes necessary; Phase 24’s happy path should be provable with `has_element?/2` alone. [VERIFIED: `CLAUDE.md`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Phoenix.LiveViewTest` file-level regression [VERIFIED: codebase grep] | Browser E2E smoke [ASSUMED] | Browser smoke would duplicate a server-rendered path the repo already proves with LiveView forms and redirects, adding more setup cost for less determinism. [VERIFIED: codebase grep] |
| ID-first selectors [VERIFIED: codebase grep] | Text-heavy assertions [ASSUMED] | Text is already secondary in the phase context and is more likely to churn than the explicit form/button ids already present in the templates. [VERIFIED: codebase grep] |

**Installation:**

```bash
# No new packages required for Phase 24; use the existing Phoenix test stack.
mix deps.get
```

**Version verification:** Phoenix is declared as `~> 1.8.5` and Phoenix LiveView as `~> 1.1.28` in `mix.exs`, with `phoenix_live_view` resolved to `1.1.28` and `lazy_html` to `0.1.11` in `mix.lock`. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Operator test conn
  -> live(conn, "/templates/hello-kiln")
    -> Browser pipeline
      -> OnboardingGate checks OperatorReadiness
        -> if not ready: redirect "/onboarding"
        -> if ready: TemplatesLive mounts
          -> submit #template-use-form-hello-kiln
            -> Specs.instantiate_template_promoted/1
            -> TemplatesLive assigns :last_promoted
            -> render #templates-success-panel + #templates-start-run
          -> submit #templates-start-run-form
            -> Runs.create_for_promoted_template/2
            -> push_navigate "/runs/:id"
              -> follow_redirect(conn)
                -> RunDetailLive mounts
                  -> assert #run-detail
```

The critical branch is the onboarding gate before `TemplatesLive` mounts. Phase 24 must set readiness deterministically or the regression never reaches the intended journey. [VERIFIED: codebase grep] [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]

### Recommended Project Structure

```text
test/kiln_web/live/
├── templates_live_test.exs   # Owning Phase 24 regression file
└── route_smoke_test.exs      # Existing broad route smoke, kept separate

lib/kiln_web/live/
├── templates_live.ex         # Existing source selectors and start-run event
└── run_detail_live.ex        # Existing destination shell proof

lib/kiln_web/plugs/
└── onboarding_gate.ex        # Readiness prerequisite that the test must satisfy
```

### Pattern 1: Readiness-First LiveView UAT

**What:** Make the owning test file explicitly satisfy onboarding readiness before mounting `/templates`, then keep the regression id-first from source form submit through destination shell. [VERIFIED: codebase grep]  
**When to use:** Any LiveView regression that targets routes behind `KilnWeb.Plugs.OnboardingGate`. [VERIFIED: codebase grep]  
**Example:**

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
result =
  view
  |> form("#templates-start-run-form")
  |> render_submit()

{:ok, run_view, _html} = follow_redirect(result, conn)
assert has_element?(run_view, "#run-detail")
```

### Pattern 2: Keep Domain Assertions Below the UI Slice

**What:** Let the UI test stop at `#run-detail`, while lower-layer tests continue to own queued-run internals like workflow checksum and state. [VERIFIED: codebase grep]  
**When to use:** When domain semantics already exist in `test/kiln/specs/template_instantiate_test.exs`. [VERIFIED: codebase grep]  
**Example:**

```elixir
# Source: /Users/jon/projects/kiln/test/kiln/specs/template_instantiate_test.exs
assert {:ok, run} = Runs.create_for_promoted_template(spec, "hello-kiln")
assert run.state == :queued
assert {:ok, _} = Runs.workflow_checksum(run.id)
```

### Anti-Patterns to Avoid

- **Redirect-only success proof:** Asserting only that `render_submit()` returned `{:error, {:live_redirect, %{to: ...}}}` is weaker than the phase contract because it never proves the destination LiveView mounted. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- **Ignoring readiness setup:** The current test file already demonstrates that skipping readiness setup causes all four tests to fail at `/onboarding`. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]
- **Text-first selector drift:** The phase context explicitly rejects text-heavy selectors as the primary seam for this operator path. [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Following a LiveView redirect | Custom parsing of `{:error, {:live_redirect, ...}}` tuples [ASSUMED] | `follow_redirect/3` from `Phoenix.LiveViewTest` [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Official support already mounts the redirected LiveView and returns a view suitable for `has_element?/2`. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| New browser-first harness | Playwright/Cypress ownership for this slice [ASSUMED] | Existing `test/kiln_web/live/templates_live_test.exs` file [VERIFIED: codebase grep] | The path is already server-rendered, form-driven, and deterministic in LiveView. [VERIFIED: codebase grep] |
| New test-only selector hooks | Extra `data-testid` sprawl [ASSUMED] | Existing ids in `TemplatesLive` and `RunDetailLive` [VERIFIED: codebase grep] | The source already has stable ids at the exact state boundaries Phase 24 needs. [VERIFIED: codebase grep] |

**Key insight:** The repo already has the right seam. The missing piece is deterministic route access through readiness plus destination proof after redirect. [VERIFIED: codebase grep] [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]

## Common Pitfalls

### Pitfall 1: Onboarding Gate Masks the Real Regression

**What goes wrong:** The LiveView never mounts `/templates`; tests fail immediately with a redirect to `/onboarding`. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]  
**Why it happens:** `KilnWeb.Plugs.OnboardingGate` runs in the browser pipeline and checks `Kiln.OperatorReadiness.ready?/0` before routed LiveViews mount. [VERIFIED: codebase grep]  
**How to avoid:** In module setup, set readiness explicitly for the test path and keep the module synchronous if it mutates the singleton readiness row. [VERIFIED: codebase grep]  
**Warning signs:** `live(conn, "/templates")` returns `{:error, {:redirect, %{to: "/onboarding"}}}` instead of `{:ok, view, _html}`. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]

### Pitfall 2: Success Panel Proven, Destination Unproven

**What goes wrong:** The test stops after `#templates-start-run` appears and never proves the run detail page loaded. [VERIFIED: codebase grep]  
**Why it happens:** The current file only checks the redirect target path substring on start-run. [VERIFIED: codebase grep]  
**How to avoid:** Use `follow_redirect/3` and assert `#run-detail`. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] [VERIFIED: codebase grep]  
**Warning signs:** Assertions end with `assert to =~ "/runs/"` and do not touch the returned destination view. [VERIFIED: codebase grep]

### Pitfall 3: Re-Proving Domain Internals in the UI Test

**What goes wrong:** The LiveView smoke starts asserting queued state, checksums, or audit payloads already covered elsewhere. [VERIFIED: codebase grep]  
**Why it happens:** UI tests sometimes absorb lower-layer responsibilities when redirect-only proof feels too thin. [ASSUMED]  
**How to avoid:** Keep the UI invariant shallow: success panel exists, redirect follows, `#run-detail` renders. Leave workflow checksum and run-state assertions in `template_instantiate_test.exs`. [VERIFIED: codebase grep]  
**Warning signs:** The LiveView test needs repo queries or run reloads to pass. [ASSUMED]

## Code Examples

Verified patterns from official sources and the current codebase:

### Follow Live Navigation After `render_submit/1`

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
result =
  view
  |> form("#templates-start-run-form")
  |> render_submit()

{:ok, run_view, _html} = follow_redirect(result, conn, ~p"/runs/#{run_id}")
assert has_element?(run_view, "#run-detail")
```

### Assert the Existing Success Boundary by ID

```elixir
# Source: /Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex
view
|> form("#template-use-form-hello-kiln")
|> render_submit()

assert has_element?(view, "#templates-success-panel")
assert has_element?(view, "#templates-start-run")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Redirect-tuple-only LiveView smoke [VERIFIED: codebase grep] | `follow_redirect/3` into the destination LiveView with a stable DOM assertion [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Present in LiveView 1.1.28 docs as of 2026-04-23. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] | Phase 24 can prove a believable end-to-end server-rendered user path without adding browser E2E. [VERIFIED: codebase grep] |

**Deprecated/outdated:**

- Treating a route substring like `"/runs/"` as the terminal proof for a LiveView navigation is outdated for this slice because the official testing API already supports mounting the redirected destination. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Browser E2E would add more setup cost and less determinism than the current LiveView seam for this exact slice. | Standard Stack / Don't Hand-Roll | Low — the phase context already locks LiveViewTest as owner, so this only affects explanatory framing. |
| A2 | New `data-testid` hooks would be unnecessary sprawl for this flow. | Don't Hand-Roll | Low — the source already has the required ids. |
| A3 | Requiring repo queries inside the UI smoke would indicate the test has expanded beyond the intended slice. | Common Pitfalls | Low — this is a planning heuristic, not a contract fact. |

## Resolved Questions

1. **Readiness setup contract for `TemplatesLiveTest`**
   - Decision: Standardize on DB-backed readiness setup inside `test/kiln_web/live/templates_live_test.exs` by capturing the current `Kiln.OperatorReadiness.current_state/0`, marking `:anthropic`, `:github`, and `:docker` true with `OperatorReadiness.mark_step/2` before `live/2`, restoring the prior booleans in `on_exit`, and running the module `async: false`. [VERIFIED: codebase grep]
   - Rejected alternative: Do not use the `KILN_SKIP_OPERATOR_READINESS=1` env bypass for Phase 24 because it sidesteps the real routing contract and introduces process-global leakage risk. [VERIFIED: codebase grep]
   - Planning impact: The plan can now treat readiness setup as resolved implementation guidance rather than an open design choice. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Focused file execution | ✓ [VERIFIED: command probe] | Project task help available [VERIFIED: mix help test] | — |
| Elixir | Test runtime | ✓ [VERIFIED: command probe] | 1.19.5 [VERIFIED: command probe] | — |
| PostgreSQL client | `mix test` alias / Ecto test DB tooling | ✓ [VERIFIED: command probe] | `psql 14.17` [VERIFIED: command probe] | — |
| Docker | Not required for the owning file-level LiveView test | ✓ [VERIFIED: command probe] | `29.3.1` [VERIFIED: command probe] | Not needed for Phase 24 quick run. [VERIFIED: codebase grep] |

**Missing dependencies with no fallback:**

- None found during this research pass. [VERIFIED: command probe]

**Missing dependencies with fallback:**

- None for the focused file-level LiveView test. [VERIFIED: command probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest + LazyHTML. [VERIFIED: `CLAUDE.md`] [VERIFIED: codebase grep] |
| Config file | none — project relies on `mix test` conventions plus aliases in `mix.exs`. [VERIFIED: mix help test] [VERIFIED: codebase grep] |
| Quick run command | `mix test test/kiln_web/live/templates_live_test.exs` [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`] |
| Full suite command | `just precommit` [VERIFIED: `AGENTS.md`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UAT-03 | Template detail -> use template -> success panel -> start run -> destination shell on `/runs/:id`. [VERIFIED: codebase grep] | LiveView integration smoke | `mix test test/kiln_web/live/templates_live_test.exs` [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`] | ✅ |

### Sampling Rate

- **Per task commit:** `mix test test/kiln_web/live/templates_live_test.exs` [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`]
- **Per wave merge:** `just precommit` [VERIFIED: `AGENTS.md`]
- **Phase gate:** Focused file green and cited verbatim in `24-VERIFICATION.md`; broader merge authority remains CI. [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`] [VERIFIED: `.planning/phases/22-merge-authority-operator-docs/22-CONTEXT.md`]

### Wave 0 Gaps

- [ ] Add readiness setup to `test/kiln_web/live/templates_live_test.exs` so `/templates` mounts deterministically behind `OnboardingGate`. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs] [VERIFIED: codebase grep]
- [ ] Replace the redirect-substring terminal assertion with `follow_redirect/3` + `assert has_element?(run_view, "#run-detail")`. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- [ ] Update `24-VERIFICATION.md` to cite `mix test test/kiln_web/live/templates_live_test.exs` exactly and describe it as narrow evidence for the template -> run journey. [VERIFIED: `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md`]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: codebase grep] | No auth surface is involved in this operator-local route slice. [VERIFIED: codebase grep] |
| V3 Session Management | no [VERIFIED: codebase grep] | The phase does not change session ownership or cookie logic. [VERIFIED: codebase grep] |
| V4 Access Control | yes [VERIFIED: codebase grep] | `KilnWeb.Plugs.OnboardingGate` blocks access to `/templates` until readiness is complete. [VERIFIED: codebase grep] |
| V5 Input Validation | yes [VERIFIED: codebase grep] | `Templates.fetch/1` and `Specs`/`Runs` server-side flows keep `template_id` validation on the server side; unknown ids already map to safe error handling. [VERIFIED: codebase grep] |
| V6 Cryptography | no [VERIFIED: codebase grep] | Phase 24 does not add crypto or secret-handling behavior. [VERIFIED: codebase grep] |

### Known Threat Patterns for Phoenix LiveView regression slices

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered `template_id` submit | Tampering | Server-side lookup rejects unknown ids and shows safe error/redirect behavior. [VERIFIED: codebase grep] |
| False-positive UI proof | Repudiation | Require destination-shell assertion after redirect instead of only asserting a path substring. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| Gate bypass in tests hides real routing behavior | Elevation of Privilege | Prefer explicit readiness setup in the test contract and keep the gate behavior visible in research/verification notes. [VERIFIED: codebase grep] [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs] |

## Sources

### Primary (HIGH confidence)

- [Phoenix.LiveViewTest docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html) - `render_submit/1`, redirect tuples, and `follow_redirect/3`. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- Local codebase:
  - `/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex`
  - `/Users/jon/projects/kiln/lib/kiln_web/live/run_detail_live.ex`
  - `/Users/jon/projects/kiln/lib/kiln_web/plugs/onboarding_gate.ex`
  - `/Users/jon/projects/kiln/lib/kiln/operator_readiness.ex`
  - `/Users/jon/projects/kiln/test/kiln_web/live/templates_live_test.exs`
  - `/Users/jon/projects/kiln/test/kiln/specs/template_instantiate_test.exs`
  - `/Users/jon/projects/kiln/test/kiln_web/live/route_smoke_test.exs`
  - `/Users/jon/projects/kiln/mix.exs`
  - `/Users/jon/projects/kiln/mix.lock`

### Secondary (MEDIUM confidence)

- None. [VERIFIED: research pass]

### Tertiary (LOW confidence)

- None beyond the explicit assumptions logged above. [VERIFIED: research pass]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - versions and harness usage are directly verified from `mix.exs`, `mix.lock`, and official LiveView docs. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html]
- Architecture: HIGH - source and destination LiveViews plus the gating plug are directly present in the repo. [VERIFIED: codebase grep]
- Pitfalls: HIGH - the focused file run reproduced the gate failure and exposed the current redirect-only proof gap. [VERIFIED: mix test test/kiln_web/live/templates_live_test.exs]

**Research date:** 2026-04-23
**Valid until:** 2026-05-23
