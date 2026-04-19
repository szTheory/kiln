# Phase 1: Foundation & Durability Floor - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Project boots reproducibly from a fresh clone via `docker compose up`, writes every side-effect through a durability- and idempotency-safe baseline (Postgres-truth, INSERT-only audit ledger with three-layer enforcement, two-phase `external_operations` intent table, structured JSON logging with correlation metadata threading), runs a strict CI gate (`mix check` with custom invariant-enforcing checks), and **fails loudly when invariants are violated** — both at boot and in CI.

Phase 1 ships the supervision-tree skeleton, the `Kiln.Audit` and `Kiln.Telemetry` contexts, the `Kiln.Oban.BaseWorker` with safe defaults, the `external_operations` intent table, the `Kiln.Health` controller, the `Kiln.BootChecks` invariant assertions, the `compose.yaml` infrastructure, the `.tool-versions`, and the GitHub Actions CI running `mix check` — and *nothing else*. Workflow engine, run state machine, agents, sandboxes, GitHub integration, UI, and operator UX all belong to later phases.

</domain>

<decisions>
## Implementation Decisions

### Phoenix Scaffold (Option A — full scaffold + ops dashboards on day one)

- **D-01:** Scaffold with `mix phx.new kiln --database postgres --binary-id --no-mailer --no-gettext --install`. `--binary-id` matches Postgres UUID convention and is hard to reverse later. `--no-html` / `--no-assets` deliberately NOT used because Phoenix generators silently assume HTML scaffolding exists; reversing in Phase 7 means hand-rolling `core_components.ex`, layouts, asset config, and endpoint static plug. `--no-mailer` and `--no-gettext` are easily reversible.
- **D-02:** Mount `Phoenix.LiveDashboard` at `/ops/dashboard` and `Oban.Web` at `/ops/oban` in Phase 1 (single router macro lines). The Kiln engineer needs these dashboards to *visually* debug correlation_id threading, Oban job retries, and `external_operations` two-phase semantics during Phases 2–6 build — debugging via raw SQL against `oban_jobs` is painful and slow.
- **D-03:** Stub `%Kiln.Scope{operator: :local, correlation_id: ..., started_at: ...}` from day one, threaded via an `on_mount` callback and a Plug. ~30 LOC. Avoids retrofitting the public API of all 12 bounded contexts when Phase 7–8 generators run (Phoenix 1.8 generators expect `current_scope` to exist in assigns). The `correlation_id` lives on the scope, integrating cleanly with `logger_json` metadata propagation.
- **D-04:** Replace generated `PageController` with `Kiln.HealthController` returning JSON at `/health` (~10 LOC). For the Phase 1–6 empty-state UX, mount `Phoenix.LiveDashboard` at `/` redirecting to `/ops/dashboard` so operators see immediate signal-of-life. Phase 8's `KilnWeb.OnboardingLive` takes over `/` when it ships. Skip `mix phx.gen.auth` entirely — opt-in only, nothing to remove.
- **D-05:** Bandit is the Phoenix 1.8 default; no `:server` config flag needed.

### `audit_events` Schema (durability ledger)

