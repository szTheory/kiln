# Phase 12: Local Docker / dev environment DX - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship **one** optional developer-experience path so a solo operator can reduce footguns **without** replacing the canonical clone story: **Compose for Postgres / DTU / optional observability; Phoenix on the host** (`mix phx.server`). Phase 12 does **not** add a second “official” quick-start competing with README (Phase 10 **D-1001a**). It **does** add a **single** reproducible orchestration layer (task runner + documented targets) plus README + `LOCAL-DX-AUDIT.md` alignment.

**Depends on:** Phase 10 complete (`LOCAL-DX-AUDIT.md`, README operator path).

**Out of scope:** Production cloud deploy; replacing host-based dev as the default; devcontainer or Compose-hosted Phoenix **as the Phase 12 shipped strategy** (see decisions — deferred unless explicitly reopened with a host-Docker story).

</domain>

<decisions>
## Implementation Decisions

### Primary strategy (LOCAL-DX-01)

- **D-1201 — Optional DX = task runner + host Phoenix:** Ship a **thin orchestration layer** — **`justfile` preferred**; **`Makefile` acceptable** if the maintainer prefers ubiquitous `make`. Targets wrap existing primitives: `docker compose up` for `db` (and optional `dtu`, OTel/Jaeger), **`KILN_DB_ROLE=kiln_owner`** for migrations/setup, host **`mix phx.server`**, optional alignment with **`bash test/integration/first_run.sh`** / **`mix integration.first_run`**. This is the **one** strategy for Phase 12 (not parallel “official” ways).

- **D-1201a — Explicit non-choices for v0.2:** Do **not** ship **Phoenix inside Compose** (`app` service) as the Phase 12 deliverable — bind-mount / watcher fragility, dual-role DB confusion, and **host `docker` CLI** usage for sandboxes create unnecessary risk and documentation split-brain. Do **not** ship **`.devcontainer/`** in Phase 12 unless a follow-up phase explicitly designs **policy-compliant host Docker access** from the dev shell and accepts editor + macOS maintenance cost.

### Documentation & information scent

- **D-1202 — README remains canonical:** Keep the **default** operator checklist and quick start **unchanged and above the fold**. Add **one** subordinate section (e.g. **“Optional: one-command local orchestration”**) after the primary path: audience, **3–6 commands** or **`just <target>`** names, **same success criteria** as the default path (reach **`/onboarding`**, same machine-smoke contract where applicable).

- **D-1202a — LOCAL-DX-AUDIT.md:** Add/update a **Runbook pointer** only — “optional orchestration: see README § …”. **No** duplicate command blocks in the audit; use the findings table / drift notes when behavior changes.

- **D-1202b — Long optional prose:** If the optional section would exceed ~15 lines, split depth to **a single** `docs/local-optional-dx.md` (or similar) with README retaining the short framing + link. Default is **README-only** subsection.

### Ship depth

- **D-1203 — Minimum shipped artifact:** **Checked-in `justfile` (or `Makefile`)** plus README + audit pointer — sufficient for falsifiable “clean machine follows documented optional path.” **Docs-only** optional path is **not** sufficient for Phase 12 unless explicitly re-scoped (high drift risk).

### CI

- **D-1204 — Canonical gate unchanged:** **`mix check`** stays on **GitHub Actions** host runners (**Ubuntu + pinned `erlef/setup-beam`** + Postgres + existing caches). Do **not** duplicate full **`mix check`** (especially Dialyzer) inside a dev image on every PR.

- **D-1204a — Future image smoke (conditional):** If a **dev `Dockerfile`** or **`.devcontainer`** is introduced in a **later** change, add a **path-filtered** workflow job: **`docker build`** and optionally **`mix compile`** (or `mix deps.get && mix compile`) **in-container** — not a second full `mix check`. Optional **scheduled** full in-image check only if drift is observed.

### Verification

- **D-1205 — Cold path parity:** Phase 12 UAT: a **second machine or clean clone** can follow **either** the default README path **or** the optional **`just` / `make`** path and reach **`/onboarding`** with **no undocumented steps**. Record outcome in **`12-01-SUMMARY.md`** (or plan SUMMARY) when executed.

