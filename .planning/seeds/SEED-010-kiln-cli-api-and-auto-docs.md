---
id: SEED-010
status: parked
planted: 2026-04-20
planted_during: v0.1.0 / Phase 3 execution recovery
trigger_when: any milestone touching external integrations, remote operation, public API surface, SDK/CLI ergonomics, developer documentation publishing, or automatic project-site generation
scope: Large (spans operator UX, integration surface, auth, docs, and release defaults)
---

# SEED-010: Kiln CLI/API Surface for Other LLMs + Auto-Maintained Docs/Site

## Why This Matters

If Kiln succeeds, other agents and tools will want a thinner integration surface than "embed a whole editor plugin" or "speak MCP." A local or remote `kiln` CLI that speaks to the running factory over a stable API gives external LLMs and automation a cheap control plane:

- ask Kiln for run status
- enqueue work
- inspect artifacts, audit events, or blockers
- resume/retry using Kiln's typed contracts instead of ad hoc prompts

That same direction naturally collides with documentation. Once Kiln owns structured project state, run history, artifacts, and accepted plans, it should become easier to auto-build:

- indexed developer docs from project artifacts
- a "deepwiki"-style knowledge surface for the current codebase
- optional static project sites with sane defaults for operators who just want something published quickly

This is not a v0.1 blocker. It is a leverage point for future interoperability and operator DX.

## When to Surface

- Any milestone that introduces a public API, SDK, CLI, or remote control surface
- Any milestone that expands remote operator workflows or non-local execution
- Any docs-focused milestone where the question becomes "how do developers keep up with what Kiln has built?"
- Any release-prep milestone where README, project site, and generated docs start diverging from reality

## Scope

### 1. Kiln CLI / thin API surface

- A `kiln` CLI that can talk to the local Phoenix app or a remote Kiln host
- Stable read operations first: status, runs, blockers, artifacts, logs, audit tail
- Then bounded write operations: start run, retry, acknowledge blocker, resume
- Authentication model has to work both locally and remotely without leaking trust boundaries into the sandbox

### 2. Other-LLM interoperability

- External LLMs should be able to use Kiln as a durable execution/control plane without needing deep repo-specific tooling
- The API surface should stay typed and narrow; do not recreate a freeform chat protocol as the primary integration mechanism
- This likely complements, not replaces, any future MCP story

### 3. Auto-maintained docs and knowledge surface

- Generate indexed docs from accepted specs, plans, summaries, and live code structure
- Prefer project-truth sources Kiln already owns over hand-curated prose that will drift
- Provide a fast path for developers to answer "what has Kiln built and why?"

### 4. Static site / publishing defaults

- Offer a low-friction way to publish a project site or docs site with sensible defaults
- Good fit for GitHub Pages or similarly boring static hosting
- Smart defaults matter more than maximum configurability in the early version

## Relationship to Existing Work

- Reinforces [SEED-002](/Users/jon/projects/kiln/.planning/seeds/SEED-002-remote-operator-dashboard.md): remote operation becomes much easier once there is a thin API/CLI surface
- Reinforces [SEED-007](/Users/jon/projects/kiln/.planning/seeds/SEED-007-project-bootstrap-wizard.md): the same structured project state that powers onboarding can power generated docs
- Reinforces [SEED-009](/Users/jon/projects/kiln/.planning/seeds/SEED-009-attach-fork-clone-existing-projects.md): attach/fork workflows get more valuable when external tools can ask Kiln about project state cheaply
- Connects strongly to Phase 6 GitHub integration and Phase 8 operator UX, but should not drag those phases off-course prematurely

## Open Questions

- Is the first public surface a CLI that shells into the local app, an HTTP API, or both?
- How much auth should be built before remote usage is considered acceptable?
- Should generated docs/site output be read-only artifacts, or editable-with-regeneration?
- What is the minimum useful integration surface for another LLM before the CLI/API becomes worth maintaining?

## Recommended Next Step When Triggered

1. Start with a small read-only CLI/API slice over existing run/audit/artifact state.
2. Validate that external automation actually uses it before widening the write surface.
3. Prototype docs generation directly from GSD and runtime artifacts before inventing a separate docs model.
4. Keep site publishing optional and boring; avoid making it a new product line.
