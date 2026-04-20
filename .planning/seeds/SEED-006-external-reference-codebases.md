---
id: SEED-006
status: dormant
planted: 2026-04-20
planted_during: v0.1.0 / Phase 3 planning (captured mid-session from operator)
trigger_when: Phase 7 workflow engine build OR Phase 8 intake UX (INTAKE-01..03) OR any milestone scoping touching "reference", "analog", "prior art", "example project", "ADR import", or when a phase's CONTEXT.md cites external repos the agents can't actually read
scope: Medium
---

# SEED-006: External Reference Codebases — Attach Other Repos as Read-Only Context

## Why This Matters

Today, when Kiln plans or codes a phase, every agent's worldview is bounded by the current project's working directory. If the operator says *"build this like the adapter layer in `plausible/plausible`"* or *"follow the style of `phoenixframework/phoenix`"* or *"this is analogous to how we did it in `my-prior-project`"*, the agents can't actually **see** the referenced code. They can only see the operator's description of it.

That produces two failure modes:

1. **Invented analogs.** The agent confidently writes "following the Phoenix controller pattern" and produces something that isn't actually the Phoenix controller pattern — because nobody in the context ever read a real Phoenix controller.
2. **Shallow imitation.** Even when the description is accurate, the agent can't copy the *tone*, *file layout*, *test structure*, or *naming idioms* — the things that make a codebase feel coherent — because those live in the bytes, not the description.

The current workaround is copy-pasting snippets into CONTEXT.md, which: (a) doesn't scale past 2-3 files; (b) rots as the reference repo evolves; (c) puts the operator in the role of "librarian curating snippets," which is exactly the role Kiln is supposed to eliminate.

## When to Surface

- **Phase 7 workflow engine build** — once stages can accept richer per-stage context, read-only references become a natural new field on the stage input. Before that, there's nowhere good to plug them in.
- **Phase 8 intake UX (INTAKE-01..03)** — the spec editor is the natural place for "attach reference repos" (paste a GitHub URL, pick a local path, pin a ref). The inbox should also surface "this spec mentions repo X — add it as a reference?" as a nudge.
- **Any milestone scoping mentions**: `reference`, `analog`, `prior art`, `example project`, `ADR import`, `style guide repo`, `similar implementation`, or when a phase's CONTEXT.md cites an external repo the agents can't actually read.
- **First time an operator asks "can Kiln look at repo X?"** — answer is currently "no, paste the relevant bits into CONTEXT.md," which is a rough moment.

## Scope

**Medium.** Two natural mini-phases:

### 1. Minimum viable version (Small-to-Medium)

A `.planning/references.yaml` (or `.kiln/references.yaml`) file listing:

```yaml
references:
  - name: phoenix
    source: github
    url: https://github.com/phoenixframework/phoenix
    ref: v1.8.5                      # tag | branch | commit
    subdir: lib/phoenix/controller   # optional narrow scope
    purpose: "canonical Phoenix controller patterns"
    load_on: [planner, researcher]   # which agents see this
    max_context_tokens: 20000        # budget cap

  - name: my-prior-project
    source: local
    path: /Users/jon/projects/old-thing
    purpose: "reference implementation for the worker pool pattern"
    load_on: [planner]
    max_context_tokens: 10000
```

On workflow boot: fetch/sparse-clone GitHub refs into `.kiln/references/cache/<name>@<ref>/`; validate local paths exist. Expose a small loader (`Kiln.References.load_for/1`) that returns `[{name, path, purpose}]` to any agent that declares `load_on` match. Surface them to researcher/planner/executor the same way CLAUDE.md is surfaced — via a `<references>` block in the agent prompt with "here are N read-only reference repos; consult them when relevant, don't edit them."

### 2. Sandbox integration (Medium — real safety work)

**Critical:** references must flow into stage sandboxes **read-only** and **separately from the egress-blocked DTU network**. Options:

- **Read-only bind mount** — `docker run ... -v .kiln/references:/references:ro,Z`. Simplest; works with existing `System.cmd("docker", ...)` / MuonTrap shape.
- **Tarball injection** — pre-build tarball, inject via `docker cp` before stage starts, delete on stage end. More complex, no host-FS coupling.

