---
created: 2026-04-24T08:23:54.823Z
title: Review orphan Phase 03 worktree residue
area: planning
files:
  - .claude/worktrees/agent-af41d79b/lib/kiln/agents/budget_guard.ex
  - .claude/worktrees/agent-af41d79b/lib/kiln/agents/telemetry_handler.ex
  - .claude/worktrees/agent-af41d79b/test/kiln/agents/budget_guard_test.exs
  - .claude/worktrees/agent-af41d79b/test/kiln/agents/telemetry_handler_test.exs
  - .claude/worktrees/agent-af41d79b/test/kiln/audit/append_test.exs
  - .planning/phases/03-agent-adapter-sandbox-dtu-safety/03-VALIDATION.md
---

## Problem

An old locked worktree, `.claude/worktrees/agent-af41d79b`, still contains uncommitted Phase 03 residue after the other stale worktrees were removed. The current main branch already has `Kiln.Agents.BudgetGuard` and `Kiln.Agents.TelemetryHandler`, so this is not missing Phase 28 runtime work. The residue is a mixed bag:

- one plausible behavior tweak in `budget_guard.ex` that relaxes notification gating when `Kiln.Notifications.desktop/2` exists
- mostly comment churn in `telemetry_handler.ex` and related tests
- suspicious test drift in `telemetry_handler_test.exs` (`stage_id` changed from `nil` to `"coding"`)
- weakened audit coverage in `append_test.exs` by deleting `replay/1` coverage and several `minimal_payload_for/1` cases

This should not be folded into unrelated execution branches opportunistically. It needs a deliberate salvage-or-discard decision tied back to Phase 03 intent.

## Solution

Treat this as separate GSD work:

1. Compare the remaining hunks against the shipped Phase 03 acceptance criteria in `03-VALIDATION.md`.
2. Salvage only behavior that is still correct and still missing from main.
3. Reject comment-only churn and any coverage-reducing test edits.
4. If nothing essential remains, delete the worktree and its branch cleanly.

If salvaging, require focused verification for:

- `mix test test/kiln/agents/budget_guard_test.exs test/kiln/agents/telemetry_handler_test.exs`
- relevant audit tests around `Audit.append/1` and `Audit.replay/1`
