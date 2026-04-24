---
status: passed
phase: 25-local-live-readiness-ssot
verified: 2026-04-23
requirements:
  - SETUP-01
  - SETUP-02
  - DOCS-09
---

# Phase 25 verification — Local live readiness SSOT

## Automated

| Check | Result |
|-------|--------|
| Readiness backend + `/settings` contract tests | PASS |
| Cross-surface readiness LiveView tests | PASS |
| README / planning SSOT grep checks | PASS |
| `bash script/precommit.sh` | PASS |

Commands (repo root):

```bash
mix test test/kiln/operator_readiness_test.exs test/kiln/runs/run_director_readiness_test.exs test/kiln_web/live/settings_live_test.exs --max-failures 1
mix test test/kiln_web/live/operator_chrome_live_test.exs test/kiln_web/live/onboarding_live_test.exs test/kiln_web/live/provider_health_live_test.exs test/kiln_web/live/templates_live_test.exs test/kiln_web/live/run_board_live_test.exs --max-failures 1
rg -n "/settings|host Phoenix|Compose data plane|Optional: Dev Container" README.md
rg -n "host Phoenix|Compose data plane|/settings" .planning/ROADMAP.md .planning/REQUIREMENTS.md
bash script/precommit.sh
```

## Must-haves (from Phase 25 plans)

| ID | Result |
|----|--------|
| D-2501 / D-2507 — readiness stops defaulting to optimistic truth | VERIFIED |
| D-2502 / D-2508 — `/settings` is the canonical remediation destination | VERIFIED |
| D-2503 / D-2509 / D-2511 — readiness-aware surfaces stay explorable and route back to `/settings` | VERIFIED |
| D-2504 / D-2505 — readiness summary exposes names-only provider/config guidance and stable remediation metadata | VERIFIED |
| D-2506 / D-2515 — README and planning SSOT match shipped behavior and cite exact proof commands | VERIFIED |

## Human verification

None.

## Gaps

None. Phase 26 remains responsible for recommended first-template guidance, live-run preflight routing, and the first end-to-end live run proof.
