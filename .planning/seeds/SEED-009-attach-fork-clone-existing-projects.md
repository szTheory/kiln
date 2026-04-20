---
id: SEED-009
status: dormant
planted: 2026-04-20
planted_during: v0.1.0 / Phase 3 planning (captured mid-session from operator)
trigger_when: Phase 8 intake UX (INTAKE-01..03) OR Phase 9 onboarding wizard scoping OR v1.0 release-prep OR any milestone touching "workspace bootstrap", "project initialization", "existing repo", "fork", "migrate", "port to", "clone into <stack>", or first operator asks "can I point Kiln at my existing project?"
scope: Medium-to-Large (spans intake, workspace hydration, git integration, and sandbox mount semantics)
---

# SEED-009: Attach / Fork / Clone — Kiln Against Existing Projects

## Why This Matters

Kiln's default mental model today is *greenfield*: operator has a spec, Kiln plans, codes, pushes to a repo that exists for that run. But the overwhelmingly more common real-world entry point is **an existing project**:

1. **Attach-to-existing** — Operator has a live repo (personal side-project, work codebase, OSS contribution target). They want to point Kiln at it and say "continue shipping features here" — Kiln treats the existing repo as its workspace, respects its patterns, ships PRs to its upstream.
2. **Fork-and-continue** — Operator finds an interesting repo (abandoned OSS, a useful but incomplete library, a starter template). They want Kiln to fork it, continue work from its current state, and ship to the fork's upstream (not the original).
3. **Clone-to-different-stack** — Operator has a working project in one stack and wants a version in another (`rails-app → phoenix-app`, `express-api → phoenix-liveview`, `python-cli → elixir-cli`, `vue-frontend → liveview-frontend`). Kiln reads the source project's intent (routes, schemas, tests, UX) and builds an equivalent in the target stack. The source repo is read-only input; the target repo is a fresh destination.

Each shape has a different workspace topology, a different git remote policy, and a different "what is read-only vs read-write" contract. Kiln today doesn't have a name for any of them — every run implicitly assumes shape #1 with a repo that was already initialized for Kiln.

## The Three Shapes, Named and Contrasted

| Shape | Source repo | Target repo | Workspace | PR destination | Typical use |
|-------|-------------|-------------|-----------|----------------|-------------|
| **Attach** | = Target (same repo) | Existing, RW | Clone of the live repo | Upstream of that repo | "Continue shipping features on my existing project" |
| **Fork-continue** | Original upstream (read-only) | Fork of original, RW | Clone of the fork | Fork's upstream | "Revive abandoned OSS" / "Build on a template" |
| **Clone-to-stack** | Read-only foreign stack | New empty repo, RW | Empty workspace, source repo mounted read-only (see SEED-006) | New repo's upstream | "Port Rails app to Phoenix" |

Critically: shapes #2 and #3 both need **two concurrent repo contexts** (source + target). SEED-006's read-only reference mount is the right mechanism for the "source" side; this seed defines how the **target** side gets set up.

## When to Surface

- **Phase 8 intake UX (primary trigger)** — the spec editor is where shape selection naturally lives. A "Create new project / Attach existing / Fork & continue / Clone to new stack" picker at spec-creation time is the intuitive surface.
- **Phase 9 onboarding wizard** — the first-run wizard (Phase 8 SC 7) is a natural branch point: after Anthropic/GitHub/Docker checks, ask "do you want to start greenfield or attach to an existing project?"
- **First time an operator asks "can I run Kiln on my existing repo?"** — the answer today is "yes, technically, but there's no flow for it" — that rough moment is the signal.
- **Any OSS-contribution milestone** — shape #2 (fork-and-continue) is the exact shape of "help me contribute to X" which is a plausible v1.1+ use case.
- **Any migration / stack-modernization scoping** — shape #3 (clone-to-stack) intersects with this naturally.

## Scope Decomposition

### Shape 1: Attach-to-existing (Small-to-Medium)

**The cheapest of the three and the highest-value for v1.1.**

