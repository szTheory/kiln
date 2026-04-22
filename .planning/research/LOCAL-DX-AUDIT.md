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
- **Product gap (optional v0.2):** No single command starts **DB + app** for operators without a local Elixir install. **Mitigation:** **Phase 12** — choose devcontainer vs `compose` `app` service vs `make`/`just` wrapper after Phase 10 runbook.

## Decision (v0.1.0)

- **Shipped truth:** LOCAL-01 = Compose for **data plane + DTU + optional observability**; **Kiln = host process**.  
- **v0.2:** Evaluate one DX strategy in **Phase 12**; do not block dogfood on full containerized app.

## Runbook (operator)

**Canonical quick path:** follow **[`README.md`](../../README.md)** end-to-end — quick start, **Operator checklist**, **Digital Twin (DTU)** subsection, and **Human-required vs automated**. That file is what a fresh `git clone` should use first. Machine smoke is **`bash test/integration/first_run.sh`** or the one-line delegate **`mix integration.first_run`** (same script; see README **Integration smoke**).

**This audit file** is for **rationale**, **drift history** (findings table), and **edge cases** (e.g. why there is no `app` service, Phase 12 pointer). Do not fork a second competing quick-start here; patch README + compose when reality changes, then summarize the “why” here if needed.

## References

- [`compose.yaml`](../../compose.yaml)  
- [`README.md`](../../README.md)  
- [`.planning/ROADMAP.md`](../ROADMAP.md) **Phase 12**
