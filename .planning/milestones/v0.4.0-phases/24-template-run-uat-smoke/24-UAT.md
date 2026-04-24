---
status: complete
phase: 24-template-run-uat-smoke
source:
  - .planning/phases/24-template-run-uat-smoke/24-01-SUMMARY.md
started: 2026-04-23T19:26:14Z
updated: 2026-04-23T19:50:58Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 3
name: Starting a run navigates into the run detail shell
expected: |
  Submitting Start run from the success panel navigates to the run page and the destination renders the run detail shell.
result: passed

## Tests

### 1. Template detail actions are visible before promotion
expected: Opening a template detail page shows the operator journey in its initial state: the primary Use template action is visible, the secondary Edit in inbox first action is visible, and the start-run controls are not shown yet.
result: [passed]

### 2. Using a template reveals the inline success panel
expected: Submitting Use template keeps the operator on the same template detail page and shows the inline success state with the success panel and Start run control.
result: [passed]

### 3. Starting a run navigates into the run detail shell
expected: Submitting Start run from the success panel navigates to the run page and the destination renders the run detail shell.
result: [passed]

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

Focused proof re-run 2026-04-23: `mix test test/kiln_web/live/templates_live_test.exs` -> 4 tests, 0 failures.