- Operator provides a repo source: `github.com/jon/my-saas` OR a local path OR an existing clone path.
- Kiln creates a workspace by cloning (or reusing an existing clone — decide: opinionated fresh-clone vs reuse-in-place).
- Workflow YAML gains an optional `workspace.source:` field alongside `workspace.target:` (or they collapse into one field for attach shape).
- PR destination is the existing repo's upstream; branch naming follows a Kiln-configurable pattern (`kiln/<run-id>` default).
- Workflow runs look at existing code and adapt: researcher reads the existing stack, planner respects existing patterns (SEED-006 already plants the "read-only references" mechanism — in attach mode, the workspace IS the reference).
- **Trust ramp:** first run on an existing repo should be extra-conservative — propose changes in a draft PR, tag the operator for review even in "autonomous" mode. Over time, operator can dial up autonomy.

### Shape 2: Fork-and-continue (Medium)

- Operator provides an upstream URL + a fork destination (GitHub org/user they own).
- Kiln's GitHub integration (Phase 6 `gh` wrapper) does the fork: `gh repo fork upstream --org operator-org --remote false --clone`.
- Workspace is the clone of the fork; `origin` points at the fork, `upstream` at the original (for fetching new commits).
- PR destination = fork's upstream (the fork → original-upstream flow).
- Spec-time decision: **inherit license from upstream** (always) + **carry attribution** (always, via CONTRIBUTING / README patch at first commit if not already present).
- Subtle: the agents must **read the original repo's tone/patterns** and not rewrite in Kiln-default style. SEED-006's read-only reference becomes load-bearing here — the fork IS the reference, loaded at max priority.

### Shape 3: Clone-to-different-stack (Medium-to-Large)

**Highest research density. Probably v2.0, not v1.1.**

- Operator provides: source repo (read-only, any stack), target stack description (Elixir/Phoenix? Go? Rust? Python?), optional "intent only" vs "behavior-equivalent" flag.
- Kiln's researcher stage does a first pass: extract routes/schemas/API shape/auth model/test intent from the source repo.
- Planner produces a phased ROADMAP for the target stack, with each phase in the target stack's idioms (not a 1:1 file mapping).
- Source repo mounted read-only via SEED-006's mechanism; target workspace fresh.
- **Critical constraint:** Kiln must NOT copy source code verbatim across language boundaries — that produces non-idiomatic output and potential license issues for non-OSS sources. Idiom translation only.
- Attribution/provenance: every generated file's commit message cites source files consulted; optional `CREDITS.md` aggregates.

## Key Decisions Each Shape Raises

