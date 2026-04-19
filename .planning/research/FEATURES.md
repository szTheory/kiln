# Feature Research — Kiln (Software Dark Factory)

**Domain:** Autonomous agent orchestration platform for end-to-end software production (dark factory model)
**Researched:** 2026-04-18
**Confidence:** HIGH (Context7 + official docs for competitors; recent public writeups from StrongDM, Gas Town, Fabro; current 2026 ecosystem)

---

## Executive Summary

The "dark software factory" category crystallized in Q1 2026 around three public reference points: **StrongDM's non-interactive factory** (no human reads code; scenarios-as-holdouts; Digital Twin Universe), **Steve Yegge's Gas Town** (Mayor/worker hierarchy; Beads durable ledger; DoltHub-federated persistence), and **Fabro** (workflow-as-code with Graphviz DOT graphs; cloud sandboxes; stage-level git checkpoints). Around them sits a crowded adjacent market of agent-in-the-loop IDEs and autonomous-task runners: Devin, Factory.ai Droids, OpenHands (née OpenDevin), Claude Code Agent Teams, Cursor Composer, GitHub Copilot Agent Mode, Replit Agent 4, Cognition, Aider, SWE-agent, AutoGPT.

The category's table stakes are now well-established: a **run board**, **per-stage diff viewer**, **sandbox isolation** (defense-in-depth), **token/cost telemetry**, **idempotent retries**, **append-only audit trail**, **stage-level checkpointing**, and **stop/resume/replay**. Missing any of these makes the system feel like a research demo. The public reliability lessons from GSD-2, Gas Town, and Fabro are consistent and loud: **systems fail when autonomy, retries, and artifacts are not tightly bounded** — stuck loops, cost runaway, silent fallback. Kiln's "bounded autonomy" posture is the correct one.

Kiln's legitimate differentiation sits in a narrow band: **BEAM-native agent tree** (OTP supervisors map 1:1 to the mayor/worker pattern without a coordination layer bolted on), **portable YAML/JSON workflow graphs** (versioned in git, survives Kiln rewrites, language-agnostic), **Digital Twin Universe out of the box** (StrongDM proved the pattern; nobody open-sourced it), **dogfood-first brand/UX posture** (operator control-room, not chat-app), and **OTel-first observability** (traces are stable in Erlang/Elixir as of 2026; most competitors lean on ad-hoc logs). Everything else is table stakes or anti-feature.

The anti-feature list is as load-bearing as the feature list. **Synchronous human approval gates**, **team/RBAC**, **hosted runtime**, **marketplace**, **web-based workflow authoring**, **real-time co-edit UX** — each of these is a well-intentioned scope expansion that would break the dark-factory thesis or drown a solo-engineer v1. PROJECT.md already captures these correctly; this research confirms that posture against the competitor set.

---

## Competitor Feature Matrix

Rows are features; columns are reference systems. Entries mark presence (✓), partial (◐), absent (✗), or anti-feature (⊘ means the system explicitly rejects it). "Kiln v1" column states the v1 intent per PROJECT.md.

| Feature | StrongDM | Gas Town | Fabro | Devin | Factory.ai | OpenHands | Claude Agent Teams | Cursor Composer | Copilot Workspace | Replit Agent 4 | Aider | SWE-agent | **Kiln v1** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Autonomous end-to-end loop (spec→ship)** | ✓ | ◐ | ✓ | ✓ | ✓ | ✓ | ◐ | ✗ | ◐ | ✓ | ✗ | ◐ | ✓ |
| **Workflow-as-code (versioned graph)** | ◐ | ✗ | ✓ (DOT) | ✗ | ◐ (Missions) | ◐ | ◐ (task list) | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (YAML) |
| **Stage-level git checkpointing** | ◐ | ✓ (Beads ledger) | ✓ | ◐ | ◐ | ◐ | ✗ | ✗ | ✗ | ✗ | ✓ (per-commit) | ✗ | ✓ |
| **Run board / kanban UI** | ✓ (internal) | ◐ (CLI) | ✓ | ✓ | ✓ | ✓ (cloud) | ✗ | ✗ | ◐ | ✓ | ✗ | ✗ | ✓ |
| **Per-stage diff viewer** | ✓ | ◐ | ✓ | ✓ | ✓ | ✓ | ◐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| **Provider-agnostic LLM adapter** | ✓ | ✓ | ✓ (stylesheets) | ✗ (Claude-only) | ✓ | ✓ (OpenRouter) | ✗ (Anthropic) | ◐ | ✗ (GH/OpenAI) | ◐ | ✓ | ✓ | ✓ |
| **Per-stage model selection** | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ◐ | ✗ | ✗ | ✗ | ✓ | ✗ | ✓ |
| **Sandbox (Docker/microVM/remote)** | ✓ | ◐ (worktree) | ✓ (cloud VM) | ✓ | ✓ | ✓ (Docker) | ✗ | ✗ | ◐ | ✓ | ✗ | ✓ | ✓ (Docker) |
| **Network egress controls** | ✓ | ✗ | ✓ | ✓ | ✓ | ◐ | ✗ | ✗ | ✗ | ◐ | ✗ | ✗ | ✓ |
| **Digital Twin / mocked externals** | ✓ (pioneered) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (DTU) |
| **Scenario-based acceptance (BDD)** | ✓ (holdouts) | ✗ | ◐ | ✗ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (SWE-bench) | ✓ |
| **Append-only audit ledger** | ✓ | ✓ (Beads) | ✓ | ◐ | ✓ (SOC2) | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **Correlation IDs / structured logging** | ✓ | ◐ | ✓ | ◐ | ✓ | ◐ | ✗ | ✗ | ✗ | ◐ | ✗ | ✗ | ✓ |
| **OpenTelemetry traces** | ✓ | ✗ | ◐ | ✗ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **Token + cost telemetry per run** | ✓ | ✓ | ✓ | ✓ (ACU) | ✓ | ✓ | ◐ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| **Bounded autonomy (caps + escalation)** | ✓ | ✓ (gt escalate) | ✓ | ◐ (runaway reported) | ✓ | ◐ | ✗ | n/a | n/a | ◐ | n/a | n/a | ✓ |
| **Idempotent retries / side-effect keys** | ✓ | ◐ | ◐ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **Stuck-run detector** | ✓ | ◐ | ◐ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **Time-travel replay** | ✓ | ✓ (ledger) | ✓ | ✗ | ✓ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ◐ (v1.1) |
| **Mayor/worker agent hierarchy** | ◐ | ✓ (canonical) | ◐ | ✗ | ✓ (Code/Knowledge Droids) | ◐ | ✓ (team lead) | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ |
| **Shared agent memory (beads-equivalent)** | ✓ | ✓ (Dolt) | ◐ | ✗ | ✓ | ◐ (file locks) | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (native) |
| **Parallel runs / concurrency** | ✓ | ✓ | ✓ | ✓ | ✓ (10+ droids) | ✓ | ✓ | ✗ | ◐ | ✓ | ✗ | ✗ | ◐ (v1: 1; v1.1+: N) |
| **Human approval gates in-loop** | ⊘ | ◐ | ✓ (hexagon nodes) | ✗ | ✓ | ✓ (Planning Mode) | ✗ | ✗ | ✓ | ◐ | ✓ | ✗ | **⊘ (anti-feature)** |
| **Team / RBAC / multi-tenant** | ✓ | ◐ (Wasteland) | ✗ | ✓ (enterprise) | ✓ (SSO/SAML) | ✓ (cloud) | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | **⊘ (v1 anti-feature)** |
| **Hosted/cloud runtime** | ✓ (internal) | ✗ | ✓ (cloud VM) | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | **⊘ (v1 anti-feature)** |
| **Web-based workflow authoring UI** | ◐ | ✗ | ✗ (git-edit DOT) | ✗ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | **⊘ (git-edit only)** |
| **Embedded model weights / local inference** | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ (via Ollama HTTP) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | **⊘ (HTTP API to Ollama only)** |
| **Marketplace / workflow sharing** | ✗ | ◐ (Wasteland) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | **⊘ (v1 anti-feature)** |
| **SSO / OIDC enterprise auth** | ✓ | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | **⊘ (v1 anti-feature)** |
| **Mobile UI** | ✗ | ✗ | ✗ | ◐ | ✗ | ◐ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | **⊘ (desktop-first)** |

