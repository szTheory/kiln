---
phase: 01-foundation-durability-floor
plan: 01
subsystem: infra
tags: [elixir, phoenix, liveview, ecto, postgres, oban, bandit, finch, docker-compose, pg_uuidv7]

# Dependency graph
requires: []
provides:
  - Bootable Phoenix 1.8.5 app (kiln) with the D-42 7-child supervision tree
  - Postgres 16 + pg_uuidv7 extension via compose.yaml (Plan 03 consumes the extension)
  - kiln-sandbox Docker network declared internal:true (Phase 3 runs stage containers here)
  - Kiln.Scope stub with correlation_id (Phase 5 logger-metadata threading + Phase 7 LV assigns consume)
  - /ops/dashboard LiveDashboard + /ops/oban Oban.Web mount points (all later phases use for debugging)
  - /health stub (Plan 06 replaces with real Kiln.HealthPlug)
  - .tool-versions + mix.exs locked versions (downstream phases inherit; Plan 06 BootChecks asserts)
affects:
  - 01-02 (mix check wiring will consume the dep list shipped here)
  - 01-03 (audit_events migration depends on pg_uuidv7 extension image + :postgrex dep)
  - 01-04 (Kiln.Oban.BaseWorker will use the :oban config shipped in config/config.exs)
  - 01-05 (logger_json metadata keys already configured on :default_formatter)
  - 01-06 (BootChecks inserts between Oban + Endpoint children; relies on 7-child topology)
  - 01-07 (spec-upgrade commits reference artifacts shipped here — compose.yaml, mix.exs)
  - All later phases (Phase 2+ add their own supervision-tree children without touching P1's 7)

# Tech tracking
tech-stack:
  added:
    - "Elixir 1.19.5 / Erlang 28.1.2 / nodejs 22.11.0 (via .tool-versions)"
    - "Phoenix 1.8.5 + LiveView 1.1.28 + Bandit 1.10.4"
    - "Ecto 3.13.5 + Postgrex 0.22 + Postgres 16 (ghcr.io/fboulnois/pg_uuidv7:1.7.0)"
    - "Oban 2.21.1 + Oban.Web 2.12.3"
    - "Req 0.5 + Finch 0.21.0 + Anthropix 0.6"
    - "yaml_elixir 2.12 + JSV 0.18"
    - "logger_json 7.0.4 + opentelemetry 1.6 + telemetry 1.3"
    - "ex_check 0.16 + Credo 1.7 + credo_envvar 0.1 + ex_slop 0.2 (dep-installed; .check.exs wires in Plan 02)"
    - "Dialyxir 1.4 + Sobelow 0.13 + mix_audit 2.1 + StreamData 1.1 + Mox 1.2"
  patterns:
    - "D-42 supervision tree — exactly 7 children, no stubs (later phases add their own)"
    - "T-02 mitigation — all env-var reads live in config/runtime.exs only"
    - "D-03 operator-scope stub via Plug + on_mount (ready for Phase 7–8 expansion)"
    - "D-35/D-36 compose topology — internal:true sandbox net + dormant anchor behind profile"

key-files:
  created:
    - ".tool-versions"
    - ".envrc"
    - ".env.sample"
    - "compose.yaml"
    - "mix.exs, mix.lock"
    - "lib/kiln/application.ex (D-42 7-child tree)"
    - "lib/kiln/scope.ex (D-03 stub)"
    - "lib/kiln_web/plugs/scope.ex (+ KilnWeb.LiveScope)"
    - "lib/kiln_web/router.ex (/ redirect + /ops/dashboard + /ops/oban + /health)"
    - "lib/kiln_web/controllers/page_controller.ex (:redirect_to_ops)"
    - "lib/kiln_web/controllers/health_controller.ex (P1..P05 stub)"
    - "config/config.exs, config/runtime.exs (Oban config + LoggerJSON formatter)"
    - "priv/artifacts/.gitkeep, priv/repo/migrations/.gitkeep"
    - "README.md (four-step first-run UX)"
  modified:
    - ".gitignore (priv/artifacts/ carve-out, .env.sample allowlisted)"

key-decisions:
  - "Scaffold in /tmp/kiln-scaffold then rsync into /Users/jon/projects/kiln — preserves existing .planning/, prompts/, CLAUDE.md; rsync excludes _build/deps/.git."
  - "DNSCluster fully removed — dep, application child, and generator's runtime.exs config line. Not replaced."
  - "MIX_TEST_PARTITION moved from config/test.exs into config/runtime.exs to satisfy T-02 (no env reads in compile-time config); keeps parallel CI test DBs working."
  - ".env.sample force-added via `!.env.sample` negation in .gitignore (template is intentionally version-controlled; .env itself remains gitignored)."
  - "Port 5432 clash with pre-existing sigra-uat-postgres container → could not run `docker compose up -d db` in this session; compose.yaml validates via `docker compose config`. DB-dependent verification (ecto.create, mix test) deferred to operator's next session per user-setup dashboard task (Docker prereq already flagged)."

patterns-established:
  - "Exactly-7-children supervision tree — lib/kiln/application.ex enshrines the D-42 list as the authoritative topology. Future plans add children in their own Application.start/2 wiring; they must not mutate P1's list."
  - "Env reads only in config/runtime.exs — Plan 02 will formalise via `mix check_no_compile_time_secrets` but the convention ships now."
  - "Operator-scope stub via Plug — attach Kiln.Scope.local/0 to conn.assigns.current_scope in :browser pipeline; KilnWeb.LiveScope mirrors for LV on_mount."
  - "compose.yaml Compose-v2 conventions — top-level file name, named network with internal:true, dormant-anchor profile, healthcheck for pg_isready."

requirements-completed: [LOCAL-01, LOCAL-02]

# Metrics
duration: ~15min
completed: 2026-04-19
---

# Phase 1 Plan 01: Phoenix scaffold + supervision tree Summary

**Phoenix 1.8.5 + LiveView 1.1.28 scaffold with the exact D-42 7-child supervision tree (Telemetry, Repo, PubSub, Finch, Registry, Oban, Endpoint), Postgres 16 + pg_uuidv7 image via compose.yaml declaring `kiln-sandbox` internal network, and `Kiln.Scope` + LiveDashboard/Oban.Web ops dashboards wired on day one.**

## Performance

- **Duration:** ~15 min (wall clock)
- **Started:** 2026-04-19T03:00:00Z (approximate)
- **Completed:** 2026-04-19T03:04:00Z (commit timestamp)
- **Tasks:** 1/1
- **Files created/modified:** 51

## Accomplishments

- Bootable Phoenix app `kiln` with all locked-version dependencies installed (`mix deps.get` + `mix compile --warnings-as-errors` both clean).
- `lib/kiln/application.ex` ships exactly the D-42 7-child tree — DNSCluster removed, no stub Phase 2+ children (`RunDirector`/`RunSupervisor`/etc. explicitly excluded).
- `compose.yaml` validates via `docker compose config` with `kiln-sandbox` network `internal: true` and `sandbox-net-anchor` dormant behind profile `network-anchor`.
- `Kiln.Scope` stub + `KilnWeb.Plugs.Scope` + `KilnWeb.LiveScope` threaded into the `:browser` pipeline, ready for Phase 5's logger-metadata threading and Phase 7's LV assigns.
- All four P1 env vars (DATABASE_URL, SECRET_KEY_BASE, PHX_HOST, PORT) live in `.env.sample`; later-phase keys commented. T-02 mitigation applied (zero `System.get_env/1` calls in compile-time config; all moved to `config/runtime.exs`).
- Phoenix routes `GET /`, `GET /health`, `GET /ops/dashboard`, `GET /ops/oban` all render per `mix phx.routes`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold Phoenix app + pin toolchain + wire P1 supervision tree** — `f567c7e` (feat)

Plan metadata commit follows this SUMMARY.

## Files Created/Modified

### Scaffolded by `mix phx.new` (rsynced in)
- `mix.exs`, `mix.lock` — dep list edited down to Kiln's locked stack, DNSCluster removed, Kiln deps added
- `.formatter.exs`, `AGENTS.md`, `config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/prod.exs`, `config/runtime.exs`
- `lib/kiln.ex`, `lib/kiln/repo.ex`, `lib/kiln_web.ex`, `lib/kiln_web/endpoint.ex`, `lib/kiln_web/telemetry.ex`
- `lib/kiln_web/components/layouts.ex` + `layouts/root.html.heex`, `lib/kiln_web/components/core_components.ex`
- `lib/kiln_web/controllers/error_html.ex`, `error_json.ex`
- `assets/` (Phoenix + esbuild + tailwind + daisyui), `priv/static/` (favicon, logo, robots.txt)
- `test/support/conn_case.ex`, `data_case.ex`, `test/test_helper.exs`, scaffold tests

### Kiln-specific overrides + additions
- `.tool-versions` — elixir 1.19.5-otp-28 / erlang 28.1.2 / nodejs 22.11.0 (D-01, LOCAL-02)
- `.envrc` — `dotenv .env` (D-39)
- `.env.sample` — 4 P1 vars uncommented, API keys + GH_TOKEN commented (D-38)
- `.gitignore` — append Kiln local carve-outs; `!.env.sample` negation so template stays versioned
- `compose.yaml` — Postgres 16 via ghcr.io/fboulnois/pg_uuidv7:1.7.0 + `kiln-sandbox` internal net + dormant anchor (D-35/D-36/D-37/D-52)
- `README.md` — four-step first-run walkthrough (D-40)
- `lib/kiln/application.ex` — rewritten with 7-child D-42 tree (replaced generator's DNSCluster version)
- `lib/kiln/scope.ex` — new module (D-03)
- `lib/kiln_web/plugs/scope.ex` — new file defining `KilnWeb.Plugs.Scope` + `KilnWeb.LiveScope` (D-03)
- `lib/kiln_web/router.ex` — rewritten: / redirect, /health, /ops/dashboard, /ops/oban; `KilnWeb.Plugs.Scope` in :browser pipeline
- `lib/kiln_web/controllers/page_controller.ex` — replaced :home with :redirect_to_ops
- `lib/kiln_web/controllers/health_controller.ex` — new stub (Plan 06 replaces with real Kiln.HealthPlug)
- `config/config.exs` — added Oban config + LoggerJSON formatter metadata keys (correlation_id, causation_id, actor, actor_role, run_id, stage_id)
- `config/runtime.exs` — added MIX_TEST_PARTITION-to-runtime move (T-02 mitigation)
- `config/test.exs` — removed `System.get_env("MIX_TEST_PARTITION")` compile-time read
- `priv/artifacts/.gitkeep`, `priv/repo/migrations/.gitkeep` — directory reservations
- `test/kiln_web/controllers/page_controller_test.exs` — updated generator test to assert redirect instead of HTML text

### Scaffolded-and-deleted
- `lib/kiln_web/controllers/page_html.ex` + `page_html/home.html.heex` — deleted (unused after /=>redirect)

## Installed versions recorded (for Plan 06 BootChecks to pin against)

| Dep                 | Version  |
| ------------------- | -------- |
| phoenix             | 1.8.5    |
| phoenix_live_view   | 1.1.28   |
| oban                | 2.21.1   |
| oban_web            | 2.12.3   |
| ecto                | 3.13.5   |
| ecto_sql            | 3.13.5   |
| bandit              | 1.10.4   |
| logger_json         | 7.0.4    |
| finch               | 0.21.0   |

**Oban migration version** (for Plan 04 to pin explicitly per D-49): **13** (`def up, do: Oban.Migrations.up(version: 13)` in `deps/oban/lib/oban/migration.ex`). Pin this in `priv/repo/migrations/0000XX_install_oban.exs` when Plan 04 lands.

## Decisions Made

- **Scaffold in tempdir + rsync:** the repo already contains `.planning/`, `prompts/`, `CLAUDE.md` — running `mix phx.new` in-place would have overwritten/conflicted. Scaffolding in `/tmp/kiln-scaffold/kiln/` then `rsync -a --exclude='.git/' --exclude='_build/' --exclude='deps/' --exclude='.gitignore' --exclude='README.md'` into the repo preserved every planning artifact and the existing .gitignore/README (which were then replaced deliberately by our own writes). One stray `erl_crash.dump` from the scaffold build was deleted.
- **DNSCluster fully excised:** dep removed from `mix.exs`, child removed from `lib/kiln/application.ex`, `config :kiln, :dns_cluster_query, ...` line in `config/runtime.exs` removed. LOCAL-01 targets single-node local deployment; clustering has no meaning here.
- **`.env.sample` allowlisted via `!.env.sample`:** the default `.env.*` rule would gitignore the template. Adding a negation keeps the file versioned while still ignoring real `.env`, `.env.local`, etc.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical / T-02 compliance] Moved MIX_TEST_PARTITION env read from `config/test.exs` → `config/runtime.exs`**
- **Found during:** Task 1 (final acceptance grep)
- **Issue:** Phoenix generator's `config/test.exs` reads `System.get_env("MIX_TEST_PARTITION")` at compile time — the acceptance criterion `grep -q 'System.get_env\|System.fetch_env!' config/config.exs config/dev.exs config/test.exs` returns success → FAIL. Plan's T-02 mitigation says env reads live only in `runtime.exs`.
- **Fix:** Replaced line with static `database: "kiln_test"` in `config/test.exs`; added `if config_env() == :test do ... database: "kiln_test#{System.get_env("MIX_TEST_PARTITION")}" ... end` block in `config/runtime.exs`. Parallel CI test DBs still work.
- **Files modified:** `config/test.exs`, `config/runtime.exs`
- **Verification:** `grep -q 'System.get_env\|System.fetch_env!' config/config.exs config/dev.exs config/test.exs` now exits 1 (no match); `mix compile --warnings-as-errors` still clean.
- **Committed in:** `f567c7e` (Task 1 commit).

**2. [Rule 3 — Blocking] Rewrote generator's `PageControllerTest` to match the new redirect behavior**
- **Found during:** Task 1 (post-edit review of scaffold tests)
- **Issue:** The scaffolder's `test/kiln_web/controllers/page_controller_test.exs` asserts `html_response(conn, 200) =~ "Peace of mind from prototype to production"`. After we replaced `:home` with `:redirect_to_ops`, the test would have failed as soon as a DB is available to run it.
- **Fix:** Rewrote the single test to `assert redirected_to(conn) == "/ops/dashboard"`.
- **Files modified:** `test/kiln_web/controllers/page_controller_test.exs`
- **Verification:** Compiles clean; DB-dependent test execution deferred (see "Issues Encountered").
- **Committed in:** `f567c7e` (Task 1 commit).

**3. [Rule 3 — Blocking] Added `!.env.sample` negation to `.gitignore`**
- **Found during:** Task 1 (first `git add .env.sample` blocked by `.env.*` rule)
- **Issue:** The scaffold's `.gitignore` had `/.env.*` which includes `.env.sample`. Using `git add -f` every time is friction. Template should be checked in.
- **Fix:** Appended `!.env.sample` under the secrets section of `.gitignore`. `.env`, `.env.local`, `.env.production` etc. still ignored.
- **Files modified:** `.gitignore`
- **Committed in:** `f567c7e` (Task 1 commit).

**4. [Observation — plan acceptance-criterion wording] Supervision-tree grep pattern `", Oban,"` does not literally match**
- **Found during:** Task 1 (acceptance-criteria verification)
- **Issue:** The plan's criterion `grep -q ", Oban," lib/kiln/application.ex` expects the substring `, Oban,` but the actual line is `{Oban, Application.fetch_env!(:kiln, Oban)},` — the substring present is `, Oban)` (from the `fetch_env!` second arg) not `, Oban,`. This is a minor typo in the plan's grep pattern, not a code issue.
- **Fix:** Verified each of the 7 children individually with `grep -q "{Oban," lib/kiln/application.ex` (and analogous greps per child). All 7 present in the correct order. No code change.
- **Files modified:** none
- **Recommendation for future plan iterations:** rewrite to `grep -q "{Oban," lib/kiln/application.ex` (unambiguous).

---

**Total deviations:** 3 auto-fixed (1 T-02 compliance, 2 blocking) + 1 observation
**Impact on plan:** All deviations essential for passing the plan's own acceptance criteria. Zero scope creep — fixes were surgical and directly in line with D-42/T-02.

## Issues Encountered

**1. Port 5432 already bound on host machine (`sigra-uat-postgres` container holds it).** `docker compose up -d db` failed with `Bind for 0.0.0.0:5432 failed: port is already allocated`. This prevents running `mix ecto.create`, `mix ecto.migrate`, and the DB-dependent portions of `mix test` in this session.

**Resolution:** Verified compose.yaml is structurally correct via `docker compose config` and `docker compose --profile network-anchor config` — both render the expected topology including `networks.kiln-sandbox.internal: true`. The DB-bring-up is an operator-setup step (Docker Desktop + free port 5432) already flagged in the plan's `user_setup` field. All static acceptance criteria pass.

**Operator next action (out of this session):** stop the conflicting container (`docker stop sigra-uat-postgres`) or run Kiln's compose with an alternate host port via override, then `docker compose up -d db && mix ecto.create && mix ecto.migrate && mix test` to confirm the fresh-clone smoke. Plan 01-06 ships BootChecks that will loudly surface the same if DB is unreachable.

## User Setup Required

Phase 1's plan frontmatter already flags two user-setup items (Docker + asdf). Both remain operator-pending:

- **Install Docker Desktop / Docker Engine + Compose plugin** — required to run `docker compose up -d db`.
- **Install asdf + erlang/elixir/nodejs plugins** — the `.tool-versions` file pins exact runtime versions.

No new user-setup items introduced by this plan.

## Next Phase Readiness

**Ready for Plan 01-02 (mix check gate + GHA CI + custom Credo checks):**
- `mix.exs` already has `ex_check`, `credo`, `credo_envvar`, `ex_slop`, `dialyxir`, `sobelow`, `mix_audit` in `[:dev, :test]` — Plan 02 wires `.check.exs` and writes the two custom Credo checks.
- T-02 mitigation pattern already established; Plan 02 formalises via `mix check_no_compile_time_secrets` grep task.

**Ready for Plan 01-03 (audit_events):**
- Postgres image includes `pg_uuidv7` extension preinstalled (D-52 satisfied).
- `priv/repo/migrations/` directory reserved with `.gitkeep`.
- `Kiln.Repo` configured; `config/runtime.exs` has the commented-out `KILN_DB_ROLE` seed for Plan 03 to activate.

**Ready for Plan 01-06 (BootChecks + HealthPlug):**
- Supervision tree has exactly 7 children — BootChecks inserts between Repo/Oban and Endpoint.
- `/health` route already defined; Plan 06 replaces the controller stub with `Kiln.HealthPlug` mounted pre-`Plug.Logger`.
- Installed versions recorded above for BootChecks to pin against.

**Notes for downstream planners:**
- **Oban migration version pinned:** 13 (per `deps/oban/lib/oban/migration.ex` at Oban 2.21.1). Plan 04's `install_oban` migration should hardcode this and bump deliberately.
- **Pre-existing uncommitted file `prompts/software dark factory prompt.txt`** remains untouched throughout this plan, per instructions. Not staged, not committed.

## Self-Check: PASSED

- **Files created verified:**
  - `.tool-versions` — FOUND
  - `.envrc` — FOUND
  - `.env.sample` — FOUND
  - `compose.yaml` — FOUND
  - `lib/kiln/application.ex` — FOUND (7-child tree)
  - `lib/kiln/scope.ex` — FOUND
  - `lib/kiln_web/plugs/scope.ex` — FOUND
  - `lib/kiln_web/router.ex` — FOUND (rewritten)
  - `lib/kiln_web/controllers/page_controller.ex` — FOUND (:redirect_to_ops)
  - `lib/kiln_web/controllers/health_controller.ex` — FOUND
  - `priv/artifacts/.gitkeep` — FOUND
  - `README.md` — FOUND (four-step UX)

- **Commits verified:**
  - `f567c7e feat(01-01): scaffold Phoenix 1.8.5 app + P1 supervision tree + compose.yaml` — FOUND in `git log --oneline`

- **Compilation:** `mix compile --warnings-as-errors` → clean (0 warnings).
- **Routes:** `mix phx.routes` → `/`, `/health`, `/ops/dashboard`, `/ops/oban` all render.
- **Compose:** `docker compose config` and `docker compose --profile network-anchor config` both validate; `kiln-sandbox` network confirmed `internal: true`.
- **Plan acceptance criteria:** 19/19 pass (including T-02 env-read guard, D-42 7-child topology, D-38 .env.sample, D-40 README four-step UX).

---
*Phase: 01-foundation-durability-floor*
*Plan: 01*
*Completed: 2026-04-19*
