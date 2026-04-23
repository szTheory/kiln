# Local development and Docker DX audit

**Date:** 2026-04-22  
**Scope:** Align `PROJECT.md` LOCAL-01 wording, `README.md`, and `compose.yaml` with how Kiln actually runs in v0.1.0.

## Findings

| Artifact | Claim | Reality |
|----------|--------|---------|
| `compose.yaml` | Services: `db`, `dtu`, `otel-collector`, `jaeger`, optional profile `network-anchor` | No Phoenix/Kiln app service. |
| `README.md` | Quick start: `docker compose up -d db`, then `mix phx.server` on host | Accurate for default loop. |
| `PROJECT.md` Active (stale) | LOCAL-01: "`docker-compose up` spins up Kiln + Postgres + sandbox runtime" | **Inaccurate:** Kiln is not started by Compose; sandbox stages use host `docker` CLI + compose-defined networks/images. |

## Doc-only vs product gaps

- **Doc-only:** Stale `PROJECT.md` **Active** checklist duplicated **Validated** and implied unshipped work. **Mitigation:** Move shipped items to **Validated**; keep **Active** for v0.2 only.
- **Product gap (optional v0.2):** Operators without a scripted habit still repeat the same **Compose + `mix`** steps by hand. **Mitigation (shipped Phase 12):** optional **`justfile`** at repo root — see **[README — Optional: Just recipes](../../README.md#optional-just-recipes-local-orchestration)** for named targets (`just db-up`, `just setup`, `just smoke`, …). **No** Compose-hosted Phoenix and **no** `.devcontainer/` as the v0.2.0 strategy; Phoenix remains on the host.

## Decision (v0.1.0)

- **Shipped truth:** LOCAL-01 = Compose for **data plane + DTU + optional observability**; **Kiln = host process**.  
- **v0.2:** Evaluate one DX strategy in **Phase 12**; do not block dogfood on full containerized app.

## Runbook (operator)

**Canonical quick path:** follow **[`README.md`](../../README.md)** end-to-end — quick start, **Operator checklist**, **Digital Twin (DTU)** subsection, and **Human-required vs automated**. That file is what a fresh `git clone` should use first. Machine smoke is **`bash test/integration/first_run.sh`** or the one-line delegate **`mix integration.first_run`** (same script; see README **Integration smoke**).

**This audit file** is for **rationale**, **drift history** (findings table), and **edge cases** (e.g. why there is no `app` service). **Optional orchestration** is documented only in **README** (pointer: [Optional: Just recipes](../../README.md#optional-just-recipes-local-orchestration)); the **`justfile`** wraps **`compose.yaml`**, **`KILN_DB_ROLE=kiln_owner mix setup`**, and **`test/integration/first_run.sh`** — not a second command matrix here. Do not fork a competing quick-start; patch README + compose when reality changes, then summarize the “why” here if needed.

**Phase 21 (optional Dev Container):** operators who want a **reproducible Linux toolchain** with **Docker + editor** can use the checked-in [`.devcontainer/`](../../.devcontainer/) plus README [Optional: Dev Container](../../README.md#optional-dev-container-minimal-host-installs) — same **Compose data plane** and **DooD** constraints as host Phoenix; no duplicate command matrix in this audit (rationale-first SSOT per **D-2117**).

## References

- [`compose.yaml`](../../compose.yaml)  
- [`README.md`](../../README.md)  
- [`.planning/ROADMAP.md`](../ROADMAP.md) **Phase 12**
