# Dark Software Factory Context Window Supplement

## What this document is

Use this as supplemental context when designing and building **GSD**, a **dark software factory** in **Phoenix LiveView**.

This document is intentionally opinionated. It combines lessons from:

- **Gas Town** for multi-agent orchestration, identity, provenance, and distributed work
- **GSD / Get Shit Done / GSD-2** for context discipline, artifactized work, and phase-based execution
- **Fabro** for deterministic workflow graphs, human gates, checkpointing, and run observability
- **StrongDM** for admin UX, policy, entitlement visibility, secret handling, access workflows, and operator ergonomics

The goal is **not** to clone any one of them.
The goal is to combine their best ideas into a system that is:

1. **fast enough for expert operators**
2. **safe enough for teams**
3. **transparent enough to debug**
4. **structured enough to scale**
5. **simple enough to adopt without a cult initiation ritual**

---

## The core thesis

A successful dark software factory should behave like this:

- **GSD on the inside**: every meaningful unit of work is small, explicit, phase-separated, and grounded in files/artifacts instead of fuzzy chat memory
- **Fabro in the middle**: workflows are deterministic, versioned, resumable, inspectable, and checkpointed after every stage
- **Gas Town at the edges**: every human and agent has identity, work history, attribution, and traceable handoffs
- **StrongDM in the control plane**: permissions, approvals, access requests, secrets, and auditability are first-class rather than bolted on later

In plain English:

> Don’t build “an agent that codes.”
> Build **a governed production system for software changes**.

The product should feel less like “chat with AI” and more like:

- a **mission control room** for software work
- a **run board** for autonomous execution
- a **policy-governed admin console**
- a **developer tool that works great locally**

---

## What to copy and what not to copy

### 1) Gas Town

#### Copy

- **Actor identity and attribution everywhere**. Every action should be attributable to a concrete actor: human operator, workflow, agent, sub-agent, reviewer, or policy gate.
- **Persistent work state outside the model’s chat history**. Gas Town is right that agent memory cannot live only in the context window.
- **Delegation as a first-class workflow primitive**. “Mayor / crew / polecats” is theatrical, but the underlying insight is strong: orchestration needs explicit roles and handoff lanes.
- **Cross-workspace coordination**. If your system is ever going to manage multiple repos, branches, or environments, coordination objects must exist above the single-repo level.
- **Terminal-grade transparency for advanced users**. Power users like being able to see agents doing work in real time.

#### Do not copy

- **Making critical runtime state depend on a sidecar issue tracker or indirect persistence mechanism**.
- **Making setup fragile**. New-user install chains that fail in sequence are poison.
- **Expensive or blocking preflight checks on every command**.
- **Terminal-first as the only UX**. Great for experts, bad default for broader team adoption.
- **Implicit “contribute back upstream” or self-improvement behavior**. Anything that can spend the user’s tokens, credentials, or GitHub identity outside their direct intent must be explicit opt-in.

#### Product lesson

Gas Town is strongest as a lesson in **orchestration semantics** and **agent identity**, not as a template for production-safe shared-state architecture.

---

### 2) GSD / Get Shit Done / GSD-2

#### Copy

- **Task sizing as a hard rule**. If a task cannot fit in one context window, it is too large.
- **Phase discipline**. Separate discuss, plan, execute, verify. Never let planning, coding, and review dissolve into one context soup.
- **Artifact-first state**. Plans, summaries, research, task breakdowns, and runtime state should be explicit artifacts.
- **Fresh-context execution**. Use new sessions/contexts for discrete work units instead of dragging forward long conversation history.
- **Recovery and resume flows**. Pause, resume, progress, and state inspection are not optional. They are core UX.
- **Operator-facing status commands**. The user should always be able to answer: where am I, what ran, what failed, what’s next?

#### Do not copy

- **Prompt-only control when the runtime can provide actual control**.
- **Letting subagents inherit context inconsistently**.
- **Relying on brittle upstream command semantics**.
- **Assuming MCP/tool availability propagates cleanly through orchestration layers**.
- **Stopping for context compaction in a way that feels like a workflow leak to the user**.

#### Product lesson

GSD is strongest as a lesson in **cognitive decomposition** and **stateful workflow artifacts**. Your system should use GSD-like discipline even if the user never sees GSD command names.

---

### 3) Fabro

#### Copy