**Key reading of the matrix:**
- No existing public system has **all** of: workflow-as-code + per-stage checkpoints + DTU mocks + OTel + bounded autonomy + append-only ledger + OSS + local-first + BEAM. Kiln v1 occupies that exact intersection.
- StrongDM is the closest in posture (no-human-reads, DTU, holdout scenarios) but is internal/closed. Fabro is closest in shape (workflow-as-code, checkpoints, sandbox) but lacks DTU and is single-tenant-hostile to solo use. Gas Town is closest in orchestration primitives (Mayor/worker, durable work) but is CLI-first and has public fragility reports.
- The "autonomous IDE" cluster (Cursor, Copilot, Replit) is adjacent but **not a direct competitor**: they optimize pair-programming UX, not unattended factory execution. Including them in the matrix is mainly to mark contrast (their in-loop approvals are a Kiln anti-feature).

---

## Feature Landscape

### Table Stakes — Missing These Makes Kiln Feel Broken

Operators will not trust an unattended factory that lacks any of these. They are non-negotiable for v1.

| # | Feature | Why Expected | Complexity | REQ-ID | Notes |
|---|---|---|---|---|---|
| TS-01 | **Run board (kanban by state)** | Every competitor in the matrix has one; the mission-control metaphor is the category UX | MED | UI-01 | Phoenix LiveView streams + PubSub; state-column-driven |
| TS-02 | **Per-stage diff viewer** | Reviewability = trust; StrongDM/Fabro/Devin/Droids all ship this | MED | UI-02 | Mount git workspace read-only; render unified diff; syntax highlight |
| TS-03 | **Per-stage logs + event stream** | Debugging stuck runs requires raw logs, not truncated "pretty" summaries (Fabro lesson) | LOW | UI-02, OBS-01 | Stream from Oban job output + structured log sink |
| TS-04 | **Workflow state machine persisted to DB** | Crash-resumability; "where is this run?" answerable from one source | MED | ORCH-03 | queued→planning→coding→testing→verifying→(merged\|failed\|escalated) |
| TS-05 | **Stage-level checkpointing** | Fabro/Gas Town/Beads all pivoted hard here; without it, retry restarts wipe work | MED | ORCH-04 | Each stage writes artifact + event before emitting success |
| TS-06 | **Idempotent retries + idempotency keys** | Oban unique jobs + side-effect keys; GSD-2 retry storms are the canonical failure mode | MED | ORCH-07 | Every git push, API call, commit keyed |
| TS-07 | **Bounded autonomy (caps + escalation)** | Publicly the #1 reliability issue in GSD-2, Gas Town, Fabro | MED | ORCH-06 | Per-run caps on retries, token spend, elapsed steps; halt + diagnostic |
| TS-08 | **Sandbox isolation** | 2026 category consensus (Firecracker/gVisor/Docker); untrusted code must not touch host | HIGH | SAND-01, SAND-02 | Ephemeral Docker + network egress blocked; per-stage teardown |
| TS-09 | **Secrets outside sandbox** | StrongDM/Northflank pattern: secret references, not inline; no long-lived creds in sandbox | MED | (gap — no REQ yet; see **Gap G-01**) | Secret class UI only; never render secret value |
| TS-10 | **Provider-agnostic LLM adapter** | Lock-in avoidance; per-stage model routing requires it | MED | AGENT-01 | Behaviour-defined port (Anthropic/OpenAI/Google/Ollama) |
| TS-11 | **Per-stage model selection** | Cost efficiency; planner=Opus, coder=Sonnet, router=Haiku is now a well-known pattern | LOW | AGENT-02 | Declarative in workflow YAML |
| TS-12 | **Token + cost telemetry per run** | Every competitor ships it; users will not adopt an unattended system they cannot budget | MED | AGENT-05, UI-04 | Record tokens in + out per agent per stage; aggregate to dashboard |
| TS-13 | **Append-only audit ledger** | StrongDM, Beads, Fabro all agree; table stakes for unattended systems | MED | OBS-03, UI-05 | Postgres append-only table + filterable view; never update-in-place |
| TS-14 | **Structured logging with correlation IDs** | Required to debug cross-stage, cross-agent behavior; operator baseline | LOW | OBS-01 | correlation_id, causation_id, actor, run_id, stage_id on every line |
| TS-15 | **Git commit/push integration** | Output has to land in git for the loop to close; `gh` for PRs when workflow calls for it | LOW | GIT-01, GIT-02 | Shell out; retry-safe |
| TS-16 | **CI status sync** | The verifier must see CI result to decide "done"; without this, loop cannot close | MED | GIT-03 | Poll/read GitHub Actions API |
| TS-17 | **Stop/halt + diagnostic artifact** | Every dark-factory post-mortem has this as missing gap | LOW | ORCH-06 (escalation half) | On cap hit: dump state, stop, mark escalated |
| TS-18 | **Stuck-run detector** | Gas Town's fragility reports + GSD-2 stuck loops drove this; no-progress alert is mandatory | LOW | OBS-04 | Timer: if no stage transition in N minutes, halt + alert |
| TS-19 | **Executable spec / acceptance scenarios** | Verifier has to run something deterministic; BDD scenarios in markdown is the StrongDM pattern | MED | SPEC-01, SPEC-02, SPEC-03 | Markdown + embedded scenarios; run in sandbox |
| TS-20 | **Zero-to-first-run onboarding** | GSD-2/Fabro adoption failures trace to install fragility; `docker compose up` → first run | LOW | LOCAL-01, LOCAL-02, LOCAL-03 | README walkthrough, tool-versions pinned |

