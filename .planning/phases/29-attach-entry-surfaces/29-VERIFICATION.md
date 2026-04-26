---
phase: 29-attach-entry-surfaces
verified: 2026-04-24T09:41:34Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 29: Attach Entry Surfaces Verification Report

**Phase Goal:** Make attach-to-existing a first-class first-use path instead of an implied advanced workflow hidden behind greenfield-only onboarding.
**Verified:** 2026-04-24T09:41:34Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Operator can choose an attach-to-existing path from onboarding and template/start surfaces with clear framing. | ✓ VERIFIED | `/onboarding` exposes `#onboarding-attach-existing-repo` next to the existing template CTA and routes to `/attach` while keeping scenario state separate ([lib/kiln_web/live/onboarding_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:198)); `/templates` exposes `#templates-attach-module` and `#templates-attach-existing-repo` above the broader catalog ([lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:315)). |
| 2 | `/onboarding`, `/templates`, and `/attach` present one coherent attach-vs-template story. | ✓ VERIFIED | All three surfaces use the explicit `Attach existing repo` vs `Built-in templates` framing and repeat the supported-source + next-step honesty contract ([lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:25), [lib/kiln_web/live/onboarding_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/onboarding_live.ex:199), [lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:319)). |
| 3 | `hello-kiln` remains the single recommended first proof path. | ✓ VERIFIED | The `hello-kiln` hero remains the dominant first-run module and the attach card is a smaller peer module below it ([lib/kiln_web/live/templates_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/templates_live.ex:240), [test/kiln_web/live/templates_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/templates_live_test.exs:32)). |
| 4 | Attach remains route-backed and does not reuse scenario, template, or template-resume plumbing. | ✓ VERIFIED | Router adds a distinct `live "/attach", AttachEntryLive, :index` entry ([lib/kiln_web/router.ex](/Users/jon/projects/kiln/lib/kiln_web/router.ex:26)); `/attach` contains only orientation copy and back-links, and its focused test explicitly refutes `template_id`, `return_to`, template actions, and draft-PR language ([lib/kiln_web/live/attach_entry_live.ex](/Users/jon/projects/kiln/lib/kiln_web/live/attach_entry_live.ex:81), [test/kiln_web/live/attach_entry_live_test.exs](/Users/jon/projects/kiln/test/kiln_web/live/attach_entry_live_test.exs:16)). |
| 5 | Phase 29 proof is credible and scoped: focused LiveView coverage plus browser choreography prove the split without pulling Phase 30/31 mechanics forward. | ✓ VERIFIED | Focused LiveView suite passed (`21 tests, 0 failures`); Playwright passed for `tests/onboarding.spec.ts` and `tests/routes.spec.ts` with Phoenix held open in a persistent TTY session (`76 passed`), and the browser spec explicitly proves `/onboarding -> /attach` without leaking `scenario=` state ([test/e2e/tests/onboarding.spec.ts](/Users/jon/projects/kiln/test/e2e/tests/onboarding.spec.ts:48), [test/e2e/tests/routes.spec.ts](/Users/jon/projects/kiln/test/e2e/tests/routes.spec.ts:32)). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/kiln_web/router.ex` | `/attach` is registered in the default LiveView session | ✓ VERIFIED | `live "/attach", AttachEntryLive, :index` sits alongside `/onboarding`, `/`, and `/templates`. |
| `lib/kiln_web/live/attach_entry_live.ex` | Dedicated attach orientation surface | ✓ VERIFIED | Exists, substantive, shell-wrapped, and honest about supported sources plus Phase 30 boundary. |
| `lib/kiln_web/live/onboarding_live.ex` | Demo-first onboarding adds explicit secondary attach branch | ✓ VERIFIED | Existing template CTA remains primary; attach CTA is additive and routes directly to `/attach`. |
| `lib/kiln_web/live/templates_live.ex` | Start surface preserves `hello-kiln` while adding attach discovery | ✓ VERIFIED | `#templates-first-run-hero` remains primary and `#templates-start-choice` adds the attach module. |
| `test/kiln_web/live/attach_entry_live_test.exs` | Focused `/attach` proof | ✓ VERIFIED | Covers ids, source framing, and absence of template/git mutation plumbing. |
| `test/kiln_web/live/onboarding_live_test.exs` | Onboarding attach regression coverage | ✓ VERIFIED | Asserts attach CTA exists and does not turn into scenario state. |
| `test/kiln_web/live/templates_live_test.exs` | Templates attach regression coverage | ✓ VERIFIED | Asserts attach module exists while `hello-kiln` remains primary. |
| `test/kiln_web/live/route_smoke_test.exs` | Route matrix includes `/attach` | ✓ VERIFIED | `/attach` included in the index-route smoke list. |
| `test/e2e/tests/onboarding.spec.ts` | Browser proof for onboarding attach handoff | ✓ VERIFIED | Verifies direct `/attach` navigation and no `scenario=` leakage. |
| `test/e2e/tests/routes.spec.ts` | Browser route matrix includes `/attach` | ✓ VERIFIED | Includes `attach-entry` in the full LiveView route list. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/kiln_web/router.ex` | `lib/kiln_web/live/attach_entry_live.ex` | `live "/attach", AttachEntryLive, :index` | ✓ WIRED | Route exists in `live_session :default`. |
| `lib/kiln_web/live/onboarding_live.ex` | `/attach` | `#onboarding-attach-existing-repo` navigate link | ✓ WIRED | CTA links directly to `/attach`; no scenario param is appended. |
| `lib/kiln_web/live/templates_live.ex` | `/attach` | `#templates-attach-existing-repo` CTA | ✓ WIRED | Attach module hands off to the dedicated route. |
| `test/kiln_web/live/route_smoke_test.exs` | `lib/kiln_web/router.ex` | Route smoke list includes `/attach` | ✓ WIRED | Smoke coverage exercises the route with the operator shell. |
| `test/e2e/tests/onboarding.spec.ts` | `/attach` | Browser click + URL assertion | ✓ WIRED | Playwright proves the browser-level handoff and non-leakage of scenario query state. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/kiln_web/live/onboarding_live.ex` | `@operator_demo_scenario` | `resolve_scenario/2` from URL params or default demo scenario | Yes | ✓ FLOWING |
| `lib/kiln_web/live/templates_live.ex` | `@first_run_template`, `@templates` | `Templates.list/0` manifest entries and `first_run_template/1` selection | Yes | ✓ FLOWING |
| `lib/kiln_web/live/attach_entry_live.ex` | `@page_title` | Static mount assign | N/A | ✓ VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused LiveView regression suite | `mix test test/kiln_web/live/attach_entry_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/route_smoke_test.exs` | `21 tests, 0 failures` | ✓ PASS |
| Browser attach/onboarding proof | `npx playwright test tests/onboarding.spec.ts tests/routes.spec.ts` from `test/e2e` with `mix phx.server` held open in a TTY session | `76 passed` | ✓ PASS |
| Repo-wide phase-adjacent gate | `bash script/precommit.sh` | Current tree exited non-zero outside the Phase 29 surface; `ex_unit` reprint showed unrelated repo-wide failures while the Phase 29 targeted suites remained green. | ? NOT SCORED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `ATTACH-01` | `29-01-PLAN.md`, `29-02-PLAN.md` | Operator can choose attach from onboarding and template/start surfaces, with clear framing for when to use attach versus built-in templates. | ✓ SATISFIED | `/onboarding`, `/templates`, and `/attach` all implement the split; targeted LiveView + Playwright coverage passed. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| none | — | No placeholder copy, dead handlers, or attach-to-template plumbing reuse found in the Phase 29 implementation files. | ℹ️ | The shipped slice is additive rather than hollow. |

### Gaps Summary

No Phase 29 goal gaps found. `ATTACH-01` is satisfied, the attach-vs-template split is explicit on `/onboarding` and `/templates`, `hello-kiln` remains the recommended first proof path, `/attach` is a dedicated route-backed surface, and the code does not pull Phase 30/31 mechanics forward.

One verification caveat is worth preserving: the Playwright proof is reproducible, but only when Phoenix is kept alive in a persistent TTY session. That matches the phase summary's execution note. The repo-wide `precommit` gate is currently not reproducible as green in this tree, but the failure observed during verification did not come from the Phase 29 surface or its owning proof files.

---

_Verified: 2026-04-24T09:41:34Z_
_Verifier: Claude (gsd-verifier)_
