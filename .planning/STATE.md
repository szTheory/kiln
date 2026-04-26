---
gsd_state_version: 1.0
milestone: v0.8.0
milestone_name: — Remote Factory & Autonomous Delivery
status: Ready to research
last_updated: "2026-04-26T07:53:57.700Z"
last_activity: 2026-04-24 -- Milestone v0.8.0 opened
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 3
  completed_plans: 3
  percent: 100
---

# Project State

## Project Reference

See: [.planning/PROJECT.md](PROJECT.md)

**Core value:** Given a spec, Kiln ships working software — built, verified, merged, and deployed or published — with no human intervention. Safely, visibly, and durably.

## Current Position

Phase: v0.8.0
Plan: 36-03 complete
Status: Phase 36 complete
Last activity: 2026-04-26 -- Completed phase 36 plan 03

## Current focus

Active milestone: **v0.8.0 — Remote Factory & Autonomous Delivery** — [ROADMAP.md](ROADMAP.md) · [PROJECT.md](PROJECT.md)

Immediate next step: **`/gsd-plan-phase 37`** — start Phase 37: Autonomous Versioning & Release.

## Milestone note

`v0.7.0` shipped bounded brownfield work as a repeatable loop. `vNext` will focus on the next solo-operator JTBD gap after a fresh requirements definition.

## Session continuity (recent CONTEXT files)

- Milestone v0.7.0 Archive: [.planning/milestones/v0.7.0-ROADMAP.md](milestones/v0.7.0-ROADMAP.md)
- Phase 35: [.planning/phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md](phases/35-draft-pr-handoff-and-owning-proof/35-CONTEXT.md)
- Phase 34: [.planning/phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md](phases/34-brownfield-preflight-and-narrowing-guardrails/34-CONTEXT.md)
- Phase 33: [.planning/phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md](phases/33-repeat-run-continuity-on-attached-repos/33-CONTEXT.md)
- Phase 32: [.planning/phases/32-pr-sized-attached-repo-intake/32-CONTEXT.md](phases/32-pr-sized-attached-repo-intake/32-CONTEXT.md)

**Last milestone execution:** v0.7.0 — shipped 2026-04-24.

**Last phase execution:** 36 (Remote Access & Operator Auth) — completed 2026-04-26.

## Accumulated Context

- `29-01` established `/attach` as a route-backed orientation surface with attach-specific ids and honest Phase 30 boundary copy.
- `29-01` kept `hello-kiln` as the single recommended first proof path while adding attach discovery on `/onboarding` and `/templates`.
- `29-02` aligned the operator-facing templates-vs-attach story across `/onboarding`, `/templates`, and `/attach`, and added browser proof for the onboarding-to-attach handoff plus `/attach` route coverage.
- `31-01` added frozen run-scoped attach delivery over persisted attached-repo facts, plus durable push and draft-PR worker payloads.
- `31-02` added `mix kiln.attach.prove` as the owning proof command and aligned milestone artifacts around that exact verification path.
- `v0.6.0` shipped attach discovery, managed brownfield hydration, conservative draft-PR delivery, and one milestone-owning proof path.

## Deferred Items

Items acknowledged and deferred at milestone close on 2026-04-24:

| Category | Item | Status |
|----------|------|--------|
| todo | `2026-04-24-review-orphan-phase-03-worktree-residue.md` | acknowledged at v0.5.0 close and accepted again at v0.6.0 close |
| repo | spawned role-process sandbox ownership noise during repo-wide test execution | observed during v0.6.0 audit and accepted as non-blocking tech debt |

**Completed Phase:** 33 (Repeat-run continuity on attached repos) — 3 plans — 2026-04-24T16:31:30Z