- **Workflow-as-code**. Version-controlled graph definitions are the right abstraction for repeatable agent pipelines.
- **Deterministic human gates**. Approval steps should be part of the workflow definition, not ad hoc social process.
- **Stage-level checkpoints**. The system should be resumable after interruption.
- **Structured event stream**. Everything important should emit structured events.
- **Same engine for CLI and server**. Local runs and remote/team runs should use the same workflow engine and same underlying definitions.
- **Model routing per step**. Different stages should be able to use different models/providers.
- **Sandbox choice per run**. Local for iteration, isolated remote for risky or heavy work.

#### Do not copy

- **Single-tenant assumptions** if you want a team product.
- **No ACLs / no roles / no rate limiting** in anything that will be shared.
- **Silent capability fallback**. If the chosen model/provider cannot perform required tool work, surface that clearly.
- **Observability that hides the exact path / command / file the user needs to see**.
- **Host-local execution as a default for untrusted code**.

#### Product lesson

Fabro is the best template here for **execution engine design**, **run board UX**, **checkpointing**, and **the “same engine, different interface” principle**.

---

### 4) StrongDM

#### Copy

- **Admin UX that answers “who has access to what, and why?”**
- **Local ergonomics with real policy underneath**. Desktop app + CLI + localhost-style ease is a winning pattern.
- **Access workflows and approval workflows**. Requests, approvals, durations, reasons, and audit should be designed from day one.
- **Entitlements visibility**. Every permission should be explainable.
- **External secret stores and centralized credential management**.
- **Operator wrappers**. If an operator is already logged in, admin tooling should inherit that session instead of requiring separate credential gymnastics.
- **Real audit APIs**. You should be able to stream or query activity programmatically.

#### Do not copy

- **Any friction that forces lots of manual networking / firewall spelunking for simple deployments**.
- **Anything that requires manual RBAC stitching after the fact**.
- **A world where HR / identity / source-of-truth integration is partial and leaves admins doing clerical work**.

#### Product lesson

StrongDM is not a software factory. It is the best inspiration in this set for **control plane quality**, **operator trust**, and **security/admin experience**.

---

## The right mental model for your product

Your Phoenix LiveView system should be built as **four layers**.

### Layer 1: Intent layer
Where humans say what they want.

Objects:

- initiative
- milestone
- slice
- task
- incident / bug / request
- run goal
- approval request

Rules:

- Every unit should have a clear owner, risk tier, target repo, target environment, and definition of done.
- Every task must be small enough to fit in one agent context window.
- If work is ambiguous, route to discuss / discovery instead of pretending it is executable.

### Layer 2: Workflow layer
Where intent becomes a deterministic plan.

Objects:

- workflow template
- stage graph
- decision edges
- verification gates
- approval gates
- rollback branch
- retry policy

Rules:

- Workflows are versioned.
- Workflows are reviewable like code.
- Changes to workflow semantics are migration events, not hidden runtime behavior.

### Layer 3: Execution layer
Where agents, tools, and sandboxes do work.

Objects:

- run
- stage
- sub-run
- worker
- sandbox
- provider/model binding
- checkpoint
- artifact
- diff
- test result

Rules:

- Every stage emits structured events.
- Every stage records actual model/provider/tool usage.
- Every stage can be resumed, retried, or inspected.
- Agent permissions are explicit.

### Layer 4: Control layer
Where policy, access, secrets, and observability live.

Objects:

- actor
- role
- policy
- entitlement
- approval workflow
- secret reference
- audit event
- budget / token policy
- environment policy

Rules:

- A human must be able to answer “why was this allowed?”
- An admin must be able to answer “who could do this?”
- An operator must be able to answer “what actually happened?”

---

## Opinionated architecture recommendation for Phoenix LiveView

## Why Phoenix LiveView is a strong fit

Phoenix LiveView is a good fit because it keeps state on the server, sends diffs over the wire, supports rich real-time interfaces with minimal client-side JavaScript, and maps naturally to a control-room style UI with streams, run boards, approvals, and live logs.

## Recommended product architecture

### UI / control plane

- **Phoenix LiveView** for the main operator UI
- Live dashboards for:
  - run board
  - stage detail
  - event stream
  - approvals inbox
  - agents / workers
  - budgets / cost / quotas
  - secrets / environment health
  - audit and entitlements

### Core app state

