# Phase 21: Containerized local operator DX - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship an **optional**, **documented** path so a solo operator on **macOS** can reach the **LiveView UI in the browser** with **Docker as the main dependency** (Compose data plane + reproducible dev environment), **without** removing the existing **host Phoenix + `justfile` + Compose (`db`, `dtu`, optional OTel)** path. Phase 21 **may supersede Phase 12 wording** only where decisions below explicitly say so; otherwise **LOCAL-DX-01** / **D-1201** remain validated.

**North-star operator outcome:** Cold clone → documented steps → **`http://localhost:4000`** (or documented port) → onboarding/health OK → **sandbox stages still run** (DTU on **`kiln-sandbox`**, egress blocked per project constraints) so dogfood (e.g. **Game Boy emulator** vertical slice) is unblocked.

</domain>

<decisions>
## Implementation Decisions

### Documentation & canonical vs optional paths

- **D-2101 — README stays single “first success” anchor:** Keep **one** above-the-fold quick start aligned with **Phase 12 D-1202**: **Compose for `db` (+ optional `dtu`/OTel)** → **`KILN_DB_ROLE=kiln_owner mix setup`** → **`mix phx.server`**. Do **not** add a second “Quick start” column with equal weight.

- **D-2102 — Tiered “Docker-centric” path (Phase 21 deliverable):** Add a **clearly labeled second section** (e.g. **“Optional: Dev Container (minimal host installs)”**) *after* the canonical path. It must **repeat the same logical sequence** (data plane up → owner-role setup → Phoenix reachable → same `/health` / onboarding success criteria) so operators are not learning two different **topologies**—only **where BEAM runs** changes.

- **D-2103 — Primary optional artifact:** Ship **`.devcontainer/`** (Dev Containers spec) as the **main** optional artifact for “**Docker + editor,** little else on the host.” Treat **Compose `app` / `web` service** as **secondary / later**—only add if non–VS Code operators need a compose-only story; if added, it must follow the same **DooD** and **network** rules as below.

- **D-2104 — Phase 12 cohesion:** The **`justfile`** remains **thin sugar** over the same primitives (**D-1201**). Optional devcontainer **may** invoke `just` targets from lifecycle scripts **or** duplicate the minimal command list once—**never** fork divergent env contracts (`DATABASE_URL`, `KILN_DB_ROLE`, `.env`).

### Orchestrator ↔ Docker (sandboxes when BEAM is in a container)

- **D-2105 — Default pattern: Docker-outside-of-Docker (DooD):** When Kiln runs **inside** a container (devcontainer or future Compose `app`), use **one Docker daemon** (Docker Desktop / Colima VM) via **bind-mounted Unix socket** or consistent **`DOCKER_HOST`** for **both** `System.cmd("docker", …)` and the Docker API path in `docker_driver.ex`. **Never** mount the socket (or pass `DOCKER_HOST`) **into stage/sandbox** containers—**orchestrator only**; keep stage `ContainerSpec` / env free of `DOCKER_*` leakage.

- **D-2106 — Avoid DinD as default:** Do **not** use **Docker-in-Docker** as the default local DX: nested daemon implies **`kiln-sandbox` + DTU** must be recreated **inside** the inner daemon—easy to split-brain vs host Compose. DinD only if an explicit future decision isolates **full** stack replication (out of scope for initial Phase 21 ship unless replanned).

- **D-2107 — Prerequisite invariant:** Document that **`kiln-sandbox` and `dtu` must exist on the same daemon** Kiln targets. Symptom of violation: “network not found” or DTU unreachable from stage containers. Colima/Podman: call out **`DOCKER_HOST` / socket path** differences from Docker Desktop.

- **D-2108 — Preferred low-surprise combo for solo Mac:** **Hybrid:** Compose data plane on host daemon; **Phoenix on host** remains the **fastest inner loop** for heavy Kiln use. The **devcontainer** path is for **reproducible toolchain / onboarding** and “I accept container FS tradeoffs”—not a mandate to move daily dev off the host.

### Inner dev loop (Phoenix in optional container)

- **D-2109 — Devcontainer run mode:** Use **`MIX_ENV=dev`**, **`mix phx.server`** (not a release) inside the devcontainer; align with idiomatic Phoenix dev.

- **D-2110 — Bind mount + Linux artifacts:** Bind-mount the repo; use **anonymous volumes** for **`deps/` and `_build/`** inside the container so Linux BEAM artifacts are not dragged across macOS ↔ Linux incorrectly.

- **D-2111 — Networking:** Phoenix/Bandit must listen on **`0.0.0.0`** in the container dev path so port **4000** publishes correctly.

- **D-2112 — Mac DX honesty:** Document **Docker Desktop VirtioFS** (or current fastest file-sharing mode), **CPU/RAM** hints, and that **file watchers / code reload** may be flakier than host—pointer to **polling** or “run Phoenix on host” if reload fails—**principle of least surprise**.

- **D-2113 — Compose profiles (if Compose `app` is added later):** Gate optional **`web`/`app`** service behind a **profile** (e.g. `operator`) so `docker compose up -d db` default behavior is unchanged for existing operators.

### CI / verification