**Coverage check:** All 20 table stakes map to existing REQ-IDs except **TS-09 (secrets)**, which is flagged as Gap G-01 below.

---

### Differentiators — Where Kiln Competes

Features that set Kiln apart. Each must trace back to Core Value from PROJECT.md: *"Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably."*

| # | Feature | Value Proposition | Complexity | REQ-ID | Why Kiln-Shaped |
|---|---|---|---|---|---|
| DIFF-01 | **BEAM-native agent tree (OTP supervisor/worker)** | Crash isolation, supervision, PubSub, message passing are free. Competitors bolt coordination onto Python/TS. Gas Town simulates this with Dolt + mail.Router; Kiln gets it from the runtime. | HIGH | AGENT-03, ORCH-02 | Ties directly to Core Value: *durably* — OTP is industry-proven for 24/7 telecom-grade reliability. |
| DIFF-02 | **Portable YAML/JSON workflow graphs** | Fabro uses Graphviz DOT (Fabro-specific tool). Kiln's YAML is readable by humans *and* other factories. Survives Kiln rewrites. Forkable. | MED | ORCH-01 | Longevity/portability — the workflow outlives the runtime. |
| DIFF-03 | **Digital Twin Universe (DTU) out of the box** | StrongDM pioneered mocked third-party APIs for deterministic sandbox testing. Nobody has open-sourced it. Makes specs truly reproducible offline. | HIGH | SAND-03 | Core Value: *safely* (no prod calls) + *durably* (reproducible runs). |
| DIFF-04 | **OpenTelemetry-first observability** | OTel Erlang/Elixir traces are stable as of 2026. Most competitors log to stdout + ad-hoc dashboards. Kiln emits spans per stage/agent call, vendor-agnostic export. | MED | OBS-02 | Core Value: *visibly* — real operator trace UX, not log grep. |
| DIFF-05 | **Mayor/worker hierarchy as real OTP supervisor tree** | Gas Town's Mayor/Polecat/Refinery maps cleanly to GenServer+supervisor. Specialized roles (Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor) are processes. | HIGH | AGENT-03 | Idiomatic to BEAM; crash-recovery semantics are free. |
| DIFF-06 | **Native beads-equivalent durable work tracking** | Gas Town uses Dolt (external dependency, public fragility reports). Kiln embeds it: Postgres-backed bead-equivalent with versioning + replay. | MED | AGENT-04 | Core Value: *durably* + addresses Gas Town's documented sidecar-dependency fragility. |
| DIFF-07 | **Kiln brand book as UI contract** | Operator microcopy ("Start run", "Verify changes", "Build verified") + coal/char/iron/bone/ash/ember palette. Feels like operating equipment, not chatting with AI. StrongDM-quality operator ergonomics. | MED | UI-06 | Core Value: *visibly* — brand book in kiln-brand-book.md is already locked. |
| DIFF-08 | **Dogfoodable for Elixir/Phoenix projects** | Kiln builds Kiln. Public repo at github.com/szTheory/kiln validates end-to-end. No other dark factory dogfoods itself publicly yet. | MED | GIT-04 | Self-validating: if Kiln can't ship Kiln features, it can't ship yours. |
| DIFF-09 | **Workflow graph rendered live in UI** | Fabro's graphs are Graphviz renders; Kiln renders YAML + current stage state live via LiveView streams. Visualize "the factory cranking." | MED | UI-02, UI-03 | Core Value: *visibly* — unique visual identity for the category. |
| DIFF-10 | **Full event sourcing optional, ledger mandatory** | Competitor ecosystem conflates event sourcing with audit. Kiln defaults to current-state + append-only ledger; event sourcing only where replay pays. Cleaner ops profile. | MED | OBS-03 | Avoids GSD-2 over-engineering pitfall; matches prompt-feedback.txt guidance. |

