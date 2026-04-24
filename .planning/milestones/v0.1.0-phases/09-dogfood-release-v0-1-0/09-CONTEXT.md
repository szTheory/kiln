# Phase 9: Dogfood & Release (v0.1.0) - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship **GIT-04**, **OBS-02**, and **LOCAL-03** in concert with a real **Kiln builds Kiln** run: after the operator’s initial spec (per ROADMAP SC1, **authored in the Kiln UI**), the factory loop runs without further human steps through **PR merge** and **green CI**; **OpenTelemetry** proves a single coherent **trace tree** across HTTP/LiveView, **Oban**, **Ecto**, **LLM**, and **Docker** boundaries; **README + integration proof** leaves no tribal knowledge for a cold clone; **`v0.1.0`** is tagged with **CHANGELOG** and **LICENSE** resolved.

Out of scope: new product capabilities (e.g. marketing site / Phase 999.1), merge queue unless proven necessary by churn, full metrics SDK while upstream remains experimental, heavy Playwright unless LiveView tests prove insufficient.

</domain>

<decisions>
## Implementation Decisions

### Dogfood run contract (D-901..D-905)

- **D-901 — UI-authored acceptance, repo-backed reproducibility:** Milestone **acceptance** follows ROADMAP SC1: the operator **writes the small real spec in the Kiln UI** and starts the run (the only intentional human step). **Engineering reproducibility** requires a **checked-in canonical spec artifact** under `dogfood/` (exact filename TBD in plan) whose bytes are the **golden template** (“Load dogfood template” or equivalent) so CI, reviewers, and diffs see the same intent as the default dogfood story—**no drift** between “what we demo” and “what’s in git.”
- **D-902 — Merge path = native GitHub auto-merge:** Enable **auto-merge** on the dogfood PR once opened; merge when **required status checks** pass. **Do not** rely on a personal PAT; use a **GitHub App** (preferred) or **fine-grained token** scoped to this repo with **least privilege** (`contents`, `pull_requests`; avoid `workflows: write` unless unavoidable). **No merge queue** in v0.1.0 unless parallel dogfood or `main` churn causes repeated “green PR → red on main”—add later, not speculatively.
- **D-903 — Branch + idempotency:** Branches `kiln/dogfood/<spec_short_hash>-<short_id>` (or equivalent fixed prefix). PR **labels** carry a stable idempotency key (e.g. `kiln-dogfood:spec/<hash>`). **Reuse** an open PR for the same key (push commits) instead of opening duplicates. Pair with **`external_operations`** + **Oban insert-time unique** for every mutating Git/GitHub side-effect (project invariants).
- **D-904 — Safety rails:** **No force-push** automation. **Path allowlist** for dogfood PRs (e.g. exclude `.github/workflows/` unless the spec explicitly targets them). If **`main` already contains the expected outcome**, complete **green with explicit `noop: already_shipped`** (telemetry + audit)—do not open noise PRs.
- **D-905 — Scope of “small real spec”:** Prefer **low-contention** changes (isolated module + tests + small doc touch) so merge conflicts rarely block the loop; spec text must cap touched paths and assert **`mix check`** (or agreed subset) as the bar.

### OpenTelemetry (D-910..D-915)

- **D-910 — Trace-first, metrics later:** Ship **traces + logs correlation** for Phase 9. **Defer OpenTelemetry metrics** to a later milestone until stable non-experimental metric readers are validated against Kiln’s needs (STACK research caveat).
- **D-911 — Local topology:** Default dev/proof stack: app exports **OTLP** to an **OpenTelemetry Collector** service in `docker compose`, which forwards to **Jaeger** for UI. **Same OTLP env contract** may point at **Honeycomb** (or another OTLP vendor) for occasional “off-laptop” proof—**app never hard-codes Jaeger** vs vendor.
- **D-912 — Instrumentation baseline:** Enable Hex stack aligned with Phoenix 1.8 + Bandit: **`opentelemetry_bandit`** + **`opentelemetry_phoenix`** (`adapter: :bandit`), **`opentelemetry_ecto`** (repo telemetry), **`opentelemetry_oban`** with **`OpentelemetryOban.insert/1`** (or current API) on enqueue so **`perform`** shares **trace_id** with producer; attach **`opentelemetry_process_propagator`** where Task/Oban/Ecto boundaries drop context.
- **D-913 — Kiln semantic spans (manual, low-cardinality):** Wrap **`kiln.run.stage`**, **`kiln.agent.call`**, **`kiln.docker.op`**, **`kiln.llm.request`** with `OpenTelemetry.Tracer.with_span` (names stable; variable data in **bounded** attributes). **Never** attach raw prompts, API keys, or secrets to spans or baggage.
- **D-914 — Sampling:** **Dev:** always-on or near-100% for debugging span shape. **Prod:** **parent-based** coherent sampling; ensure async jobs **inherit** parent context so traces do not fragment.
- **D-915 — Oban span relationships:** Prefer **parent/child** continuity for “one run = one tree” semantics; use **links** only where a child relationship would lie about causality—validate visually in Jaeger before locking patterns in code.

