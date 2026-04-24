# Phase 25: Local live readiness SSOT - Context

**Gathered:** 2026-04-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the first slice of **v0.5.0 local first success** by making Kiln's **live-readiness story operational, centralized, and honest**. The operator should be able to tell from one coherent setup surface whether the machine is ready for a real local run, what is missing, why it matters, and what to do next.

This phase is about **SSOT and guidance**, not the full first-live-run experience. It may refine existing readiness-aware copy, links, and shared rendering contracts across operator surfaces, but it must **not** claim that the recommended first live template path or end-to-end live launch flow is solved here. Those belong to **Phase 26** and **Phase 27**.

</domain>

<decisions>
## Implementation Decisions

### Readiness source of truth

- **D-2501:** `Kiln.OperatorSetup` is the **data SSOT** for operator-facing readiness in Phase 25. Existing LiveViews should read a shared readiness summary instead of each page inventing its own checklist logic.
- **D-2502:** The **operator-facing canonical setup surface** is `/settings`, not `/onboarding`, `/providers`, `/templates`, or `/`. Other surfaces may summarize readiness, but they should point back to `/settings` for remediation.
- **D-2503:** `/onboarding` remains a **demo-first orientation surface**. It may mention live readiness and route to `/settings`, but it is not the long-term home for the full checklist contract.

### Requirement interpretation

- **D-2504:** **SETUP-01** means the UI must show the local prerequisites that matter for a believable live run using **status, provider/config presence, and probe/remediation guidance**, without exposing secrets.
- **D-2505:** **SETUP-02** means every missing prerequisite should produce an explicit **recommended next action** and a stable navigation target. “Explore anyway” is acceptable only when paired with honest disconnected-state messaging.
- **D-2506:** **DOCS-09** means README and planning docs must describe **one canonical local trial path**: host Phoenix + Compose data plane remains primary; the devcontainer remains clearly secondary.

### Surface cohesion

- **D-2507:** Phase 25 should reduce drift across readiness-aware surfaces (`/settings`, `/onboarding`, `/providers`, `/templates`, `/`) by standardizing **what readiness state is called, when disconnected heroes appear, and which page is the recovery target**.
- **D-2508:** Use `/settings` as the consistent remediation destination from readiness-aware surfaces unless a more specific anchor materially improves recovery.
- **D-2509:** Existing disconnected-state UI in `OnboardingLive`, `ProviderHealthLive`, `TemplatesLive`, and `RunBoardLive` is a reusable pattern, but the copy and proof scope should be tightened so the surfaces read like one system instead of nearby variants.

### Guardrails and non-goals

- **D-2510:** Do **not** introduce “recommended first live template” selection, special live-template badging, or broader run-entry choreography in Phase 25. Those are **Phase 26** concerns.
- **D-2511:** Do **not** broaden this phase into E2E/browser-proof ownership. Focus on shared readiness contracts, operator-facing UX, and docs/tests that prove them.
- **D-2512:** Do **not** rely on the historical `OnboardingGate` redirect model. In the current codebase, `KilnWeb.Plugs.OnboardingGate` is a no-op; planning must treat old assumptions about route blocking as stale unless the code is explicitly changed again.

### Testing and verification

- **D-2513:** LiveView tests should remain the owning proof for these operator surfaces. Prefer targeted tests around stable ids and disconnected-state elements rather than brittle text-only assertions.
- **D-2514:** Test setup must respect the current harness behavior: `KilnWeb.ConnCase` marks readiness true by default unless a test opts out. Incomplete-readiness tests should use that contract intentionally rather than fighting hidden setup.
- **D-2515:** Verification should use **narrow commands that directly prove the Phase 25 surfaces** plus the repo-required final `bash script/precommit.sh` closeout gate.

### the agent's Discretion

- Whether Phase 25 introduces a small shared UI helper/component for readiness callouts or keeps the shared contract at the data/copy/test level.
- Whether `/settings` needs anchor-level links or a more prominent summary block to serve as the canonical remediation page.
- Exact plan count and decomposition, as long as Phase 25 stays inside readiness SSOT, remediation guidance, and canonical docs.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone truth