**Differentiator posture:** Nine of ten differentiators tie to *how* Kiln operates (BEAM, YAML portability, DTU, OTel, brand). One (DIFF-08) is meta: proving the category works for the builder's own stack. Kiln does **not** differentiate on model quality, speed, or novelty of agents — those are commodity layers.

---

### Anti-Features — Explicitly Rejected

Every anti-feature here has been "commonly requested" in the competitor set, but would break the dark-factory thesis, Kiln's v1 scope, or solo-operator posture. Documenting the *why* prevents scope creep re-entry.

| # | Anti-Feature | Why Requested | Why Problematic for Kiln | Alternative | PROJECT.md Ref |
|---|---|---|---|---|---|
| AF-01 | **Synchronous human approval gates in execution loop** | Feels "safer"; Fabro ships them as hexagon nodes; OpenHands shipped Planning Mode | **Defining anti-pattern for dark-factory model.** Approval gates turn the factory into a ticket queue. Bounded autonomy (caps + halt + escalation diagnostic) is the correct safety mechanism. StrongDM's entire public writeup is "no human reads the code." | Bounded autonomy: retry caps, token caps, step caps, escalation = halt + artifact. No synchronous human wait states. | Out of Scope: "Human approval gates / synchronous review UI" |
| AF-02 | **Multi-tenant / teams / RBAC** | Every enterprise-aimed competitor ships it; Factory.ai SOC2/SSO/SAML is in their GA headline | Premature scope. Solo operator self-use must be proven first. Adds auth middleware, row-level security, audit-by-tenant, impersonation — multiplies complexity by 3-4x. | Prove single-user value first. Revisit once one operator ships meaningful work. | Out of Scope |
| AF-03 | **Hosted cloud runtime (K8s/AWS/GCP)** | "Where do I run it?" is the first question enterprise asks; Factory.ai/Devin/Replit all ship hosted | Operational overhead massively inflates v1. Local Docker is the StrongDM/Fabro local mode; upgrade path later if demand materializes. | `docker compose up` on operator's machine. Terraform templates are v2+ consideration. | Out of Scope |
| AF-04 | **Web-based workflow authoring UI** | Fabro ships a graph editor; users expect "drag-and-drop workflows" | Workflows should be code: versioned, diffable, reviewable in git PRs. A GUI editor adds state-sync complexity and tempts ad-hoc edits that bypass version control. | Workflows are YAML files in git; LiveView renders them **read-only**. Edit in editor of choice, commit, Kiln reloads. | Out of Scope |
| AF-05 | **Embedded model weights / local inference** | Privacy-conscious users want "no API calls"; OpenHands connects to Ollama | Embedding inference means GPU mgmt, model download, quant trade-offs, vendor-neutral loader. Vastly out of scope for a Phoenix app. | Call Ollama via its HTTP API like any other provider. Kiln orchestrates; it does not infer. | Out of Scope |
| AF-06 | **Marketplace / workflow sharing** | Gas Town's Wasteland federation is the pattern; community loves "share your workflow" | Distribution, signing, trust model, namespace clashes, supply-chain risk. All enormous. And single-user scope makes it moot. | Public git repos for workflows; copy-paste YAML is the v1 distribution method. | Out of Scope |
| AF-07 | **SSO / OIDC / enterprise auth** | Standard enterprise prerequisite | Solo-operator, localhost-only. No login screen needed in v1. Adds identity provider integration, session mgmt, token refresh — all out of scope. | No auth; listen on localhost only; rely on OS-level user boundary. | Out of Scope |
| AF-08 | **Mobile app / mobile UI** | Dashboards should be checkable on phone | Operator work (intervention, debugging, re-triggering) is desktop work. Mobile view is decorative, not functional, and bloats the UI surface. | Desktop-first LiveView. Responsive to tablet, but no mobile-specific work. | Out of Scope |
| AF-09 | **Real-time pair-programming UX (Cursor/Copilot-style)** | Users of in-IDE agents assume this is the UX model | Pair programming requires a human in the loop watching keystrokes. Factory mode is unattended. Mixing the two produces a confused product. | Kiln is not an IDE. Operators inspect *after* the factory acts, not during. | Consistent with PROJECT.md stance |
| AF-10 | **Per-run manual context injection / mid-stream guidance** | Gas Town allows operators to nudge agents mid-run; GSD-2 has `/steer` | Corrupts run provenance, bypasses the durable artifact trail, encourages vibes-driven operation. Kiln is "set spec, start run, read result." | If the spec is wrong, fix the spec, restart the run. No mid-flight steering. | Implicit in bounded-autonomy decision |
| AF-11 | **Chat transcript as primary UX** | Every consumer AI product does this; it's the easy path | "If daily usage feels like chatting harder, you have failed" — context-window doc's own words. Kiln UX is a run board, not a chat thread. | Run board + stage cards + structured artifacts. Chatter is viewable per stage but is not the main surface. | Context window doc, final product stance |
| AF-12 | **"Agent compute units" / opaque billing tokens** | Devin's ACU model; Factory.ai Droid credits | Obscures real cost. Operators want raw token counts and dollar figures. Opaque billing tokens are a SaaS pricing construct, not an operator-trust construct. | Raw tokens + dollar cost per stage, per run, per workflow. No synthetic units. | Consistent with AGENT-05, UI-04 |

**Anti-feature posture:** The anti-feature list is what makes Kiln a dark factory rather than an agentic IDE. Removing any of AF-01, AF-04, AF-09, AF-10, or AF-11 would destroy the category fit, even if each sounds "user-friendly" in isolation.

---

## Feature Dependency Graph

Dependencies inform phase ordering. Arrows point "requires" (A → B means A depends on B).