- **D-2114 — Keep `mix check` authoritative:** Full **`mix check`** stays on existing **Ubuntu + `erlef/setup-beam` + Postgres service** job—**no** full Dialyzer-in-Docker on every PR (**Phase 12 D-1204** preserved).

- **D-2115 — Path-filtered Docker job:** Add a **path-filtered** workflow (or guarded job) on changes to `compose.yaml`, `**/Dockerfile*`, `.devcontainer/**`, `priv/dtu/**`, and any future operator image context. Minimum steps: **`docker compose config --quiet`** → **`docker compose build`** (BuildKit + GHA cache). Extends with **`docker compose … up --wait` + `/health` JSON** once an optional **`app`/`web`** service exists—reuse or factor shared assertions with **`test/integration/first_run.sh`** where practical.

- **D-2116 — Scheduled heavier smoke:** Add **weekly `schedule` + `workflow_dispatch`** for a heavier variant (full profile `up`, optional devcontainer build) so end-to-end drift is caught **off** the critical PR path.

### Requirements / product doc follow-up (plan phase)

- **D-2117 — Traceability:** During implementation, **amend `PROJECT.md` LOCAL-01** (and **`REQUIREMENTS.md`** if a new LOCAL id is introduced) so validated wording matches the **tiered** truth—no duplicate “Active vs Validated” confusion (**LOCAL-DX-AUDIT** table spirit).

### Claude's Discretion

- Exact **devcontainer feature** set (extensions, post-create vs post-start), **image base** (`hexpm/elixir` vs custom Dockerfile), and **`just`** vs raw shell in lifecycle hooks.
- Whether **`script/assert_health_json.sh`** (or similar) is extracted for reuse between `first_run.sh` and Docker smoke.
- Wording and section titles in README for the optional tier (tone: calm, operator-first per brand contract).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase boundary & intent

- `.planning/ROADMAP.md` — Phase 21 row, success criteria (UI reachable, sandbox viability, CI smoke, host path preserved).
- `.planning/phases/21-containerized-local-operator-dx/21-BRIEF.md` — Pre-discuss intent, gray-area seeds, explicit non-goals.

### Prior locks (supersede only where this CONTEXT explicitly diverges)

- `.planning/phases/12-local-docker-dx/12-CONTEXT.md` — **D-1201–D-1205** (host Phoenix default, README canonical, CI philosophy).
- `.planning/research/LOCAL-DX-AUDIT.md` — Shipped LOCAL-01 truth; drift history.
- `.planning/PROJECT.md` — **LOCAL-01**, **LOCAL-DX-01**, sandbox constraints (**no socket into sandbox workloads**), solo-operator scope.

### Implementation anchors

- `compose.yaml` — `db`, `dtu`, `kiln-sandbox` (`internal: true`), OTel/Jaeger, profiles.
- `justfile` — `db-up`, `setup`, `smoke`, env contracts.
- `test/integration/first_run.sh` — Host-first machine smoke SSOT.
- `lib/kiln/sandboxes/docker_driver.ex` — `docker` CLI + API; `DOCKER_HOST` / socket coherence.

### Phoenix / ecosystem references (research-backed)

- Hexdocs: [Phoenix releases](https://hexdocs.pm/phoenix/releases.html) — releases vs `mix` dev (use **mix** for devcontainer inner loop).
- Docker for Mac / VirtioFS and large-file bind-mount caveats — document in README optional section as needed.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`test/integration/first_run.sh`** / **`mix integration.first_run`** — Success contract (compose `db`, setup, `/health` JSON); extend or share assertions for optional container smoke.
- **`compose.yaml`** — Additive services/profiles must preserve default **`db`-only** workflows.
- **`justfile`** — Delegate from devcontainer lifecycle to avoid duplicated orchestration logic.

### Established patterns

- **Host Phoenix + Compose data plane** — Canonical per Phase 10/12 and `LOCAL-DX-AUDIT.md`.
- **Sandbox driver** — Host daemon + **`kiln-sandbox`** network names on that daemon; **DooD** preserves this model when Kiln moves into a container.

### Integration points

- **README** — Single canonical quick start + one optional subsection (or short + link to `docs/…` if length exceeds Phase 12 **D-1202b** threshold).
- **`.github/workflows/`** — New path-filtered job; keep existing `mix check` + `first_run` ordering.

</code_context>

<specifics>
## Specific Ideas

- **Operator goal:** macOS + browser + end-to-end Kiln for **Game Boy emulator dogfood**—prioritize **reliability and documented recovery** over “pure Docker purity.”
- **Industry pattern to emulate:** CI/devcontainer **DooD** (job container + host daemon) vs **DinD** unless isolation is explicitly worth the cost.
- **Industry pattern to avoid:** Two equal “Quick start” stories without labeling **which is fastest on Mac** vs **which minimizes host installs**.

</specifics>

<deferred>
## Deferred Ideas

- **Compose-only `app` service** without devcontainer—revisit if users without VS Code/Cursor need parity.
- **Full Phoenix-in-Compose as default**—explicitly out of scope for README above-the-fold per **D-2101**.
- **Kubernetes / cloud deploy** — remains out of scope (`21-BRIEF.md`).

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned no matches for phase 21.

</deferred>

---

*Phase: 21-containerized-local-operator-dx*
*Context gathered: 2026-04-22*
