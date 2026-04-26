# Phase 21 — Pre-discuss brief (not CONTEXT)

**Purpose:** Persist intent and anchors on disk so **`/gsd-discuss-phase 21`** (even after **`/clear`**) loads the same scope. Do **not** treat this file as locked **CONTEXT** — discuss produces **`21-CONTEXT.md`**.

## One-line intent

Optional **Docker-first local operator DX**: one documented path to run Kiln with **minimal host installs** (primarily Docker / editor), dogfooding better cold-clone ergonomics than **host-only Phoenix** today.

## Prior shipped decisions (revisit only inside Phase 21 scope)

| Source | Decision |
|--------|----------|
| [`.planning/research/LOCAL-DX-AUDIT.md`](../../research/LOCAL-DX-AUDIT.md) | Compose = **data plane + DTU + optional OTel**; **no** Kiln `app` service; **no** `.devcontainer/` as v0.2 shipped strategy. |
| [Phase 12 `12-local-docker-dx`](../12-local-docker-dx/) / **LOCAL-DX-01** | **`justfile`** + **host `mix phx.server`**; single README quick start. |
| [`.planning/PROJECT.md`](../../PROJECT.md) **LOCAL-01** | `docker compose` runs Postgres + DTU + …; **Phoenix on host**; single-command “Kiln in Compose” **not** v0.1.0 scope (wording may be amended **by this phase’s deliverables**). |
| [`README.md`](../../../README.md) | Explains **why Compose does not start Kiln**. |
| [`CLAUDE.md`](../../../CLAUDE.md) / **PROJECT.md** | Sandboxes: **`System.cmd("docker", …)`**; **no** `/var/run/docker.sock` mount **into sandbox containers**; DTU on internal **`kiln-sandbox`**. |

## In-repo technical anchors (for discuss / research)

- [`compose.yaml`](../../../compose.yaml) — `db`, `dtu`, `otel-collector`, `jaeger`, `sandbox-net-anchor` profile.
- [`justfile`](../../../justfile) — `db-up`, `setup`, `smoke`, etc.
- [`test/integration/first_run.sh`](../../../test/integration/first_run.sh) — machine smoke (host `mix`).

## Gray areas to drive in discuss (seed list)

1. **Primary artifact:** Compose **`app` service`**, **`.devcontainer/`**, or **both**; which is “canonical” vs optional.
2. **Orchestrator ↔ Docker:** When BEAM runs **inside** a container, how does **`docker`** invoke stage containers with correct **network** / **DTU** reachability and **acceptable security** (no accidental broad socket exposure into **sandboxes**).
3. **Developer loop:** Hot reload vs rebuild; bind-mount source tree; `MIX_ENV=dev` vs dedicated `docker` profile.
4. **Documentation contract:** Still **one** primary README quick start, or clearly tiered “Host path” vs “Container path”.
5. **CI:** What minimal job proves the container path stays green.

## Explicit non-goals (unless discuss promotes them)

- Production Kubernetes / cloud deploy.
- Changing **sandbox safety model** (egress policy, internal DTU network) without explicit decision.

## Commands after `/clear`

1. **`/gsd-discuss-phase 21`** — produces **`21-CONTEXT.md`** in this directory.
2. **`/gsd-plan-phase 21`** — after CONTEXT exists.
3. Optional research flag per project gates: **`/gsd-research-phase 21`** if HIGH research is required.

## Deferred ideas (parking)

Capture in **CONTEXT** “Deferred ideas” if the user mentions scope outside Phase 21 during discuss.