```
                         LOCAL-01 (docker-compose)
                                  |
                                  v
                          Core DB + Oban + Phoenix boot
                                  |
            +---------------------+---------------------+
            |                     |                     |
            v                     v                     v
      ORCH-01 YAML         OBS-01 logging          GIT-01 git drive
      workflow schema      + correlation IDs        + workspace
            |                     |                     |
            +-----------+---------+                     |
                        v                               |
                  ORCH-03 state machine (runs, stages)  |
                        |                               |
                        v                               |
                  ORCH-02 stage executor                |
                     (supervised BEAM process)          |
                        |                               |
            +-----------+-----------+                   |
            v           v           v                   |
       AGENT-01      SAND-01     ORCH-07                |
       LLM adapter   Docker      idempotency            |
            |        sandbox        |                   |
            |           |           |                   |
            v           v           |                   |
       AGENT-02      SAND-02        |                   |
       per-stage     egress block   |                   |
       model route      |           |                   |
            |           v           |                   |
            |        SAND-03        |                   |
            |        DTU mocks      |                   |
            |           |           |                   |
            +-----------+-----------+-------------------+
                        |
                        v
                  ORCH-04 checkpointing
                  (artifacts + events per stage)
                        |
                        v
                  AGENT-03 specialized agents
                  (Planner/Coder/Tester/Reviewer/QA/Mayor)
                        |
                        v
                  AGENT-04 shared memory (beads)
                        |
                        v
                  SPEC-01 spec editor
                        |
                        v
                  SPEC-02 executable scenarios
                        |
                        v
                  SPEC-03 verifier
                        |
                        v
                  ORCH-05 loop-until-spec-met
                        |
                        v
                  ORCH-06 bounded autonomy caps
                        |
                        v
                  OBS-04 stuck-run detector
                        |
            +-----------+-----------+
            v                       v
       UI-01 run board         GIT-02/03 PR + CI sync
       UI-02 run detail
       UI-05 audit ledger view
            |
            v
       UI-04 cost dashboard
       AGENT-05 cost telemetry (emits to UI-04)
            |
            v
       UI-03 workflow registry
       UI-06 brand book applied
            |
            v
       OBS-02 OTel traces (emits throughout; reader UI)
       OBS-03 audit ledger (emits throughout; UI-05 reader)
            |
            v
       GIT-04 CI for Kiln itself (dogfood)
       LOCAL-03 README zero-to-first-run walkthrough
```

### Critical dependency notes

- **ORCH-01 (workflow YAML) blocks everything downstream.** Without the schema, there is no "run" to execute. First feature after app skeleton.
- **ORCH-03 (state machine) is the backbone.** Run board (UI-01) reads it; checkpointing (ORCH-04) writes to it; bounded autonomy (ORCH-06) gates on it.
- **SAND-01/02/03 form a unit.** Sandbox without egress blocking is unsafe; egress blocking without DTU mocks makes most workflows impossible to verify (they call third-party APIs). Ship together.
- **OBS-01 (correlation IDs) must precede ORCH-02.** If stages emit logs without correlation IDs, debugging is impossible from day one. Logger middleware first.
- **OBS-03 (audit ledger) is a write path used by almost every other feature.** Define the append-only table + API before ORCH-03 goes live. Do not bolt on later.
- **AGENT-04 (shared memory / beads-equivalent) depends on ORCH-04 (checkpointing).** Beads *is* a checkpointed write log.
- **ORCH-05 (loop-until-spec-met) depends on SPEC-03 (verifier).** Cannot loop without a verdict. Cannot verdict without executable scenarios (SPEC-02).
- **ORCH-06 (bounded autonomy) is a *gate* on ORCH-05, not parallel to it.** The loop must call the cap-check before each iteration.
- **UI-04 (cost dashboard) reads from AGENT-05 (cost telemetry).** Telemetry must emit in a queryable shape from the start; dashboard is a read projection.
- **GIT-04 (CI for Kiln itself) should ship early** even though it looks like a polish feature — it's the dogfood validation that the whole system produces working software.

### Features that must ship together (coupled dependencies)

| Coupled Set | Reason |
|---|---|
| SAND-01 + SAND-02 + SAND-03 + SAND-04 | Sandbox is not useful until egress + DTU + workspace mount all work together |
| ORCH-03 + ORCH-04 + OBS-03 | State machine, checkpoints, and audit ledger share the same write-path discipline |
| AGENT-01 + AGENT-02 + AGENT-05 | LLM adapter, per-stage routing, and cost telemetry are one subsystem |
| SPEC-01 + SPEC-02 + SPEC-03 | Editor, executable scenarios, and verifier are one spec-validation subsystem |
| GIT-01 + GIT-02 + GIT-03 | Git/gh/Actions must all work for the loop to close |

### Conflicts (features that must not coexist in same phase)

- **UI polish (UI-06 brand, UI-04 cost, UI-03 registry)** should trail the execution path. Building brand-book UI before ORCH-02 works wastes effort on pre-functional surfaces.
- **OBS-02 (OTel traces)** should not land before OBS-01 (structured logs + correlation IDs) — traces without correlation IDs are useless.
- **GIT-04 (CI for Kiln)** depends on Kiln compiling and testing itself — pointless until there's enough Kiln to test.

---

## MVP Definition (v1)

**MVP goal:** Kiln ships one non-trivial spec end-to-end for an Elixir project, unattended, with visible telemetry and a reviewable audit trail.

### Launch With — v1 (all Active REQs in PROJECT.md)

All 32 Active REQs per PROJECT.md § Requirements. Organized by dependency order:

**Foundation (must ship first):**
- [ ] **LOCAL-01, LOCAL-02** — docker-compose + .tool-versions → zero-friction first boot
- [ ] **OBS-01** — correlation IDs + structured logging → debuggable from first line of code
- [ ] **ORCH-01** — YAML workflow schema → the thing runs read

**Execution core:**
- [ ] **ORCH-02, ORCH-03** — stage executor + state machine → runs can start, progress, persist
- [ ] **ORCH-04** — checkpointing → runs resumable
- [ ] **ORCH-07** — idempotency → retries are safe
- [ ] **OBS-03** — audit ledger → every event written append-only
- [ ] **AGENT-01, AGENT-02, AGENT-05** — provider-agnostic adapter + per-stage routing + cost telemetry

