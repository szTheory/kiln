# Phase 25: Local live readiness SSOT - Research

**Researched:** 2026-04-23  
**Domain:** Phoenix LiveView local-readiness UX, readiness state ownership, and local trial documentation  
**Confidence:** MEDIUM

## User Constraints

- Research Phase 25 only; do not plan Phase 26 or 27 beyond explicit dependency notes. [CITED: user request]
- Focus on the current readiness architecture and UI surfaces around `OperatorReadiness`, `OperatorSetup`, `OnboardingLive`, `ProviderHealthLive`, operator chrome/runtime mode, run-start gating in `RunDirector`, and README/local setup docs. [CITED: user request]
- Identify what is already solved vs still missing for `SETUP-01`, `SETUP-02`, and `DOCS-09`. [CITED: user request]
- Include explicit file references, risks, stale assumptions in prior docs, and concrete verification commands. [CITED: user request]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETUP-01 | Operator setup/readiness surface reports whether the local environment is ready for a live run, including Docker/runtime prerequisites and provider/config presence without exposing secret values. | Current state and gap analysis in `OperatorReadiness`, `OperatorSetup`, `SettingsLive`, chrome, and provider surfaces; see sections below. [VERIFIED: repo grep] |
| SETUP-02 | When the local environment is not ready, Kiln shows explicit remediation guidance and the recommended next action instead of making the operator infer the fix from scattered screens or logs. | Current remediation behavior is cataloged across `SettingsLive`, `OnboardingLive`, `ProviderHealthLive`, `TemplatesLive`, and `RunBoardLive`, with drift risks and SSOT recommendations called out below. [VERIFIED: repo grep] |
| DOCS-09 | README and planning docs describe one canonical local trial flow, with host Phoenix + Compose as the primary path and the optional devcontainer clearly framed as secondary. | README and planning-doc analysis below confirms what is already aligned and what still needs Phase 25 cleanup. [VERIFIED: repo grep] |
</phase_requirements>

## Summary

Kiln already has most of the visible pieces of a local live-readiness story: a persisted readiness row (`lib/kiln/operator_readiness.ex:17-106`), a derived setup summary (`lib/kiln/operator_setup.ex:39-128`), a full settings checklist (`lib/kiln_web/live/settings_live.ex:74-191`), shared operator chrome (`lib/kiln_web/components/layouts.ex:68-172`, `lib/kiln_web/components/operator_chrome.ex:127-245`), and disconnected live-state messaging on onboarding, templates, providers, and the run board. The problem is not absence of UI; it is that readiness is currently split across multiple sources and duplicated presentation layers. [VERIFIED: repo grep]

The current implementation is not yet a trustworthy SSOT for live readiness. The strongest technical risk is that `operator_readiness` is seeded to all `true` in the migration (`priv/repo/migrations/20260421230000_create_operator_readiness.exs:16-18`), while the checklist summary is derived from that persisted row rather than from fresh probes (`lib/kiln/operator_readiness.ex:22-29`, `64-80`; `lib/kiln/operator_setup.ex:56-94`). That means the app can report “ready” before an operator has verified anything on the current machine. [VERIFIED: repo grep]

