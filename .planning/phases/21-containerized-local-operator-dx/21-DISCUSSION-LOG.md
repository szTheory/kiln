# Phase 21: Containerized local operator DX - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `21-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 21-containerized-local-operator-dx
**Areas discussed:** Primary artifact & README tiers; Orchestrator ↔ Docker (DooD); Inner dev loop; CI strategy
**Mode:** User selected **all** areas + parallel **subagent research** synthesis (advisor-style depth without USER-PROFILE).

---

## 1. Primary artifact & canonical README story

| Option | Description | Selected |
|--------|-------------|----------|
| A — Host-primary README + optional task runner | Canonical path unchanged; `just`/`make` as sugar (**Phase 12**) | ✓ (baseline preserved) |
| B — Compose `app` as primary | One `docker compose up` for everything | |
| C — `.devcontainer/` as co-equal quick start | Two first-class clone stories | |
| D — B + C full container dev | Maximum maintenance / confusion | |

**User's choice:** **Tiered documentation** — canonical quick start remains **host Mix + Compose data plane**; Phase 21 ships **`.devcontainer/`** as the **primary optional** artifact for minimal host installs; **Compose `app`** deferred/secondary.
**Notes:** Subagent consensus: Phoenix OSS idioms favor **host `mix phx.server`**; Rails/Django/devcontainer ecosystems show **dual equal quick starts** create support load. Kiln-specific: **Compose `app`** pressures **DooD** docs and splits Phase 12 strategy—acceptable only as **labeled optional** profile, not README above-the-fold.

---

## 2. Orchestrator ↔ Docker (BEAM in container, sandboxes)

| Option | Description | Selected |
|--------|-------------|----------|
| Host Kiln + devcontainer shell only | Sandboxes unchanged | ✓ (recommended fastest loop) |
| DooD — socket / `DOCKER_HOST` in **orchestrator only** | Stage containers sibling on same daemon | ✓ (when BEAM in container) |
| DinD nested daemon | Isolated but splits networks | |
| Remote `DOCKER_HOST` only | Ops-heavy for solo Mac | |

**User's choice:** **DooD** for optional containerized Kiln; **reject DinD** as default; document **single-daemon** invariant for `kiln-sandbox` + DTU.
**Notes:** Aligns with GitLab docker executor / GHA job-container patterns; matches `docker_driver.ex` “one daemon” model.

---

## 3. Inner dev loop

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid A — Phoenix on host | Fastest Mac feedback | ✓ (recommended for heavy daily use) |
| Bind-mount dev in container | `MIX_ENV=dev`, anonymous `deps`/`_build` volumes | ✓ (inside devcontainer path) |
| Rebuild-per-change image | Prod-like | |
| Mutagen / heavy sync | Extra ops | |

**User's choice:** **Devcontainer:** bind mount + **`MIX_ENV=dev`** + anonymous volumes for **`deps`/`_build`** + **`0.0.0.0`** bind; document **VirtioFS** and watcher caveats; **host Phoenix** remains the **fastest** path for Game Boy dogfood iteration.

---

## 4. CI / proof

| Option | Description | Selected |
|--------|-------------|----------|
| Dialyzer in Docker every PR | High cost | |
| Path-filtered `compose config` + `build` | Low cost, catches drift | ✓ |
| Weekly heavy `up` + health | Off critical path | ✓ |
| Full compose up every PR | High confidence, slow | |

**User's choice:** **Path-filtered** Docker workflow + **weekly** heavier smoke; **`mix check`** remains sole full static-analysis oracle.

---

## Claude's Discretion

- Devcontainer implementation details (extensions, base image, exact lifecycle commands).
- Shared health assertion script extraction.

## Deferred Ideas

- Compose **`app`/`web`** service for non-editor users — only if demand appears; must use same DooD rules.

---

*Append after future discuss revisions if CONTEXT is updated.*