### Release mechanics (D-920..D-924)

- **D-920 — CHANGELOG:** Add **`CHANGELOG.md`** following **[Keep a Changelog](https://keepachangelog.com/)** with sections `Added` / `Changed` / `Fixed` / `Security` as needed. Under **`[0.1.0]`**, include a **REQ-ID checklist** (or table) mapping **GIT-04, OBS-02, LOCAL-03** and cross-reference “all v1 requirements shipped + validated” per ROADMAP SC5—**narrative for humans, REQ-IDs for audit**.
- **D-921 — GitHub Release:** Create a **GitHub Release** on tag **`v0.1.0`** whose **body is copied or sliced from** the `CHANGELOG` section for that version—**no mandatory release assets** for the app (optional SBOM/image digest later). Treat the Release as a **view**, not a second log.
- **D-922 — LICENSE:** Replace README “TBD” with a concrete **`LICENSE`** file. Default choice: **Apache-2.0** (patent grant + industry familiarity). **Avoid AGPL** unless copyleft-on-network is an explicit product decision. If Apache `NOTICE` obligations appear from dependencies, maintain **`NOTICE`** per license terms.
- **D-923 — Tag ↔ version CI gate:** Extend **`.github/workflows/ci.yml`** with `on.push.tags` matching `v*`. On tag builds, **fail** if `git describe` / tag (strip leading `v`) does not equal **`Mix.Project.config()[:version]`** in `mix.exs` (already `0.1.0`—keep in lockstep going forward).
- **D-924 — Tagging order:** **Merge dogfood + docs to `main` →** final **`CHANGELOG` / LICENSE / README** edits on `main` → **annotated tag `v0.1.0` on that commit** → push tag → publish GitHub Release.

### README, validation, and DX (D-930..D-934)

- **D-930 — Layered proof (no false confidence):** (1) **`mix check`** + existing CI = code + boot invariants. (2) **`test/integration/first_run.sh`** = machine contract for **Postgres + migrate + boot + `/health` JSON** (extend only with **machine-verifiable** steps). (3) **`Phoenix.LiveViewTest`** (and existing onboarding tests) = **authoritative** onboarding wizard behavior—**not** curl-only. (4) **Manual cold clone** on a **second machine or disposable VM** once per milestone: **README only** through onboarding + first run; capture a short **friction log**—this is the honest bar for ROADMAP SC4 / LOCAL-03.
- **D-931 — README structure:** **Prerequisites** once; **happy path** numbered blocks: env → `docker compose up -d db` → **`KILN_DB_ROLE=kiln_owner mix setup`** (single place for migrate/setup) → `mix phx.server`. **“Open first”** list starts with **`/onboarding`**, then `/`, `/ops/*` as today—aligns with Phase 8 gate (no surprise redirects). Single short **`KILN_DB_ROLE`** explanation + pointer to `config/runtime.exs`.
- **D-932 — Script/README parity:** `first_run.sh` header must state whether it **assumes** Elixir installed (per `.tool-versions`) or invokes **`asdf install`**—README and script must **match** so “README only” operators are not misled.
- **D-933 — Screenshots:** Default **no screenshots** in README (avoid rot). If ROADMAP’s “screenshots from dogfood run” is satisfied, prefer **one bounded image** stored under `docs/` or `.planning/` **referenced at a tag**, or **asciinema** for CLI—planner picks least maintenance.
- **D-934 — Automation limits (honesty):** **Do not** claim full onboarding in **`first_run.sh`** without real credentials; CI may use **test doubles** for keys where appropriate. Document clearly what is **human** (API keys, `gh auth login`) vs **automated**.

### Claude's Discretion

- Exact `dogfood/` filenames and template UX copy.
- Collector processor knobs (batch sizes) within OTLP defaults.
- Whether first GitHub Release uses `gh release create` vs UI (either satisfies D-921).
- REQ-ID table formatting in CHANGELOG (table vs bullets).

### Folded Todos

- None (`todo.match-phase` returned zero).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 9 roadmap & requirements

- `.planning/ROADMAP.md` — Phase 9 goal, success criteria 1–5, phase artifacts (`ci.yml`, OTel wiring, README, CHANGELOG, tag).
- `.planning/REQUIREMENTS.md` — **GIT-04**, **OBS-02**, **LOCAL-03** (note: LOCAL-03 wording may reference earlier phase—**Phase 9 SC4 is the authoritative fresh-clone + onboarding bar**).
- `.planning/PROJECT.md` — Core value, out-of-scope (no human approval gates, solo operator).

### Prior locks (do not contradict)

- `.planning/phases/08-operator-ux-intake-ops-unblock-onboarding/08-CONTEXT.md` — Onboarding route, typed unblock, factory chrome, `/ops` boundary.
- `.planning/phases/07-core-run-ui-liveview/07-CONTEXT.md` — Domain vs `/ops`, streams-first.
- `.planning/phases/01-foundation-durability-floor/01-CONTEXT.md` — Audit immutability, `external_operations`, logging metadata (D-46).

### Repo & CI

- `.github/workflows/ci.yml` — Current `mix check`, Dialyzer cache, boot checks step; extend per **D-923**.
- `mix.exs` — Version SSOT for tags (**D-923–D-924**).
- `README.md` — First-run narrative to align with **D-931–D-932**.
- `test/integration/first_run.sh` — Integration contract; extend per **D-930, D-932**.

### External (OpenTelemetry)

- `https://opentelemetry.io/docs/languages/erlang/getting-started/` — Erlang/Elixir OTel setup, experimental metrics split.
- `https://hex.pm/packages/opentelemetry_phoenix` — Phoenix instrumentation.
- `https://hex.pm/packages/opentelemetry_bandit` — Bandit HTTP spans.
- `https://hex.pm/packages/opentelemetry_oban` — Oban propagation helpers.
- `https://opentelemetry.io/docs/concepts/signals/baggage/` — Baggage vs attributes (do not put secrets in baggage).

### Changelog convention

- `https://keepachangelog.com/` — Format reference for **D-920**.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **CI:** `.github/workflows/ci.yml` already runs pinned Elixir/OTP, caches `deps`/`_build` and `priv/plts`, `mix compile --warnings-as-errors`, `mix check`, then `KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks` — extend for tag equality and optional integration job.
- **Integration:** `test/integration/first_run.sh` encodes health JSON contract + port conflict handling — evolve in lockstep with README per **D-932**.
- **Deps:** `mix.exs` already lists `opentelemetry`, `opentelemetry_api`, `opentelemetry_exporter` — **library wiring under `lib/` is Phase 9 work** (subagents found no `opentelemetry_*` usage in `lib/` yet).

### Established Patterns

- **Idempotency:** Oban unique **insert-time** + `external_operations` two-phase pattern is non-negotiable for dogfood Git/GitHub automation (**D-903**).
- **Logging:** JSON logger + metadata filter from Phase 1 — span attributes must stay as redaction-safe as logs (**D-913**).

### Integration Points

- **`Application.start/2`:** Early OTel SDK + exporter config before heavy work (**D-912**).
- **Oban workers / stage executor:** Propagation injection + manual spans around Docker `System.cmd` and Req-based LLM calls (**D-912–D-913**).

</code_context>

<specifics>
## Specific Ideas

- Treat dogfood automation like **Dependabot-class bots**: deterministic inputs, deduped PRs, labels, auto-merge—not ad-hoc scripts.
- **Collector → Jaeger** default matches “principle of least surprise” for local solo DX while staying **vendor-neutral** at the app boundary (**D-911**).
- Subagent consensus: **Apache-2.0** for LICENSE if a public future is plausible; keep **MIT** as documented alternative if legal minimalism wins—**D-922** locks Apache-2.0 unless planner finds blocking dependency incompatibility.

</specifics>

<deferred>
## Deferred Ideas

- **Merge queue (GitHub):** Add only if v0.1.0 dogfood hits repeated merge-order failures (**D-902**).
- **Playwright / Wallaby E2E:** Defer unless LiveView tests cannot cover a critical onboarding path (**D-930**).
- **OTel metrics + dashboards:** Defer until experimental Erlang metrics path is acceptable (**D-910**).
- **Phase 999.1 docs & landing site:** Remains backlog slot decision in ROADMAP—**not** part of v0.1.0 unless explicitly promoted.

### Reviewed Todos (not folded)

- None.

</deferred>

---

*Phase: 09-dogfood-release-v0-1-0*
*Context gathered: 2026-04-21*
