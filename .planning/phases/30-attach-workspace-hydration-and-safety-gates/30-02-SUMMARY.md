---
phase: 30-attach-workspace-hydration-and-safety-gates
plan: "02"
subsystem: database
tags: [attach, workspace, ecto, git, github]
requires:
  - phase: 30-attach-workspace-hydration-and-safety-gates
    provides: "Canonical attach source resolution for local paths and GitHub URLs"
provides:
  - "Managed attach workspace root with deterministic hydrate or reuse behavior"
  - "Durable attached-repo metadata keyed to one canonical source"
  - "Narrow Kiln.Attach API for workspace hydration and later branch orchestration"
affects: [attach, workspace hydration, trust gates, github delivery]
tech-stack:
  added: []
  patterns: ["Managed workspace root confinement", "Attached repo upsert keyed by canonical source fingerprint"]
key-files:
  created: [lib/kiln/attach/workspace_manager.ex, lib/kiln/attach/attached_repo.ex, priv/repo/migrations/20260424120544_create_attached_repos.exs]
  modified: [config/config.exs, config/runtime.exs, lib/kiln/attach.ex, test/kiln/attach/workspace_manager_test.exs, test/integration/attach_workspace_hydration_test.exs]
key-decisions:
  - "Local-path attaches hydrate into a Kiln-managed mirror instead of mutating the operator's original working tree in place."
  - "Attached repo persistence is keyed by a canonical source fingerprint so future plans can update one durable row instead of rediscovering repo identity."
patterns-established:
  - "Workspace hydration stays behind Kiln.Attach and Kiln.Attach.WorkspaceManager, not in LiveView or future git workers."
  - "Future branch or PR orchestration should read attached repo metadata through Kiln.Attach fetch APIs rather than schema internals."
requirements-completed: [ATTACH-03]
duration: 4min
completed: 2026-04-24
---

# Phase 30 Plan 02: Attach Workspace Hydration Summary

**Managed attach workspace hydration with deterministic reuse, safe root confinement, and durable attached-repo metadata for later branch and PR orchestration**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-24T12:02:58Z
- **Completed:** 2026-04-24T12:07:13Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added a managed attach workspace root and a deterministic workspace manager that clones or reuses exactly one writable workspace per attached repo.
- Aligned attach workspace rooting with the existing GitHub worker allowlist model by making `:attach_workspace_root` and `:github_workspace_root` converge on the same managed root.
- Persisted canonical attached-repo metadata through a narrow `Kiln.Attach` API so Phase 31 can reuse repo identity, workspace bookkeeping, and branch defaults without reparsing sources.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a managed attach workspace root and deterministic hydrate/reuse logic** - `75ba9fe` (test), `ad73df1` (feat)
2. **Task 2: Persist attached repo metadata needed for later run-scoped branch orchestration** - `0c1e24e` (test), `8c8f1b8` (feat)

**Plan metadata:** recorded in the final docs commit for this plan

_Note: TDD tasks used RED -> GREEN commits._

## Files Created/Modified
- `config/config.exs` - Added the default managed attach workspace root and aligned the GitHub worker allowlist root with it.
- `config/runtime.exs` - Added `KILN_ATTACH_WORKSPACE_ROOT` runtime override that updates both attach and GitHub workspace roots together.
- `lib/kiln/attach.ex` - Exposed workspace hydration plus attached-repo upsert and fetch APIs.
- `lib/kiln/attach/workspace_manager.ex` - Implemented deterministic workspace keying, safe root confinement, clone-or-reuse behavior, and branch or remote introspection.
- `lib/kiln/attach/attached_repo.ex` - Added the durable schema for canonical attached-repo and workspace metadata.
- `priv/repo/migrations/20260424120544_create_attached_repos.exs` - Created the `attached_repos` table with constraints, indexes, and runtime-role grants.
- `test/kiln/attach/workspace_manager_test.exs` - Locked the workspace manager and attached-repo persistence contracts with unit tests.
- `test/integration/attach_workspace_hydration_test.exs` - Proved that one resolved source hydrates to one reusable managed workspace.

## Decisions Made

- Local attach sources now clone into a Kiln-managed workspace root instead of operating directly on arbitrary operator paths, which keeps later git mutations behind one allowlisted boundary.
- Attached repo persistence stores both canonical source identity and hydrated workspace bookkeeping, so later plans can create run-scoped branches without rediscovering remote or base-branch facts.
- The upsert boundary is `Kiln.Attach.create_or_update_attached_repo/2`; later run orchestration should depend on that boundary instead of the Ecto schema.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized local workspace remote assertions around canonical macOS paths**
- **Found during:** Task 1 (managed attach workspace root and deterministic hydrate or reuse logic)
- **Issue:** Local git clone remotes canonicalize `/var/...` temp paths to `/private/var/...` on this host, so the original remote assertion was too literal.
- **Fix:** Updated the test expectation to assert against the source contract's canonical repo root instead of the raw temp path.
- **Files modified:** `test/kiln/attach/workspace_manager_test.exs`
- **Verification:** `mix test test/kiln/attach/workspace_manager_test.exs test/integration/attach_workspace_hydration_test.exs`
- **Committed in:** `ad73df1`

**2. [Rule 3 - Blocking] Replaced a real GitHub clone attempt in unit tests with an injected hermetic runner**
- **Found during:** Task 1 (managed attach workspace root and deterministic hydrate or reuse logic)
- **Issue:** The first GitHub hydration test tried to clone a live remote, which would make the plan nondeterministic and network-dependent.
- **Fix:** Added a fake clone runner that initializes a local repo and sets the expected `origin`, keeping the hydration contract testable without network access.
- **Files modified:** `test/kiln/attach/workspace_manager_test.exs`
- **Verification:** `mix test test/kiln/attach/workspace_manager_test.exs test/integration/attach_workspace_hydration_test.exs`
- **Committed in:** `ad73df1`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes kept the plan deterministic and portable without widening scope.

## Issues Encountered

- `WorkspaceManager` initially failed compilation due to an invalid remote typespec reference; tightening the type definition resolved it before GREEN verification.
- The new persistence migration had to be applied to the test database explicitly with `MIX_ENV=test mix ecto.migrate` before the Task 2 test target could pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `Kiln.Attach.hydrate_workspace/2` now returns one deterministic managed workspace result that future trust-gate logic can inspect.
- `Kiln.Attach.create_or_update_attached_repo/2` persists the canonical repo identity, workspace path, and branch metadata Phase 31 needs for branch, push, and draft PR orchestration.
- Attach workspace rooting now aligns with the existing GitHub worker allowlist model, so future git jobs can consume persisted `workspace_path` without introducing a second trust boundary.

## Self-Check: PASSED

- Found summary file: `.planning/phases/30-attach-workspace-hydration-and-safety-gates/30-02-SUMMARY.md`
- Found task commits: `75ba9fe`, `ad73df1`, `0c1e24e`, `8c8f1b8`

---
*Phase: 30-attach-workspace-hydration-and-safety-gates*
*Completed: 2026-04-24*