**Sandbox:**
- [ ] **SAND-01, SAND-02, SAND-03, SAND-04** — Docker + egress block + DTU + workspace mount (ship as a unit)

**Agents:**
- [ ] **AGENT-03** — specialized agent roles (Planner, Coder, Tester, Reviewer, UI/UX, QA/Verifier, Mayor)
- [ ] **AGENT-04** — shared memory (beads-equivalent)

**Spec loop:**
- [ ] **SPEC-01, SPEC-02, SPEC-03** — spec editor + executable scenarios + verifier
- [ ] **ORCH-05** — loop-until-spec-met
- [ ] **ORCH-06** — bounded autonomy caps + escalation

**GitHub:**
- [ ] **GIT-01, GIT-02, GIT-03** — git/gh/Actions integration

**Observability:**
- [ ] **OBS-02** — OTel traces
- [ ] **OBS-04** — stuck-run detector

**Operator UI:**
- [ ] **UI-01** — run board
- [ ] **UI-02** — run detail (stage graph + diff + logs + events + chatter)
- [ ] **UI-03** — workflow registry (read-only YAML viewer)
- [ ] **UI-04** — token/cost dashboard
- [ ] **UI-05** — audit ledger view
- [ ] **UI-06** — Kiln brand book applied

**Dogfood:**
- [ ] **GIT-04** — CI for Kiln itself
- [ ] **LOCAL-03** — README zero-to-first-run

### Gap filings (features without REQ-IDs in PROJECT.md)