### Claude's Discretion

- Exact **`just`** target names and ordering (e.g. whether `dev` includes `dtu` by default vs separate `dev-with-dtu`).
- Whether to add a **one-line `mix`** alias mirroring the most common `just` target (must remain a **delegate**, per Phase 10 **D-1005b** spirit — no duplicated orchestration logic in Elixir).
- **`just` vs `make`** if the implementer prefers **`make`** for zero extra install; document the chosen tool in README once.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase boundary & roadmap

- `.planning/ROADMAP.md` — Phase 12 goal, **LOCAL-DX-01**, execution order vs Phases 10–13.
- `.planning/research/LOCAL-DX-AUDIT.md` — Shipped LOCAL-01 truth; Phase 12 pointer; Runbook alignment with README.

### Prior locks (host-first, docs)

- `.planning/phases/10-local-operator-readiness/10-CONTEXT.md` — **D-1001a–D-1006** (README canonical cold path; audit = rationale; `first_run.sh` scope; integration smoke SSOT).
- `.planning/PROJECT.md` — **Validated** LOCAL-01 / **Active** LOCAL-DX-01; constraints (sandbox, Docker, solo operator).

### Artifacts Phase 12 will likely touch

- `README.md` — Optional subsection; primary checklist unchanged.
- `compose.yaml` — Reference only unless Compose profiles change (not required by D-1201).
- `test/integration/first_run.sh` — Machine smoke SSOT; task runner may wrap, not fork logic.

### Research / follow-up (not implementation contracts)

- `https://github.com/gsd-build/gsd-2` — See `<deferred>`; possible future GSD tooling integration, out of scope for Phase 12.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable assets

- **`test/integration/first_run.sh`** — Port guard, `.env` bootstrap, `docker compose up -d db`, `KILN_DB_ROLE=kiln_owner mix setup`, `mix phx.server` + `/health` JSON; optional **`mix integration.first_run`** delegate.
- **`compose.yaml`** — `db`, `dtu`, `otel-collector`, `jaeger`, `kiln-sandbox` (`internal: true`); no `app` service today.

### Established patterns

- **Host Phoenix + Compose data plane** — Canonical per Phase 10 and `LOCAL-DX-AUDIT.md`.
- **Two DB roles** — `kiln_owner` for DDL/migrations/setup; `kiln_app` at runtime; any new orchestration must preserve explicit owner-role steps.

### Integration points

- README **Operator checklist** and **Human-required vs automated** tables — optional section must not fork a competing “first read” story.
- **GitHub Actions** — `.github/workflows/ci.yml` (pinned BEAM, Postgres service, caches) remains the PR oracle.

</code_context>

<specifics>
## Specific Ideas

- Prefer **`just`** for readable recipes and arguments; fall back to **`make`** if the project standardizes on zero extra tooling.
- Optional **`just dev`** (or equivalent) should be discoverable from README in **one** sentence after the primary checklist.

</specifics>

<deferred>
## Deferred Ideas

### Containerized dev (revisit only with explicit design)

- **`.devcontainer/`** — Useful for Cursor/no-local-asdf workflows; blocked for Phase 12 as **shipped** strategy until **host Docker** usage for sandboxes is reconciled with project security rules and documented without `docker.sock` footguns.
- **Compose `app` service** (Phoenix in container) — Revisit only if product goals change; high maintenance vs host-first for this codebase.

### GSD tooling research

- **gsd-2** (`https://github.com/gsd-build/gsd-2`) — Possible future **integration or piggy-back** for GSD-style planning/workflow tooling alongside this repo’s `.planning/` workflow. **Not in scope** for Phase 12 or current execution; treat as **research / follow-up** (e.g. backlog note or Phase 13+ discussion). No implementation or dependency work now.

### Reviewed Todos (not folded)

- None — `todo.match-phase` returned no matches for phase 12.

</deferred>

---

*Phase: 12-local-docker-dx*
*Context gathered: 2026-04-21*