- **Postgres** as the system of record
- Strong recommendation: use **append-only event tables** for runs and approvals, plus materialized read models for the UI
- Do **not** make the canonical runtime state depend on chat transcripts, browser session state, or an indirect issue tracker

### Workflow engine

- Define workflows in a versioned DSL or structured graph format
- Keep **workflow version**, **stage version**, and **prompt bundle version** explicit
- The LiveView UI and CLI should talk to the **same engine**
- Local and remote execution should use the same run semantics

### Execution runners

Support at least three runner modes:

1. **local** — fastest feedback, lowest isolation
2. **container** — default safe execution mode
3. **remote sandbox** — for risky, long-running, or previewable work

Never blur these together in the UI. The operator should always know where code is running.

### Identity model

Make identity a first-class table, not a naming convention.

Actors should include:

- human operator
- reviewer
- admin
- workflow template
- agent session
- sub-agent session
- automation/service account

Every event, artifact, diff, approval, retry, or deploy should point back to an actor.

### Policy engine

Use a policy layer for:

- which workflows can run in which environments
- which tools/models can access which secrets
- when approval is required
- which repos or paths are writable
- which network destinations are allowed
- what cost / token ceiling applies
- what actions require justification or MFA-like confirmation

### Secrets

- Keep secrets outside agent sandboxes by default
- Prefer secret references, not inline secret values
- Use short-lived credentials when possible
- Support external stores from day one
- Make the UI show **what secret class is being used**, not the value

### Observability

You need both:

- **human-readable logs**
- **machine-queryable events**

Record:

- prompt bundle version
- actual model/provider used
- tool invocations
- file writes
- diffs
- retries
- cost/tokens
- human approvals
- policy evaluations
- network accesses (where possible)

And importantly:

- preserve **full paths / commands / error messages** in inspect mode
- provide **pretty mode** without hiding critical details

### Deploy / upgrade / maintain

Design upgrades like database products do:

- versioned schema migrations
- versioned workflow migrations
- compatibility checks before deploy
- dry-run upgrade mode
- rollback instructions generated automatically
- node/runner health checks
- post-upgrade validation run

Do not make users discover incompatibilities through broken runs.

---

## Product UX by persona and job-to-be-done

## Persona 1: Individual expert engineer

### JTBD

- “I want to turn a rough idea into a safe, reviewable run without babysitting every prompt.”
- “I want to move quickly locally, but still have structure.”
- “I want to inspect and fix exactly where the run went wrong.”

### Great UX for this persona

- one obvious **Start Run** entry point
- choose: quick fix / feature / refactor / migration / investigate
- show expected workflow before start
- show risk level before start
- default to small slices, not giant autonomous missions
- real-time stage view with raw + pretty logs
- resume / retry / fork run from checkpoint
- inline diff review per stage
- “what changed since last checkpoint?”
- one-click “open this stage locally”

### Anti-patterns

- giant monolithic chat transcript
- hidden model/provider changes
- only one giant final diff
- magic resume behavior with no visible checkpoint model

---

## Persona 2: Tech lead / reviewer

### JTBD

- “I want to know whether this run is safe, aligned, and worth merging.”
- “I want to review the process, not only the output.”

### Great UX for this persona

- run summary card: goal, workflow, repo, branch, risk, time, cost, operator
- per-stage artifacts: brief, output, tests, diffs, review notes
- explicit verify gates
- approval queue with required context
- ability to compare two runs for the same task
- clear provenance: who approved, which model ran, which tests passed
- replayable timeline

### Anti-patterns

- approvals with no context
- “trust me, the agent handled it”
- no way to inspect why a workflow routed the way it did

---

## Persona 3: Platform/admin/security operator

### JTBD

- “I want this thing to be easy to deploy and easy to govern.”
- “I want to know who can do what, why they can do it, and what they did.”
- “I want to integrate it into existing identity, secret, and environment systems.”

### Great UX for this persona

- access workflows
- approval workflows
- entitlement visibility
- policy simulation / dry run
- secret store integration UI
- runner inventory and health
- environment reachability / connectivity checks
- audit search by actor, repo, environment, secret class, workflow, run
- local session wrappers for admin tasks
- version / upgrade center

### Anti-patterns

- burying critical settings across scattered pages
- forcing SSH and firewall debugging for every basic install
- no explanation of why a user/agent had access
- making admins manage separate auth for UI, CLI, API, and automation manually

---

## Persona 4: Product manager / non-operator stakeholder