**Primary recommendation:** Phase 25 should stop at one authoritative readiness projection and one authoritative readiness page/component contract, then update every existing surface to consume that contract; it should not absorb Phase 26’s run-start preflight routing or first-template recommendation work. [VERIFIED: repo grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Persist readiness facts | Database / Storage | API / Backend | `operator_readiness` is an Ecto-backed singleton row in Postgres. `OperatorReadiness` reads and updates it through `Repo`. [VERIFIED: repo grep] |
| Compute operator-facing readiness summary | API / Backend | — | `OperatorSetup.summary/0` composes checklist state and provider matrix before LiveViews render. [VERIFIED: repo grep] |
| Render authoritative readiness page | Frontend Server (SSR) | Browser / Client | `/settings` is the richest current readiness surface and renders checklist, blockers, and provider matrix from assigns. [VERIFIED: repo grep] |
| Render shared runtime-mode and provider-status chrome | Frontend Server (SSR) | Browser / Client | `OperatorChromeHook` assigns mode/scenario/provider snapshots for all default LiveViews, and `Layouts.app` renders the shared shell. [VERIFIED: repo grep] |
| Probe local machine prerequisites | API / Backend | OS / CLI | Docker and `gh` checks run through `System.cmd/3`; Anthropic readiness reads application env only. [VERIFIED: repo grep] |
| Gate run execution | API / Backend | Database / Storage | `RunDirector.start_run/1` is the hard backend guard for readiness and missing provider keys. [VERIFIED: repo grep] |
| Explain canonical local trial flow | Documentation | — | README and planning docs already define host Phoenix + Compose as canonical and devcontainer as secondary. [CITED: README.md] |

## Current Architecture and UI Surfaces

### Readiness state today

- `Kiln.OperatorReadiness` owns three persisted booleans: `anthropic_configured`, `github_cli_ok`, and `docker_ok`, plus three probes and a bypass env var `KILN_SKIP_OPERATOR_READINESS=1`. See `lib/kiln/operator_readiness.ex:17-106`. [VERIFIED: repo grep]
- `Kiln.OperatorSetup.summary/0` builds the operator-facing checklist and provider matrix from `OperatorReadiness.current_state/0` and `ModelRegistry.provider_health_snapshots/0`. See `lib/kiln/operator_setup.ex:39-128`. [VERIFIED: repo grep]
- `operator_readiness` is initialized with a singleton row whose three flags are all `true`. See `priv/repo/migrations/20260421230000_create_operator_readiness.exs:16-18`. This is the largest current trust gap. [VERIFIED: repo grep]

### UI surfaces already consuming readiness

| Surface | Current behavior | File refs |
|---------|------------------|-----------|
| `SettingsLive` | Most complete readiness page: blockers list, provider matrix, checklist rows, verify buttons, and “what to do next” copy. [VERIFIED: repo grep] | `lib/kiln_web/live/settings_live.ex:74-191` |
| `OnboardingLive` | Demo-first flow plus “live mode active” disconnected hero and an inline quick-check list with verify actions. [VERIFIED: repo grep] | `lib/kiln_web/live/onboarding_live.ex:111-260` |
| `ProviderHealthLive` | Provider cards plus disconnected-live hero that points back to settings when setup is incomplete. [VERIFIED: repo grep] | `lib/kiln_web/live/provider_health_live.ex:86-113` |
| `TemplatesLive` | Uses `setup_summary` to disable “Use template” and “Start run” in live mode and show disconnected-state messaging. [VERIFIED: repo grep] | `lib/kiln_web/live/templates_live.ex:176-200`, `344-437` |
| `RunBoardLive` | Uses `setup_summary` to show a disconnected-live hero while keeping the board explorable. [VERIFIED: repo grep] | `lib/kiln_web/live/run_board_live.ex:251-290` |
| Shared chrome | Shows runtime mode, provider config presence counts, and provider-readiness banner based on provider snapshots, not `OperatorSetup.summary/0`. [VERIFIED: repo grep] | `lib/kiln_web/components/layouts.ex:142-160`, `lib/kiln_web/components/operator_chrome.ex:127-245` |

### Where the state is split

- The page-level readiness story uses `OperatorSetup.summary/0`, which is based on persisted checklist booleans and provider snapshots. [VERIFIED: repo grep]
- The chrome banner uses `ModelRegistry.provider_health_snapshots/0` directly and does not know about checklist blockers like Docker or `gh` auth. See `lib/kiln_web/components/operator_chrome.ex:207-223`. [VERIFIED: repo grep]
- `OnboardingLive` and `SettingsLive` duplicate the same verify-event handlers and post-verify flash behavior instead of sharing a single component or action module. Compare `lib/kiln_web/live/onboarding_live.ex:33-63` and `lib/kiln_web/live/settings_live.ex:21-51`. [VERIFIED: repo grep]

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|------------------|---------|---------|--------------|
| Phoenix + LiveView | Phoenix 1.8.5 / LiveView 1.1.28 | Operator UI surfaces and shared layout/chrome. [CITED: CLAUDE.md] | All current readiness surfaces are LiveViews under one `live_session`, so Phase 25 should stay inside existing LiveView patterns. [VERIFIED: repo grep] |
| Ecto + Postgres | Ecto 3.13 / Postgres 16 | Persistence for readiness row and run state. [CITED: CLAUDE.md] | The current readiness booleans already live in Postgres; Phase 25 should evolve that contract rather than add a second store. [VERIFIED: repo grep] |
| Existing readiness modules | app-internal | `OperatorReadiness`, `OperatorSetup`, `OperatorRuntime`, `OperatorChromeHook`. [VERIFIED: repo grep] | These are already the building blocks for the SSOT; no new dependency is required for Phase 25. [VERIFIED: repo grep] |

### Supporting

| Library / Module | Version | Purpose | When to Use |
|------------------|---------|---------|-------------|
| `ModelRegistry` | app-internal | Provider config presence and health snapshots for names-only display. [VERIFIED: repo grep] | Use for provider matrix and chrome counts, not as the sole readiness source. [VERIFIED: repo grep] |
| Playwright / E2E tasking | repo-installed | Cross-page operator-flow verification. [CITED: README.md] | Use for full-journey smoke after Phase 25 implementation stabilizes, not for every inner-loop check. [CITED: README.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `OperatorReadiness` + `OperatorSetup` | New ETS/cache-only readiness store | Would create a second truth source and lose the existing persisted contract already referenced by tests and gating. [VERIFIED: repo grep] |
| Reusing `/settings` as the authoritative readiness page | Spreading “fix it here” actions across onboarding, providers, templates, and runs | That is close to today’s drift pattern and makes `SETUP-02` harder to keep coherent. [VERIFIED: repo grep] |

**Installation:** No package additions are recommended for Phase 25; use the current application stack. [VERIFIED: repo grep]

## Requirement Status

| Requirement | Already solved | Still missing for Phase 25 |
|-------------|----------------|----------------------------|
| `SETUP-01` | Kiln already has an operator checklist, provider matrix, runtime-mode chrome, provider health page, and server-side readiness gate without exposing secret values. Secret-shaped strings are explicitly negative-tested in `test/kiln_web/live/operator_chrome_live_test.exs:85-93`. [VERIFIED: repo grep] | The current “ready” answer is not trustworthy enough for SSOT use because the persisted row is seeded `true`, can go stale between boots, and is not recomputed centrally on mount. Chrome also omits Docker and GitHub readiness because it only sees provider snapshots. [VERIFIED: repo grep] |
| `SETUP-02` | Settings checklist rows already include `why`, `where_used`, `next_action`, and “Pages that will point here.” Disconnected-live heroes on onboarding, providers, templates, and run board all redirect the operator calmly toward setup. [VERIFIED: repo grep] | Recommended next action is not centralized. Some surfaces point to `/settings`, the chrome banner points to `/providers`, and `item.href` exists in `OperatorSetup` but is not rendered by `SettingsLive`. This is coherent enough for demos, not for SSOT. [VERIFIED: repo grep] |
| `DOCS-09` | README already states the canonical local path as host Phoenix + Compose data plane, and it explicitly frames the devcontainer as optional. Planning docs (`PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`) match that direction. [CITED: README.md] | Phase 25 still needs the documentation set to name the authoritative live-readiness surface and the verification path for readiness itself; today the docs explain local boot topology well, but not the “one live-readiness SSOT” contract. [CITED: README.md] |

## Architecture Patterns

### System Architecture Diagram

```text
Local machine / env vars / CLI tools
        |
        v
OperatorReadiness probes
(:anthropic_api_key_ref, gh auth status, docker info)
        |
        v
Persisted operator_readiness row (Postgres)
        |
        +----------------------------+
        |                            |
        v                            v
ModelRegistry.provider_health   OperatorSetup.summary
snapshots (provider names,      (checklist + blockers +
config presence, health)        provider matrix)
        |                            |
        +-------------+--------------+
                      |
                      v
        LiveViews and shared shell chrome
        /settings, /onboarding, /providers,
        /templates, /, Layouts.app
                      |
                      v
              Operator actions
         verify buttons / navigate to fix
                      |
                      v
            RunDirector.start_run/1
       hard gate for readiness + provider keys
```

The right Phase 25 shape is to keep the persisted row and provider snapshots, but expose one authoritative projection that every readiness-aware surface consumes. [VERIFIED: repo grep]

### Recommended Project Structure

```text
lib/
├── kiln/
│   ├── operator_readiness.ex     # raw probes + persisted row
│   ├── operator_setup.ex         # authoritative readiness projection
│   └── operator_runtime.ex       # demo/live UI mode only
└── kiln_web/
    ├── components/               # shared readiness cards/banners
    ├── live/                     # settings/onboarding/providers/templates/run board
    └── live/operator_chrome_hook.ex
```

Phase 25 should preserve these boundaries and avoid pushing readiness rules down into each LiveView. [VERIFIED: repo grep]

### Pattern 1: One authoritative readiness projection

**What:** Keep raw probes and persisted facts in `OperatorReadiness`, but make `OperatorSetup` the single public projection for readiness state, blockers, and recommended next action. [VERIFIED: repo grep]

**When to use:** Any UI or server-side code that needs to answer “is local live mode ready?” or “what should the operator do next?” [VERIFIED: repo grep]

**Example:** `SettingsLive`, `OnboardingLive`, `ProviderHealthLive`, `TemplatesLive`, and `RunBoardLive` already mount `OperatorSetup.summary/0`. [VERIFIED: repo grep]

### Pattern 2: One authoritative remediation page, many thin callers

**What:** Treat `/settings` as the place that explains blockers in full; other screens should summarize status and link back to the exact checklist target. [VERIFIED: repo grep]

**When to use:** Any disconnected-live hero or shell banner outside `/settings`. [VERIFIED: repo grep]

**Example:** `TemplatesLive` and `RunBoardLive` already follow this pattern partially by linking back to `/settings`; the problem is inconsistency, not absence. [VERIFIED: repo grep]

### Anti-Patterns to Avoid

- **Per-surface readiness logic forks:** The verify handlers and readiness copy are already duplicated between onboarding and settings; adding more copy branches will make SSOT drift worse. [VERIFIED: repo grep]
- **Treating persisted booleans as self-validating truth:** The seeded `true` row means persistence currently remembers optimism, not verified machine state. [VERIFIED: repo grep]
- **Expanding Phase 25 into Phase 26:** Preflighting the operator’s live-run launch and routing back to a specific blocker is explicitly `LIVE-02`, which is assigned to Phase 26 in `REQUIREMENTS.md` and `ROADMAP.md`. [VERIFIED: repo grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| New readiness store | Another ETS/cache/session store | Extend `OperatorReadiness` + `OperatorSetup` | Existing tests, row schema, and gating already depend on them. [VERIFIED: repo grep] |
| Per-page disconnected-state copy logic | Independent condition trees in every LiveView | Shared component + shared readiness projection | Current drift already shows this becomes inconsistent quickly. [VERIFIED: repo grep] |
| Secret display debugging | Raw env/value echoes in templates | Names-only provider/config reporting | SEC-01 and existing tests already enforce names-only UI. [VERIFIED: repo grep] |

**Key insight:** Phase 25 is a consolidation phase, not an invention phase. The right move is to remove ambiguity from existing readiness codepaths rather than add more readiness concepts. [VERIFIED: repo grep]

## Common Pitfalls

### Pitfall 1: False-positive readiness on a fresh database

**What goes wrong:** A brand-new environment can appear live-ready before any verification clicks occur. [VERIFIED: repo grep]  
**Why it happens:** The migration inserts the singleton row with all checks `true`. [VERIFIED: repo grep]  
**How to avoid:** Make the authoritative readiness projection start pessimistic or freshly probed, not inherited from seeded `true` values. [VERIFIED: repo grep]  
**Warning signs:** `/settings` says “Ready for live-mode setup-sensitive paths” on a machine that has never run `gh auth status` or `docker info`. [VERIFIED: repo grep]

### Pitfall 2: Split-brain between shell chrome and settings

**What goes wrong:** The shell can imply provider trouble while the settings checklist still looks healthy, or vice versa. [VERIFIED: repo grep]  
**Why it happens:** The chrome banner reads provider snapshots directly, while the settings page reads the checklist summary. [VERIFIED: repo grep]  
**How to avoid:** Drive both surfaces from one readiness projection with explicit sections for checklist blockers and provider-health notes. [VERIFIED: repo grep]  
**Warning signs:** Chrome links to `/providers` while all disconnected heroes tell the operator to fix `/settings`. [VERIFIED: repo grep]

### Pitfall 3: Thinking Phase 25 owns live-run launch preflight

**What goes wrong:** The plan grows to include start-run routing behavior and recommended first-template flow. [VERIFIED: repo grep]  
**Why it happens:** `RunDirector.start_run/1` is already a hard gate, so it is easy to overreach into `LIVE-02`/`LIVE-03`. [VERIFIED: repo grep]  
**How to avoid:** Limit Phase 25 to readiness truth, readiness presentation, and documentation; only leave interface hooks Phase 26 can consume. [VERIFIED: repo grep]  
**Warning signs:** Tasks start mentioning template choice, start-run redirects, or end-to-end proof flow. [VERIFIED: repo grep]

## Code Examples

Verified patterns from current repo code:

### Shared readiness summary on mount

```elixir
# Source: lib/kiln_web/live/settings_live.ex
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:page_title, "Settings")
   |> assign(:setup_summary, OperatorSetup.summary())
   |> assign(:last_verified, nil)}
end
```

[VERIFIED: repo grep]

### Hard backend readiness gate

```elixir
# Source: lib/kiln/runs/run_director.ex
def start_run(run_id) when is_binary(run_id) do
  if not OperatorReadiness.ready?() do
    {:error, :factory_not_ready}
  else
    start_run_when_ready(run_id)
  end
end
```

[VERIFIED: repo grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard onboarding gate / redirect expectation | Demo-first exploration with per-page disconnected states; `OnboardingGate` is now a no-op pass-through. [VERIFIED: repo grep] | By 2026-04-23 code state. [VERIFIED: repo grep] | Readiness must now be communicated honestly on every relevant page, not enforced by one redirect. [VERIFIED: repo grep] |
| No canonical demo/live mode flag | `OperatorRuntime` + `OperatorChromeHook` assign runtime mode and scenario to all default LiveViews. [VERIFIED: repo grep] | Added after 999.2 planning assumptions. [VERIFIED: repo grep] | Prior phase docs that say no canonical mode flag exists are now stale. [VERIFIED: repo grep] |

**Deprecated/outdated:**

- Phase 08 Summary still says `OnboardingGate` is part of the readiness gate story, but the current plug explicitly allows all traffic through unchanged. Compare `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-09-SUMMARY.md:14` with `lib/kiln_web/plugs/onboarding_gate.ex:1-16`. [VERIFIED: repo grep]
- 999.2 research says “No canonical demo vs live flag exists in the codebase today,” which was true then but is no longer true after `OperatorRuntime` landed. Compare `.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-RESEARCH.md:15-16` with `lib/kiln/operator_runtime.ex:1-38`. [VERIFIED: repo grep]
- Phase 17 context says readiness should be enforced before a run enters `queued`, but the current template flow still inserts a queued run via `Runs.create_for_promoted_template/2`; the hard readiness gate is in `RunDirector.start_run/1` after queue creation. Compare `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md:35-38` with `lib/kiln/runs.ex:47-85` and `lib/kiln/runs/run_director.ex:83-106`. [VERIFIED: repo grep]

## Strong Recommendations for Phase 25 Decomposition

1. **Readiness contract slice:** Refactor `OperatorReadiness` and `OperatorSetup` into one authoritative readiness projection that answers `ready?`, `blockers`, `provider presence`, and `recommended_next_action`, and make the initial state trustworthy. This slice should own the backend/domain contract only. [VERIFIED: repo grep]
2. **Shared UI slice:** Make `/settings` the authoritative readiness page and extract shared components for disconnected-live summaries so onboarding, providers, templates, run board, and shell chrome all render the same status semantics from the same projection. [VERIFIED: repo grep]
3. **Docs and verification slice:** Update README and planning docs to describe the readiness SSOT and exact verification commands, while preserving the existing “host Phoenix + Compose primary, devcontainer secondary” contract. [CITED: README.md]

**Boundary to hold:** Do not implement Phase 26’s live-run launch preflight routing in Phase 25. Phase 25 may expose the blocker metadata and exact `href` targets that Phase 26 will need, but it should not change run-launch flow semantics beyond that. [VERIFIED: repo grep]

## Assumptions Log

All material claims in this research were verified from the repo or cited from in-repo planning/docs artifacts. No user-confirmation assumptions are currently open. [VERIFIED: repo grep]

## Resolved Planning Decisions

1. **Phase 25 should make readiness pessimistic-by-default, not auto-probe on page mount.**
   - Decision: the operator-facing truth for a fresh or reset machine should default to **not ready** until explicit verification/probe results say otherwise. [VERIFIED: repo grep]
   - Rationale: this fixes the current false-ready risk directly, keeps readiness semantics deterministic in tests and docs, and avoids hidden machine-side effects or slow/flaky probes during LiveView mount. [VERIFIED: repo grep]
   - Scope note: explicit verify actions remain the way pages refresh probe state in Phase 25; broader automatic refresh can be revisited later if it materially improves UX. [VERIFIED: repo grep]

2. **Phase 25 should keep provider presence generic, not template/profile-specific.**
   - Decision: the authoritative readiness result should report generic local blocker state plus provider/config presence only. [VERIFIED: repo grep]
   - Rationale: template/profile-specific launch preflight is part of Phase 26’s first-live-run path, not this SSOT cleanup slice. [VERIFIED: repo grep]
   - Scope note: Phase 25 may improve names-only provider/config reporting and recovery language, but it should not predict whether a specific template/run will succeed. [VERIFIED: repo grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `docker` | Docker readiness probe, local topology docs, smoke commands | ✓ | Docker 29.3.1 / Compose v5.1.1 [VERIFIED: terminal command] | — |
| `gh` | GitHub readiness probe | ✓ | 2.89.0 [VERIFIED: terminal command] | — |
| `jq` | `first_run.sh` / shift-left docs | ✓ | 1.7.1 [VERIFIED: terminal command] | — |
| `curl` | `first_run.sh` / health checks | ✓ | 8.7.1 [VERIFIED: terminal command] | — |
| `lsof` | `first_run.sh` port checks | ✓ | present [VERIFIED: terminal command] | — |
| `mix` | tests and verification commands | ✓ | Mix 1.19.5 / OTP 28 [VERIFIED: terminal command] | — |
| `just` | README convenience commands | ✗ | — [VERIFIED: terminal command] | Use `bash script/dev_up.sh`, `bash script/precommit.sh`, `mix shift_left.verify`, and `bash test/integration/first_run.sh`. [CITED: README.md] |

**Missing dependencies with no fallback:**

- None for research. [VERIFIED: terminal command]

**Missing dependencies with fallback:**

- `just` is not installed in this workspace, but README already documents shell and Mix equivalents for every relevant command. [CITED: README.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest + Playwright e2e coverage already wired in repo. [CITED: README.md] |
| Config file | `test/` suite plus existing Mix tasks; no new framework install is needed. [VERIFIED: repo grep] |
| Quick run command | `mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs` [VERIFIED: repo grep] |
| Full suite command | `mix shift_left.verify` or `just shift-left` when available. [CITED: README.md] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETUP-01 | Shared UI surfaces show readiness/disconnected state without leaking secrets, and the backend readiness contract is not falsely optimistic on a fresh machine. [VERIFIED: repo grep] | backend + LiveView | `mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs` [VERIFIED: repo grep] | ✅ |
| SETUP-02 | Missing readiness provides actionable guidance and links back to setup surfaces. [VERIFIED: repo grep] | LiveView | `mix test test/kiln_web/live/settings_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs` [VERIFIED: repo grep] | ✅ |
| DOCS-09 | Canonical local flow and fallback commands stay aligned. [CITED: README.md] | docs + smoke | `bash test/integration/first_run.sh` and manual doc diff against `README.md`, `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` [CITED: README.md] | ✅ / docs review |

### Sampling Rate

- **Per task commit:** run the targeted `mix test ...` command above. [VERIFIED: repo grep]
- **Per wave merge:** run `bash test/integration/first_run.sh` because Phase 25 still touches the operator’s local readiness story. [CITED: README.md]
- **Phase gate:** run `mix shift_left.verify` when feasible; if `just` is unavailable, use the Mix command directly. [CITED: README.md]

### Wave 0 Gaps

- [ ] `test/kiln_web/live/settings_live_test.exs` — there is no dedicated Settings LiveView regression file today even though `/settings` is the richest readiness surface. [VERIFIED: repo grep]
- [ ] A focused contract test for `OperatorSetup.summary/0` — current tests cover screens and readiness gating, but not yet one dedicated summary-contract test with exact blocker semantics. [VERIFIED: repo grep]
- [ ] A docs verification note or grep-based artifact for `DOCS-09` — README is aligned today, but there is no phase-local regression check that the canonical local trial wording stays consistent. [CITED: README.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Solo local operator app; no login flow in scope. [CITED: .planning/PROJECT.md] |
| V3 Session Management | no | Not part of readiness scope. [CITED: .planning/PROJECT.md] |
| V4 Access Control | no | Not part of readiness scope. [CITED: .planning/PROJECT.md] |
| V5 Input Validation | yes | Keep readiness writes constrained to the existing enum-like `mark_step/2` API and current Ecto schema. [VERIFIED: repo grep] |
| V6 Cryptography | yes | Secret values stay outside UI; use names-only config presence per SEC-01 and current tests. [CITED: CLAUDE.md] |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret leakage in readiness UI | Information Disclosure | Keep using provider names/status only; do not render raw env vars or keys; preserve negative tests like `operator_chrome_live_test.exs:85-93`. [VERIFIED: repo grep] |
| False-ready machine state | Tampering / Integrity | Make readiness projection derive from trustworthy probes or explicit fresh verification, not seeded optimistic defaults. [VERIFIED: repo grep] |
| Drift between screens | Integrity | Use one projection and one authoritative remediation target instead of duplicating per-page readiness logic. [VERIFIED: repo grep] |

## Sources

### Primary (HIGH confidence)

- `lib/kiln/operator_readiness.ex` — persisted readiness row, probes, bypass env, readiness predicate. [VERIFIED: repo grep]
- `lib/kiln/operator_setup.ex` — checklist and provider matrix composition. [VERIFIED: repo grep]
- `lib/kiln_web/live/settings_live.ex` — current richest readiness page. [VERIFIED: repo grep]
- `lib/kiln_web/live/onboarding_live.ex`, `provider_health_live.ex`, `templates_live.ex`, `run_board_live.ex` — current disconnected-state surfaces. [VERIFIED: repo grep]
- `lib/kiln_web/components/layouts.ex`, `lib/kiln_web/components/operator_chrome.ex`, `lib/kiln_web/live/operator_chrome_hook.ex` — shell runtime-mode and provider-status wiring. [VERIFIED: repo grep]
- `lib/kiln/runs/run_director.ex`, `lib/kiln/runs.ex` — backend readiness gate and current queued-run creation path. [VERIFIED: repo grep]
- `README.md` — canonical local path and fallback commands. [CITED: README.md]

### Secondary (MEDIUM confidence)

- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` — current phase allocation and milestone boundaries. [VERIFIED: repo grep]
- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-09-SUMMARY.md` — stale readiness-gate assumptions now contradicted by code. [VERIFIED: repo grep]
- `.planning/phases/17-template-library-onboarding-specs/17-CONTEXT.md` — stale “pre-queued readiness enforcement” expectation vs current implementation. [VERIFIED: repo grep]
- `.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-RESEARCH.md` — stale “no canonical runtime-mode flag exists” claim. [VERIFIED: repo grep]

### Tertiary (LOW confidence)

- None. [VERIFIED: repo grep]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Phase 25 uses existing Phoenix/Ecto/internal modules already present in repo docs and code. [VERIFIED: repo grep]
- Architecture: HIGH - Current code boundaries are clear and the key Phase 25 product decision is resolved: readiness should become pessimistic-by-default, with explicit verify actions refreshing probe state. [VERIFIED: repo grep]
- Pitfalls: HIGH - The main drift points are explicit in code and prior-phase docs today. [VERIFIED: repo grep]

**Research date:** 2026-04-23  
**Valid until:** 2026-05-23

## RESEARCH COMPLETE