Either way:
- References land at a fixed mount point (`/references/<name>/...`) inside the container.
- `--read-only` flag on the mount is non-negotiable.
- References do NOT traverse the egress-blocked network (they're local filesystem objects, not network resources) — so no conflict with the sandbox egress policy locked in D-112.
- Workspace RW mount stays separate; the sandbox diff at stage end still only captures workspace changes, never reference changes (references are immutable).
- Must pass the same "no secrets in container" audit as workspace (no `.env` files, no `.git/config` with credentials) — a `Kiln.References.Sanitizer` step before each fetch strips known secret files.

### 3. GitHub authentication (Small — decide, don't build v1)

Public repos: `gh` CLI or unauthenticated `git clone`. Private repos: defer to v1.1 — requires extending SEED-004 credential management to cover GitHub PATs with a reference-repo-only scope. Plant a todo breadcrumb on that integration.

### 4. Cache policy (Small)

- Cache directory `.kiln/references/cache/<name>@<ref>/` is gitignored (git ignores `.kiln/cache/`).
- Refs pinned by tag/commit are cached forever; refs pinned by branch refresh on workflow boot (configurable via `ref_refresh: never | on_boot | daily`).
- `mix kiln.references.prune` removes stale cache entries (>30 days unused).

### 5. Context budget discipline (Medium — the real UX challenge)

References are seductive — an operator adds 5 large reference repos and suddenly the planner's context is 80% "reference code the planner never actually cites." We need:

- Per-reference `max_context_tokens` cap (forces operator to narrow `subdir`).
- Per-agent-role `load_on` gating (planner doesn't need all references the researcher sees).
- Default-narrow behaviour: when a reference is attached without `subdir`, the loader extracts only README + top 3 most recently modified files + an LLM-produced 200-token summary — the operator has to explicitly opt in to "load the full repo."
- Telemetry: `kiln.references.tokens_consumed` per reference per stage, visible in LiveDashboard. An operator looking at "20% of my context goes to a reference that got cited zero times" is the intended nudge.

## Relationship to existing scope

- **INTAKE-01 / INTAKE-02 (Phase 8)** — the spec editor is the primary attach point. When an operator imports a GitHub issue as a spec, and the issue mentions "like repo X," the inbox can prompt "attach X as a reference?"
- **SEED-003 onboarding templates** — templates can ship with references pre-attached (e.g., the "add a feature to this repo" template **is** a reference-attached workflow).
- **SEED-004 credential management** — private-repo support depends on SEED-004 landing first.
- **D-112 sandbox isolation** — references integrate at the bind-mount layer, not the network layer; the egress-blocked DTU network policy stays unchanged.
- **PROJECT.md constraint "local-first, Docker Compose"** — references are a natural fit for local-first operators; they already have repos on disk; we're just letting them wire them in.
- **CLAUDE.md convention "Secrets are references, not values"** — reuse the `*.Ref` pattern shape: `Kiln.References.Ref` is a lightweight struct pointing at a cache path + `purpose`, not the contents themselves.

## Design open questions

- **Where to store the config?** `.planning/references.yaml` (planning-adjacent, suggests references shape the planning of work) or `.kiln/references.yaml` (runtime-adjacent, suggests references are a runtime input)? Leaning planning-adjacent because references shape *what* gets built.
- **Per-phase vs. project-wide?** Default project-wide (in `.planning/`); allow per-phase override in `.planning/phases/NN-*/references.yaml` for phases that need a narrow reference set.
- **Should the workflow YAML reference references by name?** E.g., `stage: planning, references: [phoenix]` — lets the operator scope references per-stage, not just per-agent-role. Probably yes, but defer to when the workflow engine (Phase 7) actually accepts per-stage inputs.
- **Versioning strategy when a GitHub ref moves.** Lockfile (`.kiln/references.lock.json`) recording the exact commit SHA the cache was built from, verified on every workflow boot? Yes — this is the right shape.
- **Do agents get to EDIT references?** No, hard-no. References are read-only. If the operator wants to work on repo X, it goes in the working directory, not references.

## Breadcrumbs

- `.planning/REQUIREMENTS.md` INTAKE-01 (Phase 8) — "freeform text / import markdown / convert GitHub issue into spec draft" is the attach point.
- `.planning/REQUIREMENTS.md` SELF-07 — "external signal capture" touches the same conceptual space (external signals as agent input).
- `.planning/ROADMAP.md` Phase 7 (workflow engine) — per-stage inputs are where references plug in.
- `.planning/ROADMAP.md` Phase 8 (intake UX) — UI for attaching references lives here.
- `.planning/PROJECT.md` "Kiln is an orchestrator of external agents" — references are another flavor of "external" input.
- `.planning/phases/03-agent-adapter-sandbox-dtu-safety/03-CONTEXT.md` D-112 sandbox policy — defines the bind-mount + egress-blocked shape that references must fit into.
- `CLAUDE.md` Conventions — "No Docker socket mounts" + "Secrets are references, not values" — two precedents for how to shape this cleanly.
- `SEED-003 onboarding templates` — templates-plus-references is a natural UX pairing.
- `SEED-004 credential management` — dependency for private-repo references.

## Recommended next step when triggered

1. Spike: hand-author a `.planning/references.yaml`, write a 50-line `Kiln.References.load_for/1`, pipe it into one gsd-planner call on a throwaway phase, observe whether the agent actually cites the reference. Goal: validate the *signal* before building the UX.
2. If the spike shows the agent uses references well: promote into Phase 7 workflow engine as first-class per-stage input.
3. If the spike shows references get ignored: revisit prompt shape before building UX — probably the issue is "agents don't know to look there," which is a prompt-engineering problem, not a config problem.
4. Sandbox integration (Option 1 above) ships alongside Phase 8 intake UX — attaching a reference from the spec editor that can't actually reach the sandbox is a worse experience than not offering references at all.