### JTBD

- “I need confidence that this system is making progress and not creating invisible risk.”

### Great UX for this persona

- milestone progress view
- run throughput and failure rate
- budget burn
- lead time from request to verified change
- common failure classes
- human wait time vs machine work time
- explanation view in plain language

### Anti-patterns

- exposing raw agent chaos as the only view
- no distinction between “queued,” “working,” “waiting on human,” and “blocked by policy”

---

## Onboarding / intermediate / advanced UX

## Onboarding mode

This is where almost all systems in this category fail.

### Requirements

- demo project or dry-run mode
- “hello world” workflow that finishes in minutes
- visible workflow graph before execution
- visible permission model before execution
- visible cost estimate range before execution
- no jargon by default
- clear explanation of local vs remote sandbox
- install doctor that actually completes quickly
- one-click health checks

### What the first-run experience should prove

1. I understand what this thing will do.
2. I understand where it will run.
3. I understand what it can access.
4. I can inspect the result.
5. I can stop it safely.

If onboarding does not prove those five things, adoption will stall.

## Intermediate mode

This is where the product becomes habit-forming.

### Requirements

- reusable workflow templates
- saved environment profiles
- task intake forms that produce structured briefs
- reliable resume/progress/next-step UX
- parallel runs that remain legible
- run comparison
- checkpoint browsing
- “open in local worktree / branch”

## Advanced mode

This is where power users live.

### Requirements

- live run board
- raw event stream
- policy overrides with approval
- multi-model routing editor
- custom workflow authoring
- branch / worktree / sandbox controls
- environment reachability tools
- deep diff provenance
- cost optimization controls
- rate limits, budgets, and priority queues

### The key principle

Advanced UX should feel like a **control room**, not a consumer web app.
But onboarding UX should feel like a **guided product**, not a hacker ritual.

---

## Footguns you must design out from day one

## 1) Hidden runtime state

If critical state lives in surprising places, operators will not trust the system.

**Design rule:** all canonical run state must be queryable from one source of truth.

## 2) Silent model fallback

If a requested model/provider cannot perform the required tool mode, fail loudly or warn loudly.

**Design rule:** record both **requested model** and **actual model used**.

## 3) Context inheritance bugs

Subagents must inherit the right project instructions, skills, MCP/tool availability, and policy constraints.

**Design rule:** create a visible “effective context” inspector per stage.

## 4) Giant review surfaces

If review happens only at the end of a 50-file or 8,500-line diff, the system loses trust.

**Design rule:** review happens per slice and per stage, not only at the PR boundary.

## 5) Parallelism without coordination costs

Parallel work can crush budget, saturate machines, or generate lock contention.

**Design rule:** make concurrency explicit, bounded, and visible.

## 6) Compaction / pause behavior that feels like failure

Users hate when the system unexpectedly stops and tells them to manually re-thread context.

**Design rule:** checkpoint automatically, resume explicitly, and show the user that it is normal.

## 7) Install / upgrade yak shaving

If install is fragile, upgrade is worse.

**Design rule:** provide doctor, validate, migrate, rollback.

## 8) Ambiguous human-in-the-loop semantics

If the system auto-answers, bypasses the flow, or asks the wrong person, trust collapses.

**Design rule:** all human questions and approvals should be durable workflow objects.

## 9) Pretty logs that hide the truth

Truncated paths, compressed error messages, or lost raw commands destroy debuggability.

**Design rule:** always provide a raw inspect mode.

## 10) Security posture that assumes a friendly world

A research-preview security model is fine for a research preview. It is not fine for a shared production console.

**Design rule:** multi-user systems need authz, audit, rate limiting, and tenancy boundaries early.

---

## Non-negotiable product requirements

## Workflow requirements

- workflows are versioned
- every stage has inputs and outputs
- every stage declares required capabilities
- every stage can checkpoint
- every stage can emit human-readable and machine-readable output
- stage failures route deterministically
- verify gates can fail the run even if execution reaches the end

## Agent requirements

- agents have stable actor IDs
- agents can be granted scoped permissions
- subagents inherit policies explicitly
- each stage can show the exact prompt bundle and artifact bundle used
- each stage records actual tools and actual model

## Review requirements

- review occurs at slice/stage boundaries
- diffs are small by default
- there is a clear path from failed verify → fix → re-verify
- humans can inject guidance without corrupting the run history