- `.planning/ROADMAP.md` — Phase 25 goal, requirements, and milestone boundary
- `.planning/REQUIREMENTS.md` — `SETUP-01`, `SETUP-02`, `DOCS-09`
- `.planning/PROJECT.md` — current milestone framing, local-first constraints, merge-authority/doc truth

### Recent phase context that constrains this work

- `.planning/phases/21-containerized-local-operator-dx/21-CONTEXT.md` — host Phoenix + Compose remains canonical; devcontainer remains optional/secondary
- `.planning/phases/24-template-run-uat-smoke/24-CONTEXT.md` — honesty around targeted proof and the existing template -> run path
- `.planning/phases/999.2-operator-demo-vs-live-mode-and-provider-readiness-ux/999.2-RESEARCH.md` — demo/live runtime mode and provider-readiness chrome

### Implementation anchors

- `lib/kiln/operator_setup.ex` — current readiness/checklist/provider summary SSOT candidate
- `lib/kiln/operator_readiness.ex` — persisted readiness flags and probes
- `lib/kiln_web/live/settings_live.ex` — strongest current candidate for canonical remediation surface
- `lib/kiln_web/live/onboarding_live.ex` — demo-first setup/orientation surface
- `lib/kiln_web/live/provider_health_live.ex` — provider/config presence and disconnected-live hero
- `lib/kiln_web/live/templates_live.ex` — readiness-aware template browsing and disconnected live state
- `lib/kiln_web/live/run_board_live.ex` — readiness-aware run-board balcony and disconnected live state
- `lib/kiln/runs/run_director.ex` — live-run start readiness guard
- `README.md` — canonical local trial path and devcontainer positioning

### Testing anchors

- `test/support/conn_case.ex` — default readiness setup behavior in LiveView tests
- `test/kiln_web/live/settings_live_test.exs`
- `test/kiln_web/live/onboarding_live_test.exs`
- `test/kiln_web/live/provider_health_live_test.exs`
- `test/kiln_web/live/templates_live_test.exs`
- `test/kiln_web/live/run_board_live_test.exs`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- `Kiln.OperatorSetup.summary/0` already aggregates checklist items, blockers, and provider/config presence without exposing secrets.
- `/settings` already renders the richest single-page readiness summary and checklist with stable DOM ids.
- `/onboarding`, `/providers`, `/templates`, and `/` already show live-mode disconnected heroes that point operators toward remediation.

### Important current realities

- `OnboardingGate` is intentionally pass-through now. Historical assumptions that unreadiness blocks routed pages are stale.
- `ConnCase` marks readiness true by default, so missing-readiness UI tests must deliberately opt out or override that setup.
- `RunDirector.start_run/1` still enforces readiness before a live run actually starts, so UI guidance must stay aligned with that backend truth.

### Likely integration points

- Shared readiness/callout rendering may belong in an operator-facing component or helper rather than repeated inline markup.
- README wording and planning artifacts should align around the same “host Phoenix + Compose primary, devcontainer secondary” path.
- Verification will likely center on focused LiveView test files plus targeted docs checks.

</code_context>

<specifics>
## Specific Ideas

- The repo already contains most of the raw pieces needed for Phase 25. The missing work is coherence: one canonical remediation page, one shared readiness vocabulary, and docs that describe the same local trial path the UI implies.
- A good Phase 25 outcome should make the operator experience feel like: “I know whether I am ready for a live run, I know exactly what is missing, and every page sends me back to the same place to fix it.”

</specifics>

<deferred>
## Deferred Ideas

- Picking and promoting the single recommended first live template — Phase 26
- Preflighted start-live-run routing and live-run launch UX — Phase 26
- End-to-end automated proof for the full local-first-run journey — Phase 27

</deferred>

---

*Phase: 25-local-live-readiness-ssot*
*Context gathered: 2026-04-23*