- **D-06:** PK = **UUID v7** via the `pg_uuidv7` Postgres extension on Postgres 16. Migrate to native `uuidv7()` when the project moves to Postgres 18. Time-sortable (b-tree locality preserved), externally referenceable (URL params in Phase 7 audit ledger, OTel trace correlation, JSON serialization), forward-compatible with v2 multi-node. 16-byte index cost accepted.
- **D-07:** `event_kind` storage = **`text` column + `CHECK` constraint**, NOT a Postgres ENUM. Rationale: ENUM `ALTER TYPE ADD VALUE` cannot run inside a transaction and takes `ACCESS EXCLUSIVE` lock — taxonomy will evolve through Phases 2–9. `Kiln.Audit.EventKind` Elixir module is the single source of truth that generates both the migration constraint and the `Ecto.Enum`.
- **D-08:** Initial 22-value `event_kind` taxonomy: `run_state_transitioned`, `stage_started`, `stage_completed`, `stage_failed`, `external_op_intent_recorded`, `external_op_action_started`, `external_op_completed`, `external_op_failed`, `secret_reference_resolved`, `model_routing_fallback`, `budget_check_passed`, `budget_check_failed`, `stuck_detector_alarmed`, `scenario_runner_verdict`, `work_unit_created`, `work_unit_state_changed`, `git_op_completed`, `pr_created`, `ci_status_observed`, `block_raised`, `block_resolved`, `escalation_triggered`. Phases that don't ship until later (e.g. `scenario_runner_verdict` lands in P5) declare their kind in P1 so the taxonomy is locked early.
- **D-09:** Payload validation = **app-side JSV per-kind at `Kiln.Audit.append/1` boundary**, with `schema_version :: integer` column. JSV is already in the stack (zero new deps). One JSON Schema 2020-12 file per kind under `priv/audit_schemas/v1/{kind}.json`. Skip `pg_jsonschema` (Rust extension; defense at wrong layer when the only writer is `Kiln.Audit.append/1`; published benchmarks show ~50× slower than alternatives).
- **D-10:** Indexes = **5 b-tree composites**, no GIN initially: `(run_id, occurred_at DESC) WHERE run_id IS NOT NULL`, `(stage_id, occurred_at DESC) WHERE stage_id IS NOT NULL`, `(event_kind, occurred_at DESC)`, `(actor_id, occurred_at DESC)`, `(correlation_id)`. Covers Phase 7 UI-05's filter UI (run/stage/actor/event-type/time-range). Add GIN on `payload` only if Phase 7 declares payload-deep filters.
- **D-11:** Partitioning **deferred** — at the projected ~700k events/year baseline, `pg_partman` becomes interesting around 10M rows (years away). Revisit when row count crosses 5M.
- **D-12: Defense-in-depth INSERT-only enforcement (THREE layers, not RULE alone).** **This upgrades the existing CLAUDE.md spec.** PG `CREATE RULE` has documented silent-bypass modes (its WHERE-clause AND-ing with the query's WHERE can produce `UPDATE 0` on a malformed mutation without raising an error) — for a security-critical audit ledger, silent enforcement failure is the worst possible outcome. The shipped enforcement is:
  - **Layer 1 (primary, role-based):** `REVOKE UPDATE, DELETE, TRUNCATE ON audit_events FROM kiln_app` + `GRANT INSERT, SELECT ON audit_events TO kiln_app`. Any attempted mutation as the runtime role raises `Postgrex.Error %{postgres: %{code: :insufficient_privilege}}` (SQLSTATE 42501). Loud.
  - **Layer 2 (trigger-based, role-bypass-resistant):** `BEFORE UPDATE OR DELETE OR TRUNCATE` trigger function `audit_events_immutable()` that `RAISE EXCEPTION 'audit_events is append-only (Kiln immutability invariant); attempted % blocked'`. Catches the case where a future migration accidentally connects as table owner.
  - **Layer 3 (RULE, CLAUDE.md-original safety net):** `CREATE RULE audit_events_no_update AS ON UPDATE TO audit_events DO INSTEAD NOTHING` and equivalent for DELETE. Final no-op safety net.
  - **Migration test asserts all three paths** (as `kiln_app`: permission denied; as table owner: trigger raises; with triggers disabled: rule no-ops).
- **D-13:** Resolve table-naming drift — ARCHITECTURE.md §9 says `events`; CLAUDE.md and Phase 1 SC #4 say `audit_events`. **Standardize on `audit_events`** and update ARCHITECTURE.md §9 in the same commit chain. (Spec correction, not a new decision.)

### `external_operations` Schema (idempotency intent table)

- **D-14:** **Single table** + polymorphic JSONB payloads (Brandur Rocket-Rides-Atomic / Stripe pattern). Per-context tables (`github_operations`, `llm_operations`, `docker_operations`) would force re-implementing the same intent→action→completion machine four times in Phases 3, 6, and 8 — opportunity for drift.
- **D-15:** Idempotency key = **flat string** `"#{run_id}:#{stage_id}:#{op_name}"` + single UNIQUE INDEX. Matches Stripe's HTTP `Idempotency-Key` header convention. Trivially debuggable in psql. For non-`run_id`-scoped system ops, prefix with `system:`.
- **D-16:** State enum = **5 values**, text + CHECK: `intent_recorded → action_in_flight → completed | failed | abandoned`. The 5th state (`:abandoned`) lets the Phase 5 `StuckDetector` mark orphans (intent recorded but action never started) distinctly from runtime failures. From Phase 1 onward, only `intent_recorded` and `completed` are written; later phases activate the other transitions.
- **D-17:** Initial 10-value `op_kind` taxonomy: `git_push`, `git_commit`, `gh_pr_create`, `gh_check_observe`, `llm_complete`, `llm_stream`, `docker_run`, `docker_kill`, `osascript_notify`, `secret_resolve`. Most are stubs in P1; real workers ship in P3 (LLM, Docker, secrets, notify), P6 (git, gh).
- **D-18:** Each `external_operation` row writes **2 audit events** (`external_op_intent_recorded` + `external_op_completed | external_op_failed`). Satisfies CLAUDE.md "every state transition writes an Audit.Event" mandate. Audit row volume ~doubles but stays under partitioning threshold for years.
- **D-19:** Cleanup = **30-day TTL prune `:completed` rows only** via an Oban-Pruner-style worker. `:failed` and `:abandoned` rows kept indefinitely for forensics. Result payload preserved in `audit_events.payload` forever regardless.
- **D-20:** PK = UUID v7 (same `pg_uuidv7` extension as audit_events). Consistency.
- **D-21:** Columns: `id, op_kind, idempotency_key, state, schema_version, intent_payload, result_payload, attempts, last_error, run_id, stage_id, intent_recorded_at, action_started_at, completed_at, inserted_at, updated_at`. Indexes: `(state) WHERE state IN ('intent_recorded','action_in_flight')`, `(run_id)`, `(op_kind, state)`, plus the unique index on `idempotency_key`.

### CI Gate (`mix check`) — Option B Balanced

- **D-22:** `mix check` (ex_check 0.16) wired into GitHub Actions with: `mix format --check-formatted` (hard gate), `mix compile --warnings-as-errors` (hard gate), Credo `--strict`, Dialyzer fail-on-warning, Sobelow HIGH-only with `--mark-skip-all` baseline, `mix_audit` fail-on-any with `.mix_audit.exs` allowlist file (commented + dated), `mix xref graph --format cycles` as a hard gate (no-op until P2 contexts exist; defends the 12-context strict DAG).
- **D-23:** Add `credo_envvar` (Hex package; covers P15 compile-time-secrets pattern) and `ex_slop` (Hex package, 23 LLM-anti-pattern checks; aligns with Phase 9 dogfood — Kiln will eventually generate Kiln code, and these checks catch exactly that class of anti-pattern).
- **D-24:** **Hand-write 2 custom Credo checks**, both AST-trivial (~20 LOC each, near-zero false-positive risk):
  - `Kiln.Credo.NoProcessPut` — flags any `Process.put/1,2` use (CLAUDE.md banned).
  - `Kiln.Credo.NoMixEnvAtRuntime` — flags `Mix.env()` use outside `def deps/0` and `mix.exs`.
  Both ship with `Credo.Test.Case` coverage.
- **D-25:** **Skip** custom Credo checks for `NoStatelessGenServer`, `NoUnsupervisedSpawn`, `NoApplyHotPath`, `BooleanObsession` — all need flow analysis Credo's prewalk-AST API can't reliably do; high false-positive rate trains the engineer to ignore the linter (worst outcome).
- **D-26:** Pre-create two grep-based Mix tasks in P1 so later phases inherit them at zero scaffolding cost:
  - `mix check_no_compile_time_secrets` — greps `config/{config,dev,prod}.exs` for `System.get_env`/`System.fetch_env!`, fails if found. Wired into `.check.exs`.
  - `mix check_no_manual_qa_gates` — greps `lib/` for `TODO|FIXME|ASK-HUMAN` markers in code paths. Stub in P1; Phase 5 fleshes out for UAT-01 enforcement.
- **D-27:** Dialyzer PLT cache key = `${OS}-${OTP}-${ELIXIR}-${hashFiles('mix.lock')}` (2026 community standard; ~30s warm-cache build, 5–10min cold).
- **D-28:** **No pre-commit hook** (no lefthook). Solo engineers documented to bypass with `--no-verify` under deadline; the hook gives DX cost without enforcement gain. Use a `make check` (or `mix check`) target instead so local + CI run identically.
- **D-29:** **Single CI runner**: Ubuntu 24.04 + Elixir 1.19.5-otp-28 + OTP 28.1.2 + Postgres 16 service container. `erlef/setup-beam@v1.23.0`. **No Postgres 17 matrix** (Ecto/Postgrex abstract version differences; doubling CI minutes for ~zero coverage gain).
- **D-30:** ex_check default failure output (no Kiln-branded wrapper — maintenance debt, diverges from upstream).

### Health Endpoint, Boot Checks, DTU, Local Dev

- **D-31:** Single hand-rolled `Kiln.HealthPlug` (~30 LOC), mounted **before `Plug.Logger`** in `KilnWeb.Endpoint`. Returns JSON `{"status":"ok|degraded|down","postgres":"up|down","oban":"up|down","contexts":12,"version":"..."}`. The same JSON is the source of truth for Phase 7's factory header (consumed via PubSub-driven LiveView). **No separate `/healthz` + `/readyz` split** — Kubernetes-style probes are over-engineering for a solo local-only product (PROJECT.md Out of Scope: hosted cloud runtime).
- **D-32:** `Kiln.BootChecks.run!/0` invoked from `Kiln.Application.start/2` **after** `Repo` and `Oban` come up but **before** `Endpoint`. Raises (terminating BEAM) on:
  - any of the 12 contexts not compiled (`Code.ensure_compiled?/1` for each `Kiln.<Context>` module)
  - `audit_events` `REVOKE` not active (validated by attempting an `UPDATE` as `kiln_app` and asserting `:insufficient_privilege`)
  - `audit_events` trigger not active (validated by attempting an `UPDATE` with elevated role)
  - Oban migration version mismatch
  - Required secrets unresolvable in `:dev` and `:prod` (Anthropic API key may be missing in `:dev`; Postgres URL must be present)
  Generalizes Plausible's SECRET_KEY_BASE-at-boot pattern.
- **D-33:** `KILN_SKIP_BOOTCHECKS=1` env var = escape hatch for `iex -S mix` and emergency debugging. Logged loudly when active.
- **D-34:** `mix kiln.boot_checks` standalone Mix task = same invariant assertions, callable from CI's GitHub Actions Postgres service container. **No `docker compose up` in CI**; CI parity comes from the Mix task.
- **D-35:** Compose file = **`compose.yaml`** (Compose v2 canonical filename), not `docker-compose.yml`. Top-level `kiln-sandbox` network with `internal: true` (Docker bridge with no external gateway — egress blocked at the network layer). Compose materializes top-level networks on `up` even without an attached service.
- **D-36:** DTU placeholder = `alpine sleep infinity` `sandbox-net-anchor` service behind `profiles: ["network-anchor"]`. **Dormant by default.** Phase 3 activates with `docker compose --profile network-anchor up` for egress negative tests. Avoids running an unneeded sleep loop on every fresh-clone `compose up`.
- **D-37:** Postgres healthcheck in `compose.yaml`: `test: ["CMD-SHELL", "pg_isready -U kiln"], interval: 2s, timeout: 5s, retries: 10`. **No app healthcheck in compose** — the Phoenix app runs on the host (asdf-managed) for fastest dev loop per STACK.md, not in compose.
- **D-38:** `.env.sample` ships with **only the four vars Phase 1 needs to boot**: `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`. API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `GH_TOKEN`) documented inline as `# Phase 3` / `# Phase 6` comments — present but commented out / empty.
- **D-39:** `.env` loading = **direnv** (`.envrc` with `dotenv .env`) is the recommended path; the asdf-direnv plugin makes it seamless given LOCAL-02's asdf requirement. README provides `set -a; source .env; set +a` shell fallback for operators who skip direnv.
- **D-40:** First-run UX: `cp .env.sample .env && docker compose up -d && mix setup && mix phx.server` → `curl localhost:4000/health` returns 200 with the JSON dependency object. Failure produces a structured `Kiln.BootChecks.Error` with a remediation hint (which mirrors Phase 8's typed-block-reason pattern at boot).
- **D-41:** Workspace artifacts (per-run diffs, logs) = `priv/artifacts/` (gitignored). Phase 1 ships the `.gitkeep`; population happens P3 onward.

### Application Architecture (P1 surface only)

- **D-42:** Phase 1 supervision tree contains **only the children P1 actually exercises**: `KilnWeb.Telemetry`, `Kiln.Repo`, `{Phoenix.PubSub, name: Kiln.PubSub}`, `{Finch, name: Kiln.Finch}` (named pool — Req uses it via `req: [finch: Kiln.Finch]`), `{Registry, keys: :unique, name: Kiln.RunRegistry}`, `Oban`, `KilnWeb.Endpoint`. **Do NOT** ship stub `RunDirector` / `RunSupervisor` / `Sandboxes.Supervisor` / `StuckDetector` / `Agents.SessionSupervisor` / `DTU.Supervisor` children in P1 — they have no behavior to exercise yet, and shipping them as no-op `:permanent` children with TODOs creates dead code that must be restructured at P2/3/4/5. Each phase adds its own children when it has behavior to put behind them.
- **D-43:** `Kiln.Audit` and `Kiln.Telemetry` contexts ship in P1 with full behavior — they are foundational and every later phase writes through them.
- **D-44:** `Kiln.Oban.BaseWorker` ships with `max_attempts: 3` default (overrides Oban's 20 default per PITFALLS P9), `unique: [keys: [:idempotency_key], period: :infinity, states: [:available, :scheduled, :executing]]`, and idempotency helpers (`fetch_or_record_intent/2`, `complete_op/2`).

### Logger Metadata Threading

- **D-45:** Ship **both** APIs from ARCHITECTURE.md §12:
  - `Kiln.Logger.Metadata.with_metadata/2` — block-style decorator for synchronous code paths.
  - `Kiln.Telemetry.pack_ctx/0` + `Kiln.Telemetry.unpack_ctx/1` — explicit pack/unpack for cross-process boundaries (`Task.async_stream`, Oban job enqueue/perform).
- **D-46:** Mandatory metadata keys on every log line: `correlation_id`, `causation_id`, `actor`, `actor_role`, `run_id`, `stage_id`. Missing keys default to the atom `:none` (not `nil` — surfaces missing-context bugs immediately).
- **D-47:** Phase 1 ships a **contrived multi-process test** proving metadata threads across `Task.async_stream` and Oban job boundaries (success criterion #3). Test uses `ExUnit.CaptureLog` + JSON parse to assert the metadata appears on log lines emitted from each spawned process.

### Migration & DB Roles

- **D-48:** Two Postgres roles in v1: `kiln_owner` (owns tables, runs migrations, full DDL/DML) and `kiln_app` (runtime, INSERT/SELECT on `audit_events`, full DML on other tables). Single Postgres instance (no read replica). `config/runtime.exs` selects role via `KILN_DB_ROLE` env var (defaults to `kiln_app`); migrations run via `mix ecto.migrate` use `KILN_DB_ROLE=kiln_owner`.
- **D-49:** Oban migrations sequenced by Kiln-owned migrations: a dedicated `priv/repo/migrations/0000XX_install_oban.exs` invokes `Oban.Migration.up(version: <pinned>)`. Pin Oban migration version explicitly (don't auto-up to latest).

### Spec Upgrades to Apply Inside Phase 1's Implementation

These are not new decisions — they are corrections to existing planning docs that Phase 1 must apply before downstream phases inherit broken assumptions:

- **D-50:** Update **CLAUDE.md** Conventions section: change `"INSERT-only is enforced at the DB level via CREATE RULE … DO INSTEAD NOTHING"` → `"INSERT-only is enforced via REVOKE + BEFORE trigger + CREATE RULE (defense in depth — see 01-CONTEXT.md D-12)"`.
- **D-51:** Update **ARCHITECTURE.md §9**: rename the table referenced as `events` → `audit_events` to match CLAUDE.md and Phase 1 success criterion #4. Re-verify all SQL examples in §9 use the corrected name.
- **D-52:** Update **STACK.md**: add `pg_uuidv7` Postgres extension to the Postgres 16 install notes (referenced for `audit_events` and `external_operations` PKs); document the PG18 migration to native `uuidv7()`.
- **D-53:** Update **PROJECT.md** Constraints line: change `"Elixir 1.18+/OTP 27+"` → `"Elixir 1.19.5+/OTP 28.1+"` (STACK.md research already flagged this drift; resolving in P1 prevents new drift).

### Claude's Discretion

The planner and executor have flexibility on:

- Exact module file names within each context's directory (follow ARCHITECTURE.md §15 layout).
- `mix.exs` aliases composition (`mix setup`, `mix check`, etc.) — must be idempotent on re-run.
- README structure beyond ensuring it documents the four-step first-run UX (`cp .env.sample .env && docker compose up -d && mix setup && mix phx.server`).
- CHANGELOG.md format (Keep a Changelog convention recommended).
- Test fixtures structure under `test/support/`.
- Whether `Kiln.HealthPlug` lives in `lib/kiln_web/plugs/` or `lib/kiln_web/health/` — local taste.
- Specific `description:` text in custom Credo checks.
- Exact wording of the operator-facing error message in trigger `RAISE EXCEPTION` (must include "audit_events is append-only" substring for test assertion).
- Whether to use Phoenix-generated tailwind config or a hand-rolled minimal one (deferred brand-book theme work to P7 either way).

### Folded Todos

None — STATE.md "Pending Todos" was empty at discussion time.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Project spec & vision
- `CLAUDE.md` — project conventions, brand contract, tech stack baseline, anti-patterns. **NOTE: Phase 1 implementation must apply spec-upgrade D-50 before downstream phases inherit it.**
- `.planning/PROJECT.md` — vision, constraints, key decisions, out-of-scope list. **NOTE: D-53 corrects the Elixir/OTP version line.**
- `.planning/REQUIREMENTS.md` — Phase 1 maps to requirements **LOCAL-01, LOCAL-02, OBS-01, OBS-03**.
- `.planning/ROADMAP.md` Phase 1 entry — goal, success criteria, artifacts, pitfalls addressed.
- `.planning/STATE.md` — session continuity.

### Stack & architecture research
- `.planning/research/STACK.md` — locked versions, `mix.exs` deps excerpt, `docker-compose.yml` reference, secret management, `.tool-versions`, GitHub Actions skeleton. **NOTE: D-52 adds `pg_uuidv7` extension.**
- `.planning/research/ARCHITECTURE.md` §3 (single Phoenix app, no umbrella), §9 (Event Ledger & Idempotency — **D-51 renames `events` → `audit_events`**), §10 (Sandbox Interface — informs DTU placeholder), §11 (LiveView Patterns — informs `/health` + LiveDashboard placement), §12 (Telemetry & Observability — logger metadata threading API), §15 (Project Directory Structure — file layout).
- `.planning/research/PITFALLS.md` — focus on **P9** (Oban defaults: `max_attempts: 3`), **P11** (GenServer overuse — Credo check D-24), **P12** (unsupervised processes — supervision tree review in CI), **P14** (N+1 — Ecto preload discipline), **P15** (compile-time secrets — Credo + custom Mix task D-26), **P17** (OTel context loss across Oban — `opentelemetry_process_propagator`).
- `.planning/research/SUMMARY.md` — high-level architectural narrative.
- `.planning/research/FEATURES.md` — feature inventory and dependency graph.
- `.planning/research/BEADS.md` — work-unit-store rationale (Option A — native Ecto + PubSub; informs P4 but P1 should not block it).

### Brand & UI contract (Phase 1 must not bake in conflicting defaults)
- `prompts/kiln-brand-book.md` — full brand contract (Inter + IBM Plex Mono, coal/char/iron/bone/ash/ember palette, borders over shadows, operator microcopy). Phase 1 doesn't apply the brand book to LV (that's Phase 7), but should not introduce defaults that conflict (e.g., default daisyUI theme is fine; cyberpunk neon would not be).

### Best-practices reference (consumed during research, retain for executor cross-checks)
- `prompts/elixir-best-practices-deep-research.md`
- `prompts/phoenix-best-practices-deep-research.md`
- `prompts/phoenix-live-view-best-practices-deep-research.md`
- `prompts/ecto-best-practices-deep-research.md`
- `prompts/elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md`
- `prompts/dark_software_factory_context_window.md` — four-layer model.

### External canonical references discovered during discussion
- Brandur, ["Implementing Stripe-like Idempotency Keys in Postgres"](https://brandur.org/idempotency-keys) — canonical reference for `external_operations` design (informs D-14, D-15, D-18).
- Brandur, [`rocket-rides-atomic`](https://github.com/brandur/rocket-rides-atomic) — reference implementation.
- [`pg_uuidv7` Postgres extension](https://github.com/fboulnois/pg_uuidv7) (D-06).
- [kjmph PL/pgSQL UUID v7 fallback](https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74) — pure-SQL alternative if extension can't be installed.
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) (D-03).
- [Oban Web installation](https://hexdocs.pm/oban_web/installation.html) (D-02).
- [jola.dev — "Health checks for Plug and Phoenix"](https://jola.dev/posts/health-checks-for-plug-and-phoenix) (D-31).
- [Plausible SECRET_KEY_BASE boot validation issue](https://github.com/plausible/analytics/issues/1105) — pattern for D-32.
- [ex_check](https://hexdocs.pm/ex_check/Mix.Tasks.Check.html) (D-22).
- [credo_envvar](https://hex.pm/packages/credo_envvar) (D-23).
- [ex_slop](https://hex.pm/packages/ex_slop) (D-23).
- [Credo: Adding Custom Checks](https://hexdocs.pm/credo/adding_checks.html) (D-24).
- [PostgreSQL Rules — silent-bypass discussion](https://medium.com/@caring_smitten_gerbil_914/why-you-should-avoid-postgresql-rules-and-use-triggers-instead-593e481bd16d) — rationale for D-12 defense-in-depth.
- [Carbonite (bitcrowd) — Elixir audit-trail library](https://github.com/bitcrowd/carbonite) — comparable reference architecture.

</canonical_refs>

<code_context>
## Existing Code Insights

**No existing application code.** Phase 1 is the first phase that produces Elixir/Phoenix source. The repo currently contains only:

- `prompts/` — research and brand-book inputs
- `.planning/` — planning artifacts (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md, research/, this CONTEXT.md)
- `CLAUDE.md` — project instructions

### Reusable Assets
- None.

### Established Patterns
- Planning docs use the GSD workflow conventions; researcher and planner outputs read these.
- Brand contract is locked in `prompts/kiln-brand-book.md` even though Phase 1 doesn't apply it.

### Integration Points
- This phase ESTABLISHES the integration points (supervision tree, Oban, Ecto, telemetry, audit, external_operations) that every subsequent phase plugs into.
- `priv/workflows/` directory deferred entirely to Phase 2; no `.gitkeep` in P1.
- `priv/mocks/` directory (DTU fixtures) deferred entirely to Phase 3; no `.gitkeep` in P1.

</code_context>

<specifics>
## Specific Ideas

- **"Kiln engineer needs operator dashboards during the build itself"** — `LiveDashboard` and `Oban Web` mounted in P1 isn't UI work, it's *operator-during-build-time UX*. The engineer building Phase 2's workflow engine needs to *see* Oban job retries visually, not query `oban_jobs` raw.
- **"Fail loudly when invariants are violated" applies at boot, not just in CI** — `Kiln.BootChecks` operationalizes Phase 1's stated principle. A fresh clone that boots successfully has, by definition, satisfied the durability-floor invariants. CI catches drift; boot catches misconfiguration. Both layers.
- **Brand-book deferral is the easy direction** — adding fonts/palette/components on top of a working tailwind pipeline at P7 is a CSS swap. The reverse (no pipeline → pipeline + brand in one phase) compounds risk. Phase 1 carries the asset cost so Phase 7 can be pure design work.
- **Phase 7's UI-05 audit ledger filter UI is the design driver for `audit_events` indexes** — the schema is correct *because* it makes Phase 7's query patterns trivial.
- **Solo engineer + public repo means CI is the second pair of eyes** — Option B's custom Credo checks shift CLAUDE.md anti-pattern enforcement from "reviewer discipline" (which has no second reviewer in solo mode) to "build break". The two AST-trivial checks are the right cost/value point.
- **Lock the event taxonomy at P1, even for kinds that don't fire until P5** — adding to a CHECK constraint mid-project requires a transactional migration; the kinds list is *cheap* to maintain when defined upfront and *expensive* to evolve incrementally under load.
- **Brandur's Stripe pattern is the right reference for `external_operations`, not Temporal** — Kiln has ~10 ops/run, not 10k; the unifying primitive is the *idempotency-key pattern*, not workflow durability (Oban handles that).

</specifics>

<deferred>
## Deferred Ideas

### From this discussion (out-of-scope for Phase 1)

- **Kubernetes-style `/healthz` + `/readyz` split** — out of scope per PROJECT.md (no hosted cloud runtime); single `/health` endpoint suffices for solo + LV factory header.
- **`pg_partman` partitioning of `audit_events`** — revisit when row count crosses 5M (years away at projected baseline).
- **GIN index on `audit_events.payload`** — defer until Phase 7 declares payload-deep filter UX needs.
- **Postgres 17 in CI matrix** — defer; revisit if Ecto/Postgrex ship 17-specific behaviors that need verification.
- **Lefthook pre-commit hook** — defer (or never); documented bypass habit defeats the purpose.
- **Custom Credo checks needing flow analysis** (`NoStatelessGenServer`, `NoUnsupervisedSpawn`, `NoApplyHotPath`, `BooleanObsession`) — defer; revisit if Credo gains flow-analysis primitives or if a third-party check ships.
- **Kiln-branded `mix kiln.check` wrapper** — defer; ex_check default output is operator-readable.
- **`pg_jsonschema` Postgres extension** — defer indefinitely; JSV at the app boundary covers v1's needs at lower cost.
- **GitHub `Dependabot` / `Renovate` config** — defer to Phase 9 release-prep work (mix_audit covers the security path in v1).
- **OTel `opentelemetry_process_propagator` wiring** — Phase 9 owns the OTel completeness work; Phase 1 stops at structured JSON logging + telemetry hooks.

### Future-work seed (raised by operator during discussion, **2026-04-18**)

The operator surfaced a meta-concern about **how Kiln self-evaluates and self-improves** — directly relevant to v2 / a follow-on milestone, not Phase 1. Captured verbatim so it isn't lost:

> "How do we judge the quality of the software output? Do we have some kind of recording (event sourced/event audit/log history) so we have a record of how runs of building software go? How will we be able to effectively iterate on Kiln itself? Do we need metrics/telemetry, record of how things went? Examples of real software. Ideally Kiln can iterate on itself — get good data along with subjective user feedback (from me mostly) so we can take lessons learned and add new features or tighten how things work. After v1 ships, when I try to use Kiln to build software, how can I evaluate how it went and effectively bring that info back into Kiln, ideally with some kind of record of how things went so we can do an analysis and figure out what could be done better — in that case and the general case of building any software — to optimize efficiency (wall time AND tokens) and pick more effective models. How do we bring in new models as they come out as options?"

Concrete sub-themes to address in a future milestone (suggested name: **"Self-Evaluation Loop"**, post-v1, possibly a v1.5 milestone before the v2 multi-tenant work):

1. **Run post-mortem record** — every shipped run emits a structured artifact: token usage by stage/agent/role, wall time, retry counts, model breakdown (`requested_model` vs `actual_model_used` already in P3), scenario-runner verdict trail, every BLOCK reason hit, every escalation, every checkpoint resume. Stored in a `run_postmortems` table or as a typed artifact file.
2. **Operator subjective rating** — after each merged run, operator prompted for 1–5 satisfaction + free-text "what went wrong / right" — stored alongside the run.
3. **Aggregated insights view** — "Across the last N runs, the Coder role on `phoenix_saas_feature` profile averaged X tokens / $Y / Z minutes; switching to model M would have saved A%, dropped scenario pass rate by B%."
4. **Spec-to-result quality scoring** — scenario pass rate is the deterministic floor (already in P5); LLM-judge can layer subjective scoring per run ("did the produced PR feel idiomatic / well-tested / well-documented") with the LLM-judge result advisory only, never overriding the scenario verdict.
5. **Model bake-off workflow** — when a new Anthropic / OpenAI / Google model ships, a "model bake-off" workflow runs the same canned spec against old vs new, compares cost + latency + scenario pass rate, recommends profile updates. Closes the loop on OPS-02/03 over time.
6. **Kiln-builds-Kiln dogfood feedback loop** — each Kiln self-run produces a "Kiln-on-Kiln learnings" artifact that informs the next Kiln spec. (Phase 9 dogfoods once; the *loop* is future work.)
7. **External signal capture** — post-merge GitHub Actions outcomes, real-world bug reports filed against produced PRs (INTAKE-03 "File as follow-up" is the entry point), runtime telemetry of shipped code if Kiln has access.

**Recommended capture mechanism** (see end of CONTEXT.md):
- Add as a v2 / v1.5 requirement cluster in `.planning/REQUIREMENTS.md` under a new section "Self-Evaluation & Continuous Improvement (v1.5 / v2)" — so it doesn't get rediscovered.
- Plant a seed via `gsd-plant-seed` triggered to surface at "Phase 9 verification" or "v1 release prep" so it's actively raised at the right milestone, not buried.

**Captured (2026-04-18):** Both capture mechanisms executed — `REQUIREMENTS.md § Self-Evaluation & Continuous Improvement (v1.5)` now carries `SELF-01..07` + `FEEDBACK-01`; `.planning/seeds/SEED-001-operator-feedback-loop.md` planted with trigger "Phase 9 verification / v1 release prep". Separately, a backlog item `999.1-docs-landing-site` was created for a future docs + landing site (slot decision — new Phase 10 inside v0.1.0 vs v1.1 milestone post-tag — deferred to late Phase 8 / early Phase 9). See `ROADMAP.md § Backlog` and `REQUIREMENTS.md § Docs & Release (v1.0+)` for `DOCS-01..07`.

This is **NOT** Phase 1 scope. Captured here so it survives the discuss → plan → execute hand-off without scope creep into the durability floor.

</deferred>

---

*Phase: 01-foundation-durability-floor*
*Context gathered: 2026-04-18*