## Admin requirements

- access workflows
- approval workflows
- entitlement visibility
- secret references
- policy simulation
- audit export / API access
- version / migration center
- environment / runner health

## Deployment requirements

- local-first
- self-hosted remote option
- same engine for local and remote
- container / remote sandbox support
- private-network defaults
- explicit auth configuration
- mTLS or equivalent for machine-to-machine traffic

---

## Recommended UX primitives

These should become first-class LiveView components.

### 1. Run board
Columns should distinguish at least:

- queued
- planning
- executing
- verifying
- waiting for human
- blocked by policy
- failed
- merged / completed

### 2. Stage card
Each stage card should show:

- stage name
- actor
- requested model
- actual model
- sandbox
- permissions level
- elapsed time
- cost
- artifact links
- raw log link
- retry count
- policy decisions

### 3. Approval card
Each approval should show:

- what is being approved
- why approval is required
- who requested it
- risk tier
- duration / scope
- what changes if approved
- relevant diff / artifact / evidence
- approve / deny / ask question

### 4. Entitlements panel
For any actor, show:

- what it can access
- why it can access it
- through which role / policy / grant
- when the grant expires
- last use

### 5. Effective context inspector
For any stage, show:

- attached artifacts
- workflow version
- project instructions
- skills
- MCP/tools available
- policy constraints
- prompt bundle hash/version

### 6. Environment panel
Show:

- local / container / remote
- network policy
- mounted repos
- secret classes attached
- preview URL / SSH / VNC availability
- runner version
- last health check

---

## The best “day to day” experience

A great day-to-day loop looks like this:

1. user opens GSD
2. chooses a workflow template
3. fills a short structured brief
4. sees the proposed execution graph and risk summary
5. starts locally by default for low-risk work
6. watches runs advance in a board, not a chat transcript
7. intervenes only at defined gates or exceptions
8. reviews slice-sized diffs, not giant end-state diffs
9. merges or deploys with provenance intact
10. can later answer exactly what happened, who approved it, and what artifacts justified it

If daily usage feels like “chatting harder,” you have failed.
If it feels like “operating a reliable change-production machine,” you are on the right track.

---

## What “maximally successful” looks like

Your product succeeds if it becomes known for these things:

### 1. It makes autonomous work reviewable
Not just possible. Reviewable.

### 2. It makes advanced workflows legible
Not just powerful. Legible.

### 3. It treats governance as UX
Not as security paperwork.

### 4. It works beautifully on localhost
This is the adoption wedge.

### 5. It scales to remote/team mode without changing the mental model
Same workflow, same artifacts, same run semantics.

### 6. It is explicit about cost, risk, and authority
No silent magic.

### 7. It is recoverable
Crash, restart, resume, inspect, retry.

---

## Final product stance

If you only borrow one lesson from each system, borrow these:

- **Gas Town:** identity + provenance matter as much as raw orchestration
- **GSD:** context discipline beats bigger prompts
- **Fabro:** deterministic workflow graphs beat improvised agent theater
- **StrongDM:** admin trust is a product feature, not a back-office concern

So the design target for your Phoenix LiveView product should be:

> **A local-first, policy-aware, workflow-defined, checkpointed, observable software factory with small-task discipline, stage-level review, strong entitlements, and excellent operator UX.**

That is the shape of a dark software factory people will actually trust.

---

## Research basis (for human review, not necessarily for the LLM context)

This document was grounded in recent public docs, issues, and reviews for:

- Gas Town official docs and GitHub repository
- Gas Town issues around Beads fragility, fresh setup failures, concurrency contention, and command hangs
- DoltHub and other public writeups on real-world Gas Town usage
- GSD / Get Shit Done and GSD-2 official repos and user guide
- GSD issues around subagent configuration, project instruction inheritance, MCP/tool propagation, workflow bypass, pause/compaction friction, and upstream CLI breakage
- Fabro official site and documentation for workflow graphs, server mode, observability, permissions, sandboxes, and security model
- Fabro issues around silent model fallback, log truncation, and Linux/glibc install friction
- StrongDM docs for gateways/relays, access workflows, approval workflows, entitlements visibility, secret stores, Vault, CLI, desktop app, Terraform, and API
- StrongDM G2 reviews for real-world likes/dislikes around setup, onboarding, admin ease, UI rough edges, networking friction, client install, and credential rotation gaps
