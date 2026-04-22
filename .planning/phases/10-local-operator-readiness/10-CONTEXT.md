# Phase 10: Local operator readiness - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the **clone → Postgres → migrate → host app → `/onboarding` → run board** path impossible to misunderstand: **README** + **`test/integration/first_run.sh`** stay in lockstep, **when to start DTU** is explicit, a scannable **operator checklist** lives in the repo root, **optional OTLP/Jaeger** stays documented without becoming a default CI gate, and **LOCAL-DX-AUDIT** remains rationale + edge cases—not a second quick-start. Aligns with Phase 9 **D-930–D-934** (layered proof: machine script, LiveView tests, honest human steps).

**Out of scope:** Phase **11** (external dogfood), Phase **12** (containerized / single-command app DX), full **DOCS-02** long-form operator guide (deferred to Phase **13** or later).

</domain>

<decisions>
## Implementation Decisions

### Doc placement & information scent (D-1001 — G1)

- **D-1001a — Canonical cold path = README:** The **operator checklist** is a dedicated **README** section (scannable bullets). **LOCAL-DX-AUDIT** gains a short **Runbook** note: canonical commands live in README; the audit file is architecture rationale + drift history + edge cases.
- **D-1001b — Starlight = optional depth:** Do not duplicate long quick-start prose under `site/` for Phase 10. README may link to published docs (e.g. onboarding deep-dive) **one-way** (README → site), not the reverse as the primary clone path.

### Machine vs human proof (D-1002 — G2)

- **D-1002a — `first_run.sh` scope:** Keep **infra + migrate + boot + `/health` JSON** only. **Do not** curl `/onboarding` or assert wizard HTML in the shell script (fragile, conflates layers).
- **D-1002b — Onboarding authority:** **Phoenix.LiveViewTest** (and existing onboarding tests) remain the **authoritative** proof of wizard behavior and typed blockers per **D-930 / D-934**.
- **D-1002c — Human dry-run:** Phase 10 UAT “onboarding loads / completes or blocks” = **documented browser steps** in README + manual verification note in plan **SUMMARY** when the plan completes—not a new automated gate. Optional **friction log** from a cold environment belongs in SUMMARY or STATE pointer, not CI.

### Optional observability (D-1003 — G3)

- **D-1003a — Jaeger UAT = doc + manual once:** The README **Traces** block is the contract. Phase 10 verifies an operator can follow it and see a trace in Jaeger for a trivial action; record outcome in **10-01-SUMMARY** (checklist). **Do not** add Jaeger/OTel to default **`mix check`** for this phase.
- **D-1003b — OTLP in app:** Preserve **D-911**: app reads **`OTEL_EXPORTER_OTLP_ENDPOINT`** only; Compose pins collector/Jaeger images (**no hard-coded Jaeger** in application code).

### DTU discoverability (D-1004 — G4)

- **D-1004a — Subsection after quick start:** Add **“Digital Twin / sandbox mocks (DTU)”** to README: before **sandbox stages**, run `docker compose up -d dtu`, wait for healthy, one line on **`kiln-sandbox`** internal network (`internal: true` in `compose.yaml`). Quick start stays **db-first** for “UI fast” path.

### Integration command SSOT (D-1005 — G5)

- **D-1005a — Named command:** **`bash test/integration/first_run.sh`** is the **single** integration smoke for DB + migrate + boot + health (already linked from README).
- **D-1005b — Mix alias (optional):** If an alias is added (e.g. `mix integration.first_run`), it must be a **one-line delegate** to the shell script—**no** duplicated Docker/migrate orchestration in Elixir.

### DOCS-02 (D-1006 — G6)

- **D-1006 — Defer long-form operator guide:** **DOCS-02** (extended onboarding / collapsible edge cases) is **not** Phase 10 scope. Target **Phase 13** (requirements/docs hygiene) or explicit backlog. Phase 10 may add at most **one “see also”** link toward Starlight without implementing the full DOCS-02 IA.

### Claude's Discretion

- Exact checklist bullet wording and ordering in README.
- Whether to add a thin `mix integration.first_run` alias (only if operators ask for Mix-discoverability).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase boundary & audit

- `.planning/ROADMAP.md` — Phase 10 goal, requirements **LOCAL-01**, **LOCAL-03**, **BLOCK-04** (operator path).
- `.planning/research/LOCAL-DX-AUDIT.md` — Shipped LOCAL-01 truth; Runbook pointer to README; Phase 12 pointer for containerized DX.

### Prior locks (layered proof, onboarding)

- `.planning/phases/09-dogfood-release-v0-1-0/09-CONTEXT.md` — **D-930–D-934** (README structure, `first_run.sh` parity, automation limits, screenshots policy).
- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-CONTEXT.md` — **D-806–D-812** (`/onboarding`, probes, BootChecks split).

### Artifacts to edit in Phase 10

- `README.md` — Quick start, operator checklist, DTU subsection, traces, human vs automated table.
- `compose.yaml` — Service names (`db`, `dtu`, `otel-collector`, `jaeger`, `network-anchor` profile).
- `test/integration/first_run.sh` — Machine contract; header comments stay aligned with README.
- `config/runtime.exs` — `KILN_DB_ROLE`, env var contract (reference only unless drift found).

### Published docs (optional depth)

- `site/src/content/docs/` — Starlight operator docs; README links here for depth, not vice versa as primary path.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`test/integration/first_run.sh`** — Port 5432 conflict guard, `.env` bootstrap, `docker compose up -d db`, `KILN_DB_ROLE=kiln_owner mix setup`, background `mix phx.server`, **`/health` JSON** assertions.
- **`Kiln.BootChecks`** / **`KILN_SKIP_BOOTCHECKS`** — Documented in README; Phase 10 verifies narrative matches boot order.
- **`KilnWeb.OnboardingLive`** — Wizard behavior proven in tests; not asserted by `first_run.sh`.

### Established patterns

- **Host Phoenix + Compose data plane** — Per LOCAL-DX-AUDIT; README already states it explicitly.
- **Two DB roles** — `kiln_owner` for DDL/migrations, `kiln_app` at runtime; README + `first_run.sh` already use `KILN_DB_ROLE=kiln_owner` for setup.

### Integration points

- README **Documentation** section already references GitHub Pages URL pattern; checklist should not fork a second URL scheme.

</code_context>

<specifics>
## Specific Ideas

- **Jaeger “trivial action”** for manual UAT: e.g. load `/health` or `/onboarding` in browser after OTLP env set—planner picks one path and documents it in SUMMARY once verified.

</specifics>

<deferred>
## Deferred Ideas

- **DOCS-02** full long-form operator guide — Phase **13** or backlog, not Phase 10.
- **Playwright / headless onboarding** — Only if LiveView tests prove insufficient (Phase 9 explicitly avoided heavy browser automation by default).

</deferred>

---

*Phase: 10-local-operator-readiness*
*Context gathered: 2026-04-21*
