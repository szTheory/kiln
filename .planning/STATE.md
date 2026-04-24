---
gsd_state_version: 1.0
milestone: v0.6.0
milestone_name: — Attach existing repo first
status: shipped
last_updated: "2026-04-24T17:40:00.000Z"
last_activity: 2026-04-24 -- Milestone v0.6.0 archived and tagged after attach delivery and proof closure
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 10
  completed_plans: 10
  percent: 100
---

# Project State

## Project Reference

See: [.planning/PROJECT.md](PROJECT.md)

**Core value:** Given a spec, Kiln ships working software with no human intervention — safely, visibly, and durably.

## Current Position

Phase: milestone close-out
Plan: Archived
Status: Milestone v0.6.0 shipped — ready for next milestone definition
Last activity: 2026-04-24

## Current focus

Latest shipped milestone: **v0.6.0 — Attach existing repo first** — [ROADMAP.md](ROADMAP.md) · [PROJECT.md](PROJECT.md) · [.planning/milestones/v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md)

Last shipped phase: **31 — Draft PR trust ramp and attach proof** (**TRUST-01, TRUST-03, GIT-05, UAT-05**).

**Next command:** **`/gsd-new-milestone`** — define the next shipped slice from the v0.6.0 baseline.

## Milestone note

v0.3.0 remains archived at tag **`v0.3.0`**. v0.4.0 shipped at tag **`v0.4.0`**. v0.5.0 established the first believable local run, and v0.6.0 shipped the first believable attach-to-existing workflow. **999.3** and **999.4** remain backlog work outside any active milestone.

## Session continuity (recent CONTEXT files)

- Phase 22: [.planning/phases/22-merge-authority-operator-docs/22-CONTEXT.md](phases/22-merge-authority-operator-docs/22-CONTEXT.md)
- Phase 21: [.planning/phases/21-containerized-local-operator-dx/21-CONTEXT.md](phases/21-containerized-local-operator-dx/21-CONTEXT.md)
- Phase 20: [.planning/phases/20-phase-19-verification-planning-ssot/20-CONTEXT.md](phases/20-phase-19-verification-planning-ssot/20-CONTEXT.md)
- Phase 19: [.planning/phases/19-post-mortems-soft-feedback/19-CONTEXT.md](phases/19-post-mortems-soft-feedback/19-CONTEXT.md)
- Phase 12 (local Docker DX): [.planning/phases/12-local-docker-dx/](phases/12-local-docker-dx/)

**Last backlog execution:** 999.2 — shipped 2026-04-22.

**Last phase execution:** 24 (Template -> run UAT smoke) — completed 2026-04-23.
**Last phase execution:** 25 (Local live readiness SSOT) — completed 2026-04-23.
**Last phase execution:** 26 (First live template run) — completed 2026-04-24.
**Last phase execution:** 27 (Local first-run proof) — completed 2026-04-24 and later superseded for requirement ownership.
**Last phase execution:** 28 (First-run proof runtime closure) — completed 2026-04-24.
**Last phase execution:** 29-01 (Attach entry surfaces) — completed 2026-04-24.
**Last phase execution:** 29-02 (Attach entry surfaces) — completed 2026-04-24.
**Last phase execution:** 30 (Attach workspace hydration and safety gates) — completed 2026-04-24.

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