1. **Workspace lifecycle** — fresh clone per run vs persistent workspace across runs? Attach wants persistent (matches operator's mental model). Fork-continue wants persistent-per-fork. Clone-to-stack wants fresh (target is greenfield).

2. **Branch strategy** — always a feature branch per run (matches Kiln's current implied model) vs long-lived `kiln-factory` branch with per-run merges? Feature-per-run is simpler and more operator-friendly for attach mode.

3. **PR behavior on attach** — every Kiln PR is a draft by default for the first N runs on a new attached repo, auto-promotes after operator approves M successful runs? Operator-overridable, but the default should bias toward caution.

4. **Credentials** — `gh` auth on the operator's host (already scoped for Phase 6). Attach and fork-continue need write scope to the operator's repos/orgs. Clone-to-stack only needs write to the new target repo (plus optional read for the source if it's private — rare).

5. **Existing-workspace state** — if the operator points Kiln at a repo with uncommitted changes / stashes / detached HEAD, what happens? Refuse loudly (default), offer to stash (operator-confirmed), or work from operator's current state (operator asserts they know what they're doing).

6. **Secrets hygiene on attach** — existing repo may contain `.env`, `.env.example`, CI secrets, Dockerfile envs. Before mounting into sandbox, Kiln runs its existing `Secrets.Scanner` (SEC-01) to enumerate and redact. Warn operator before proceeding.

7. **Intent drift detection** — in attach mode, the existing repo may already have in-flight work that contradicts the new spec. Kiln should surface "I see open PRs / unmerged branches / recent commits that may conflict — proceed?" instead of silently ignoring them.

## Relationship to Existing Work

- **Reinforces** SEED-006 (external reference codebases) — shape #3 is the canonical consumer of SEED-006's read-only mount mechanism. Shape #2 uses it for upstream-as-reference.
- **Reinforces** SEED-007 (project bootstrap wizard) — that seed is the greenfield shape; this seed is the other three shapes. Same wizard, different branches.
- **Reinforces** Phase 6 GitHub integration — `gh repo fork`, `gh pr create` already planned; this seed adds `gh repo clone --depth` + attach semantics.
- **Reinforces** Phase 8 INTAKE-01..03 — the spec editor is the primary operator surface for shape selection.
- **Complements** SEED-002 (remote operator dashboard) — remote operator likely attaches to projects from laptop and lets the remote-host Kiln work; the attach flow must be driver-friendly from a non-local UI.

## Scope Estimate

**Medium-to-Large overall, but cleanly separable:**

- **Shape 1 (Attach):** Medium. Primary v1.1 candidate. ~2 phases of work (intake flow + workspace-hydration changes + trust-ramp defaults).
- **Shape 2 (Fork-continue):** Medium. Probably v1.2. Adds 1 phase on top of Shape 1.
- **Shape 3 (Clone-to-stack):** Large. Probably v2.0. Its own milestone — researcher upgrades, cross-stack idiom translation, attribution infrastructure.

Shape 1 alone would unlock ~80% of the operator value ("I want Kiln to work on my real codebase"). Fork and clone-to-stack are differentiating but not blocking v1.

## Open Questions (for the milestone that picks this up)

1. **Attach permission model** — does Kiln get a "per-repo autonomy dial" (fully autonomous vs requires-approval-per-PR vs requires-approval-per-stage)? Probably yes, default to conservative on first attach, relaxable after N successful runs.
2. **Fork fork fork** — if operator forks `A/foo` into `op/foo`, runs Kiln, and later wants to fork `op/foo` again for a variant, does Kiln support multi-fork chains? Probably yes (recursive application of shape #2) but not in v1.1.
3. **Workspace sharing across runs** — two concurrent runs on the same attached repo: serialize, parallel on different branches, or refuse? Probably "parallel on different branches with a warning."
4. **Un-attach** — is there a clean "disconnect Kiln from this project" flow? Probably just: stop scheduling runs against it + offer to clean up the workspace clone. Not much more needed.
5. **Closed-source attach** — private repos: operator's `gh` auth covers it if scoped correctly. Docker sandbox mounts the workspace RW as today. No new primitive required.
6. **Clone-to-stack quality ceiling** — how good can idiom translation actually be before humans write the last 10%? Open-ended. Scaffold the infra, prototype on a known pair (e.g., `plug-based API → phoenix`), measure, decide before committing to v2.0.

## Suggested Experiments Before Committing

- **Shape 1 dogfood:** Once v0.1.0 ships, pick one of the operator's existing personal projects, point an ex-post-facto Kiln attach flow at it (manual workspace hydration for now), run a real feature workflow. Measure: did the PR respect the existing patterns? Did the operator trust the output enough to merge?
- **Shape 2 dogfood:** Fork a real OSS repo with an open issue, have Kiln attempt the fix on the fork. Measure: tone match + commit-message quality + attribution correctness.
- **Shape 3 spike:** Pick a narrow, well-tested source repo (a CLI with 20 tests), try a clone-to-stack into a different language, manually read the output. Measure: idiom quality, behavior equivalence via the source repo's test spec re-rendered in the target language.

---

## One-Line Operator Framing

> "Kiln should treat an existing repo as a first-class starting point, not a greenfield-only special case. Attach is the common case; fork-continue is the OSS case; clone-to-stack is the ambitious case. Make the picker obvious and the defaults safe."

---

*Planted 2026-04-20 during Phase 3 planning. Triggers at Phase 8 intake UX or any scoping that mentions "existing repo", "fork", "migrate", or "port to".*