| Gap | Feature | Recommendation |
|---|---|---|
| **G-01** | **Secrets handling (secret references, never inline)** | Add **SEC-01** to Active: "Kiln stores secret *references* only; never renders values in UI or logs. Secrets injected into sandbox via short-lived credentials; rotated per-run where possible." |
| **G-02** | **Effective-context inspector per stage** (context window doc footgun #3) | Consider adding **UI-07** to Active: "For any stage, render: attached artifacts, workflow version, prompt bundle hash, tools/MCP available, policy constraints." Low effort if artifacts are already durable; high operator-trust payoff. |
| **G-03** | **Raw-vs-pretty log toggle** (context window doc footgun #9) | Consider folding into UI-02 scope: "Logs render in pretty mode by default; operator can toggle to raw to see full paths, commands, errors." |
| **G-04** | **"Actual model used" recording** (context window doc footgun #2 — silent fallback) | Consider folding into AGENT-05: recording *requested* and *actual* provider+model per call. One extra column; big auditability gain. |
| **G-05** | **Policy/capability surface per stage** | Deferred for v1: capability declarations are overkill for solo-op. Revisit when teams/RBAC (AF-02) ever returns. |
| **G-06** | **Holdout scenarios (spec-not-visible-to-coder-agent)** | StrongDM's pioneering insight. Consider adding **SPEC-04** to Active: "Verifier scenarios are stored where Coder/Planner cannot read them; only Verifier accesses them." This is the single most impactful quality feature from the StrongDM writeup, and it is not in PROJECT.md v1 yet. **Strong recommendation: add it.** |

### Add After Validation — v1.1

Features that extend v1 once single-user flow is proven.

- [ ] **Parallel runs** — v1 runs sequentially; v1.1 lifts to N concurrent. Requires concurrency caps + per-run sandbox pool.
- [ ] **Time-travel replay (interactive UI)** — Ledger already stores events (OBS-03); v1.1 adds "replay this run from stage N" UI.
- [ ] **Run comparison** — Side-by-side of two runs for the same spec. Useful for prompt-engineering iteration.
- [ ] **Workflow templates / preset library** — One template per software-type (Elixir lib, CLI, Phoenix app, etc.) — not a marketplace, just starter YAML in the repo.
- [ ] **Cost optimization advisor** — "This run used Opus at stage X where Sonnet would have been cheaper."
- [ ] **Diagnostic artifact bundle** — When a run escalates, auto-package logs + traces + diffs + spec + ledger slice into a downloadable zip.

### Future Consideration — v2+

Features deferred until product-market fit; most are already in PROJECT.md Out of Scope.

- [ ] **Team/RBAC** — only after solo self-use proven
- [ ] **Hosted runtime** — only if local self-hosting becomes a real adoption blocker
- [ ] **Workflow marketplace** — only if enough workflows exist to be worth sharing
- [ ] **Event sourcing (full)** — only if audit/replay needs outgrow append-only ledger
- [ ] **Mobile operator companion** — only if operators demonstrably need mobile check-in

---

## Feature Prioritization Matrix

Prioritized within v1 scope. Priority reflects *ordering within v1*, not exclusion (everything in Active is P1 or P2).

| REQ-ID | Feature | User Value | Impl Cost | Priority |
|---|---|---|---|---|
| LOCAL-01 | docker-compose up | HIGH | LOW | P1 |
| LOCAL-02 | .tool-versions | HIGH | LOW | P1 |
| OBS-01 | correlation IDs + logging | HIGH | LOW | P1 |
| ORCH-01 | YAML workflow schema | HIGH | MED | P1 |
| ORCH-03 | state machine | HIGH | MED | P1 |
| ORCH-02 | stage executor | HIGH | MED | P1 |
| ORCH-04 | checkpointing | HIGH | MED | P1 |
| ORCH-07 | idempotency | HIGH | MED | P1 |
| OBS-03 | audit ledger | HIGH | MED | P1 |
| AGENT-01 | LLM adapter | HIGH | MED | P1 |
| AGENT-02 | per-stage model | MED | LOW | P1 |
| AGENT-05 | cost telemetry | HIGH | MED | P1 |
| SAND-01 | Docker sandbox | HIGH | HIGH | P1 |
| SAND-02 | egress block | HIGH | MED | P1 |
| SAND-04 | workspace mount | HIGH | MED | P1 |
| SPEC-01 | spec editor | HIGH | MED | P1 |
| SPEC-02 | executable scenarios | HIGH | HIGH | P1 |
| SPEC-03 | verifier | HIGH | HIGH | P1 |
| ORCH-05 | loop-until-spec-met | HIGH | MED | P1 |
| ORCH-06 | bounded autonomy | HIGH | MED | P1 |
| OBS-04 | stuck-run detector | HIGH | LOW | P1 |
| GIT-01 | git commit/push | HIGH | LOW | P1 |
| UI-01 | run board | HIGH | MED | P1 |
| UI-02 | run detail | HIGH | MED | P1 |
| SAND-03 | DTU mocks | HIGH | HIGH | P2 |
| AGENT-03 | specialized agents | HIGH | HIGH | P2 |
| AGENT-04 | shared memory (beads) | MED | MED | P2 |
| GIT-02 | PR via gh | MED | LOW | P2 |
| GIT-03 | Actions status sync | MED | MED | P2 |
| GIT-04 | Kiln CI | MED | LOW | P2 |
| OBS-02 | OTel traces | MED | MED | P2 |
| UI-03 | workflow registry | MED | LOW | P2 |
| UI-04 | cost dashboard | MED | MED | P2 |
| UI-05 | audit ledger view | MED | LOW | P2 |
| UI-06 | brand book applied | MED | MED | P2 |
| LOCAL-03 | README | HIGH | LOW | P2 |
| **G-01 (proposed SEC-01)** | secrets references | HIGH | MED | **P1** (add) |
| **G-06 (proposed SPEC-04)** | holdout scenarios | HIGH | MED | **P1** (add) |

**Priority key:**
- **P1 (21 + 2 proposed):** Must ship in v1 initial cut — the minimum that makes "autonomous spec-to-ship" actually work.
- **P2 (13):** Ship before v1 release — the minimum that makes v1 *trustable* and *operator-ready*.
- **P3:** None in v1. Everything v1-scoped is P1 or P2.

---

## Phase-Ordering Implications

From the dependency graph and MVP cut, suggested phase structure:

1. **Phase 1 — Foundation & Observability**
   - LOCAL-01, LOCAL-02, OBS-01, OBS-03 (ledger write path)
   - *Addresses:* install friction (Fabro/GSD-2 adoption failure mode), undebuggable-from-day-one (context window doc footgun #9).

2. **Phase 2 — Workflow Engine Core**
   - ORCH-01, ORCH-02, ORCH-03, ORCH-04, ORCH-07
   - *Addresses:* durable-unit-of-work (Gas Town Beads lesson), resume-from-checkpoint (Fabro lesson), idempotent side effects (Oban/GSD-2 lesson).

3. **Phase 3 — LLM Adapter & Cost**
   - AGENT-01, AGENT-02, AGENT-05
   - *Addresses:* vendor lock-in, silent fallback (context window doc footgun #2), cost runaway (GSD-2 public reports).

4. **Phase 4 — Sandbox + DTU**
   - SAND-01, SAND-02, SAND-03, SAND-04
   - *Addresses:* safe unattended execution; StrongDM-proven deterministic mocks; 2026 category standard (microVM/gVisor/Docker).

5. **Phase 5 — Agent Tree & Shared Memory**
   - AGENT-03, AGENT-04
   - *Addresses:* Gas Town mayor/worker pattern mapped to OTP; durable work tracking without external Dolt dependency.

6. **Phase 6 — Spec, Verification, Bounded Loop**
   - SPEC-01, SPEC-02, SPEC-03, ORCH-05, ORCH-06, OBS-04
   - *Addresses:* the full dark-factory loop; bounded autonomy is the category's dominant reliability issue.

7. **Phase 7 — GitHub Integration**
   - GIT-01, GIT-02, GIT-03
   - *Addresses:* closing the loop — code lands in git, CI runs, factory sees result.

8. **Phase 8 — Operator UI**
   - UI-01, UI-02, UI-03, UI-04, UI-05, UI-06
   - *Addresses:* control-room UX (context window doc core thesis); brand book applied last after functionality is locked.

9. **Phase 9 — Dogfood & OTel Polish**
   - GIT-04, OBS-02, LOCAL-03
   - *Addresses:* Kiln-on-Kiln validation; vendor-agnostic observability ready for v2+ export; zero-to-first-run docs.

**Research flags for phases:**

| Phase | Needs Deeper Research? | Why |
|---|---|---|
| Phase 1 | No | Oban + Phoenix patterns well-established |
| Phase 2 | **Yes (moderate)** | Workflow YAML schema design is opinion-heavy; research Fabro DOT + GitHub Actions YAML + Temporal workflow schemas for inspiration |
| Phase 3 | No | LLM adapter behaviors are a solved pattern (AGENT-01 behavior + per-provider modules) |
| Phase 4 | **Yes (high)** | DTU design is novel territory; only StrongDM has public writeup; needs design doc before build |
| Phase 5 | **Yes (high)** | Beads-equivalent in native Elixir; Gas Town's Dolt approach has public fragility reports; Kiln must not repeat those failure modes |
| Phase 6 | **Yes (high)** | Bounded autonomy cap semantics (what counts as a "step"? interaction between retries and cost caps?) is the category's hardest unsolved problem |
| Phase 7 | No | `gh` CLI + git shell-out is boring and standard |
| Phase 8 | No (design only) | LiveView streams + PubSub patterns well-established; brand book is locked in kiln-brand-book.md |
| Phase 9 | No | Standard dogfood + docs work |

---

## Competitor Feature Analysis — Synthesis

For each competitor cluster, summary of what to adopt vs. reject:

### StrongDM (internal software factory)
- **Adopt:** Holdout scenarios (agents can't read tests), Digital Twin Universe for third-party mocks, no-human-reads-code posture, scenarios-as-BDD (LLM-as-evaluator), entitlement visibility UI pattern.
- **Reject:** Internal/closed-source; team-first; enterprise-auth first; heavy operator role separation.
- **Kiln posture:** Copy scenarios + DTU + no-human posture verbatim. Ignore everything team/enterprise-sized.

### Gas Town / Beads / Wasteland
- **Adopt:** Mayor/worker hierarchy, durable work ledger, escalation primitives (`gt escalate`), work-history persistence across sessions.
- **Reject:** External Dolt dependency (fragility reports), CLI-first UX, Wasteland federation (out of scope), sidecar issue tracker as runtime state.
- **Kiln posture:** Map Mayor/worker directly to OTP supervisor/worker. Use Postgres for the ledger (not Dolt). Elixir-native beads-equivalent.

### Fabro
- **Adopt:** Workflow-as-code (versioned graph files), stage-level git checkpointing, structured event stream, same engine for CLI + server, per-step model routing.
- **Reject:** Graphviz DOT syntax (less portable than YAML), human gate hexagons (anti-feature for Kiln), cloud VMs as default sandbox.
- **Kiln posture:** Copy workflow-as-code and checkpointing philosophy. Use YAML not DOT. Docker locally, no cloud VM default.

### Devin (Cognition)
- **Adopt:** Sandboxed compute environment, PR-based output, dynamic re-planning on roadblock (maps to ORCH-05 loop).
- **Reject:** Single-vendor (Anthropic-only), opaque ACU billing, no public workflow-as-code, reported parallel-session management issues.
- **Kiln posture:** Adopt the "autonomous end-to-end" target. Reject the billing + lock-in patterns.

### Factory.ai (Droids)
- **Adopt:** Parallel droid execution (v1.1+), persistent-computer-per-droid pattern (maps to stateful worker session in Kiln), Missions decomposition pattern.
- **Reject:** Enterprise-first (SOC2/SSO/SAML gate), hosted-only, proprietary Droid kinds.
- **Kiln posture:** Missions decomposition is essentially what Kiln's workflow graph already does. No enterprise features v1.

### OpenHands (OpenDevin)
- **Adopt:** OSS posture, Docker sandbox default, model-flexibility via OpenRouter/Ollama/direct.
- **Reject:** Planning Mode (human approval gate), cloud platform as differentiator.
- **Kiln posture:** Most direct architectural parallel. Kiln diverges on: no approval gates, BEAM-native, YAML workflows, DTU.

### Claude Code Agent Teams
- **Adopt:** Team-lead / teammate decomposition, shared task list, peer messaging, file locking.
- **Reject:** Anthropic-only, chat-first UX, in-IDE assumption.
- **Kiln posture:** Agent Teams' team-lead = Kiln's Mayor. Different runtime (BEAM vs. Claude sessions), different UX (control room vs. terminal).

### Cursor Composer / GitHub Copilot Workspace / Replit Agent 4
- **Adopt:** Essentially nothing — different category (in-IDE pair programming, not unattended factory).
- **Reject:** The entire in-loop-human-supervising pattern.
- **Kiln posture:** Not competitors. Included in matrix only to contrast UX models.

### Aider / SWE-agent / AutoGPT
- **Adopt:** Aider's git-first discipline (every change is a commit); SWE-bench as a scenario-eval benchmark pattern.
- **Reject:** Terminal-first UX (Aider), research-only scope (SWE-agent), early-autonomy footguns (AutoGPT's loops-without-bounds became the cautionary tale the whole category reacted to).
- **Kiln posture:** AutoGPT's failures are the negative example Kiln's bounded autonomy is designed around.

---

## Sources

**Primary (HIGH confidence):**
- PROJECT.md (Kiln) — `/Users/jon/projects/kiln/.planning/PROJECT.md`
- software dark factory prompt.txt — vision + direct inspirations
- software dark factory prompt feedback.txt — constraints, bounded-autonomy lessons, output contracts
- dark_software_factory_context_window.md — four-layer mental model, UX anti-patterns, footgun list
- kiln-brand-book.md — brand voice + visual contract
- Fabro official docs + GitHub README — workflow-as-code, DOT graphs, stylesheets, checkpoints
- Gas Town GitHub + Steve Yegge Medium "Gas Town: from Clown Show to v1.0" (Apr 2026) — Mayor/worker, Beads, escalation
- StrongDM public "Software Factory" writeup (Feb 2026) via Simon Willison + StrongDM blog + Stanford CodeX analysis — DTU + holdout scenarios

**Competitor analyses (MEDIUM–HIGH confidence):**
- Cognition Devin 2026 review (popularaitools.ai, morphllm.com, digitalapplied.com)
- Factory.ai "Factory is GA" + Code Droid technical report (factory.ai)
- OpenHands 1.6.0 release notes (Mar 2026) + official docs (openhands.dev)
- Replit Agent 3/4 (replit.com discover)
- Cursor Composer + GitHub Copilot Agent Mode 2026 comparisons (truefoundry, nxcode, makerpad)
- Aider (terminal git-first tool); SWE-agent (research); AutoGPT (Wikipedia + codecademy)
- Claude Code Agent Teams official docs (code.claude.com/docs/en/agent-teams)

**Ecosystem / patterns (MEDIUM confidence):**
- "Agents at Work: 2026 Playbook for Reliable Agentic Workflows" (promptengineering.org)
- Northflank / E2B / Koyeb sandbox comparisons (Firecracker/gVisor/Docker guidance)
- Morph "We Tested 15 AI Coding Agents (2026)" market survey
- NVIDIA "Practical Security Guidance for Sandboxing Agentic Workflows"
- Gryph audit-trail project (safedep.io) — local-first audit-trail design patterns

---

*Feature research for: Kiln (software dark factory, Elixir/Phoenix)*
*Researched: 2026-04-18*
*Confidence: HIGH overall; MEDIUM on feasibility of some v1 features (flagged in phase-ordering research flags)*
