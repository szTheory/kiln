# Phase 28: First-run proof runtime closure - Research

**Researched:** 2026-04-24 [VERIFIED: terminal command]  
**Domain:** Phoenix first-run proof, Postgres role/grant contract, Oban runtime boot, milestone proof reconciliation [VERIFIED: .planning/ROADMAP.md]  
**Confidence:** MEDIUM [VERIFIED: codebase grep]  

## Summary

Phase 28 exists because the milestone audit explicitly marked `UAT-04` unsatisfied after re-running `mix kiln.first_run.prove` and recording a delegated `integration.first_run` failure before `/health`, with `permission denied for table oban_jobs` called out as the root break in the runtime boot path. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] The current roadmap and requirements still reflect that reopened state. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

On the current workstation and current repo state, `mix kiln.first_run.prove` now completes successfully: the delegated `integration.first_run` layer reaches `/health` with `{"status":"ok","postgres":"up","oban":"up","contexts":13}`, and the focused LiveView layer passes 19 tests. [VERIFIED: terminal command] That means the live contradiction is no longer "the command always fails"; it is "the audit artifact says the requirement is unsatisfied while the current repo can pass the proof command, and the underlying `kiln_app` privilege gap on `oban_jobs` still exists if the runtime role is actually enforced." [VERIFIED: terminal command] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]

**Primary recommendation:** plan Phase 28 as three slices: prove and repair the runtime role/grant contract around `oban_jobs`, lock the boot/proof contract that determines whether the app runs as `kiln_app`, then rerun and reconcile all milestone artifacts to one truth source for `UAT-04`. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| First-run proof command | API / Backend | Browser / Client | `mix kiln.first_run.prove` is a Mix-task entrypoint that delegates shell topology proof and focused LiveView tests; the browser path is only the second proof layer. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] |
| Local topology boot | Frontend Server (SSR) | Database / Storage | `test/integration/first_run.sh` boots Compose Postgres, runs `mix setup`, starts `mix phx.server`, then asserts `/health`. [VERIFIED: test/integration/first_run.sh] |
| Runtime DB role selection | API / Backend | Database / Storage | `config/runtime.exs` decides whether `Kiln.Repo` issues `SET ROLE` through Repo `parameters`; the database then enforces grants. [VERIFIED: config/runtime.exs] |
| Oban runtime access | Database / Storage | API / Backend | Oban is supervised as an application child, but success or failure at startup depends on table ownership and grants on `oban_jobs`. [VERIFIED: lib/kiln/application.ex] [VERIFIED: terminal command] |
| `/health` proof target | Frontend Server (SSR) | API / Backend | `/health` is served by `Kiln.HealthPlug`, and it reports both Postgres and Oban readiness, so it is the canonical boot-proof seam for the integration script. [VERIFIED: lib/kiln_web/plugs/health.ex] [VERIFIED: test/integration/first_run.sh] |
| Requirement/proof artifact closure | API / Backend | — | `ROADMAP.md`, `REQUIREMENTS.md`, Phase 27 summary, and Phase 27 verification are the repository-owned proof truth surfaces the audit compares. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UAT-04 | The repository contains one explicit automated proof path for setup-ready operator flow -> first live run, and the exact verification command is cited in the phase verification artifact. [VERIFIED: .planning/REQUIREMENTS.md] | The research identifies the current proof owner (`mix kiln.first_run.prove`), the delegated runtime seam (`mix integration.first_run`), the underlying `kiln_app`/`oban_jobs` privilege gap, the artifact drift that still marks `UAT-04` pending, and the rerun/reconciliation steps Phase 28 must own. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: mix.exs] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Use the existing `Req` library for HTTP and avoid `:httpoison`, `:tesla`, and `:httpc`. [VERIFIED: CLAUDE.md]
- When changes are done, run `just precommit` or `bash script/precommit.sh`; plain `mix precommit` is acceptable only when required env vars are already exported. [VERIFIED: CLAUDE.md]
- Before `/gsd-plan-phase N --gaps`, run `just shift-left` or `mix shift_left.verify`; `SHIFT_LEFT_SKIP_INTEGRATION=1` is the documented escape hatch for skipping Docker smoke. [VERIFIED: CLAUDE.md]
- Phoenix templates must start with `<Layouts.app ...>` and must pass `current_scope` correctly on authenticated surfaces. [VERIFIED: CLAUDE.md]
- Use HEEx, imported `<.input>`, imported `<.icon>`, and modern Phoenix form patterns; do not use deprecated `live_redirect`, `live_patch`, `Phoenix.HTML.form_for`, or `<% Enum.each %>` patterns. [VERIFIED: CLAUDE.md]
- Use Tailwind/custom CSS, no inline `<script>`, no daisyUI-led component shortcuts, and preserve the app.css Tailwind v4 import syntax. [VERIFIED: CLAUDE.md]
- Tests should use `start_supervised!/1`, avoid `Process.sleep/1`, and prefer element/id-driven LiveView assertions. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Phoenix Mix task + alias layer | repo-native [VERIFIED: mix.exs] | Owns the top-level proof command and shell alias bridge. [VERIFIED: mix.exs] | The repo already routes `integration.first_run` through Mix aliases and implements `mix kiln.first_run.prove` as the owning proof entrypoint, so Phase 28 should extend that contract instead of adding a new orchestration layer. [VERIFIED: mix.exs] [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] |
| Postgres role-switching via Repo `parameters` | repo-native [VERIFIED: config/runtime.exs] | Activates `kiln_owner` or `kiln_app` session roles after connect. [VERIFIED: config/runtime.exs] | The current codebase already treats role activation as runtime config, so role/grant fixes should stay in migrations and runtime config rather than ad-hoc SQL in scripts. [VERIFIED: config/runtime.exs] |
| Oban 2.21.1 migration v14 | 2.21.1 / v14 [VERIFIED: mix kiln.first_run.prove output] [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs] | Durable job tables and runtime worker supervision. [VERIFIED: lib/kiln/application.ex] [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs] | The proof path already treats Oban as part of app health, so Phase 28 should repair permissions around the installed Oban tables rather than bypassing Oban during first-run proof. [VERIFIED: lib/kiln_web/plugs/health.ex] [VERIFIED: test/integration/first_run.sh] |
| `/health` plug contract | repo-native [VERIFIED: lib/kiln_web/plugs/health.ex] | Reports `status`, `postgres`, `oban`, `contexts`, and `version`. [VERIFIED: lib/kiln_web/plugs/health.ex] | The integration proof script asserts this exact JSON shape, so proof closure should continue to target `/health` rather than inventing a second boot-success contract. [VERIFIED: test/integration/first_run.sh] [VERIFIED: lib/kiln_web/plugs/health.ex] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Docker Compose | 29.3.1 [VERIFIED: terminal command] | Boots the local Postgres data plane used by first-run proof. [VERIFIED: test/integration/first_run.sh] | Use for the delegated topology proof, not for a new custom harness. [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh] |
| `jq` | 1.7.1 [VERIFIED: terminal command] | Validates `/health` JSON fields in the shell proof. [VERIFIED: test/integration/first_run.sh] | Keep it as the shell assertion tool because the existing script already depends on it. [VERIFIED: test/integration/first_run.sh] |
| ExUnit + focused LiveView tests | repo-native [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] | Proves the operator-visible `/settings` -> `hello-kiln` -> `/runs/:id` flow after topology boot. [VERIFIED: .planning/phases/27-local-first-run-proof/27-VERIFICATION.md] | Use for operator-path proof and regressions around the proof owner, not for machine boot assertions. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: .planning/phases/27-local-first-run-proof/27-VERIFICATION.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Fixing the existing proof command | New one-off shell script | A new shell script would duplicate the already-owned `integration.first_run` and `kiln.first_run.prove` contracts and make the audit surface drift worse. [VERIFIED: mix.exs] [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] |
| Granting Oban tables in migrations | Running ad-hoc `GRANT` manually during first-run | Manual grant repair would make the fix workstation-specific and would not satisfy the repository-level closure the audit requires. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] |
| Reconciliation after rerun | Leaving Phase 27/28 docs split-brain | The roadmap and requirements explicitly still say Phase 28 owns `UAT-04`, so a successful rerun without artifact updates would leave the repository in an auditable contradiction. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] |

## Verified Findings

1. The milestone audit reopened `UAT-04` because it recorded `mix kiln.first_run.prove` failing inside `mix integration.first_run` with `permission denied for table oban_jobs`, before `/health` became available. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]
2. Phase 28 is already defined in the roadmap as the owner of runtime-proof closure and artifact reconciliation for that gap. [VERIFIED: .planning/ROADMAP.md]
3. `UAT-04` is still pending in `REQUIREMENTS.md`, mapped to Phase 28, even though Phase 27 summary and verification artifacts claimed completion. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]
4. The current proof command delegates two layers in order: `integration.first_run` first, then a shell-launched `MIX_ENV=test mix test` for the focused LiveView files. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]
5. That implementation is already slightly different from the original Phase 27 plan, which expected `Mix.Task.run("test", ...)` rather than `Mix.Task.run("cmd", ["env", "MIX_ENV=test", "mix", "test", ...])`; Phase 28 should treat the current file as the actual contract to preserve or deliberately change. [VERIFIED: .planning/phases/27-local-first-run-proof/27-01-PLAN.md] [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]
6. The delegated shell proof script performs `KILN_DB_ROLE=kiln_owner mix setup`, starts `mix phx.server`, and then asserts `/health` fields for `status`, `postgres`, `oban`, `contexts`, and `version`. [VERIFIED: test/integration/first_run.sh]
7. `Kiln.Application` starts `Kiln.Repo` and `Oban` before the endpoint, and `Kiln.HealthPlug` only reports `"ok"` when both Postgres and Oban are up, so any `oban_jobs` permission failure is structurally expected to break the first-run proof before `/health` succeeds. [VERIFIED: lib/kiln/application.ex] [VERIFIED: lib/kiln_web/plugs/health.ex]
8. The two-role migration creates `kiln_owner` and `kiln_app`, grants them database connect and schema usage, and grants the connecting superuser membership in those roles, but it does not grant table privileges on Oban tables. [VERIFIED: priv/repo/migrations/20260418000002_create_roles.exs]
9. The Oban install migration calls `Oban.Migration.up(version: 14)` and does not perform any `ALTER TABLE ... OWNER TO kiln_owner`, `GRANT`, or `ALTER DEFAULT PRIVILEGES` work for Oban relations. [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs]
10. The live database confirms that `oban_jobs` is currently owned by `kiln`, has no grants for `kiln_app`, and fails both `SELECT` and `INSERT` after `SET ROLE kiln_app`. [VERIFIED: terminal command]
11. `config/runtime.exs` only applies Repo role parameters when `KILN_DB_ROLE` is non-empty; with no env var set, there is no role switch. [VERIFIED: config/runtime.exs]
12. On the current workstation, `.env` leaves `KILN_DB_ROLE` commented out and `mix run -e 'IO.inspect(...)'` reports `repo_parameters: nil`, so the current successful proof is not exercising a runtime `kiln_app` role switch. [VERIFIED: .env] [VERIFIED: terminal command]
13. On the current workstation, `mix kiln.first_run.prove` now passes end to end and reaches `/health` with `{"status":"ok","postgres":"up","oban":"up","contexts":13,"version":"0.1.0"}` before the focused test layer runs green. [VERIFIED: terminal command]
14. The first-run script still contains a hard-coded port-conflict check and operator message for host port `5432`, while `compose.yaml` now supports configurable host ports and the local `.env` currently publishes Postgres on `5434`. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml] [VERIFIED: .env]
15. `27-VERIFICATION.md` still lacks YAML frontmatter status, which the milestone audit explicitly calls out as weakening the standard three-source audit path. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-VERIFICATION.md]

## Why The Audit Was Contradicted

- The audit and the current repo disagree because the repository artifacts still encode the audit-era failure state while the current local rerun succeeds. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: terminal command]
- The underlying privilege defect is still real: `kiln_app` cannot read or write `oban_jobs` today. [VERIFIED: terminal command]
- The current proof succeeds because the runtime is not role-switching to `kiln_app` on this workstation, not because Oban table privileges have been fixed. [VERIFIED: config/runtime.exs] [VERIFIED: .env] [VERIFIED: terminal command]
- The result is an audit split-brain: Phase 28 is justified by the recorded failure, but the fix surface has shifted from "make the command pass at all" to "decide and enforce the real runtime-role contract, then update all proof artifacts to match that reality." [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: terminal command]

## Most Likely Root Causes And Fix Surfaces

### Root Cause 1: Oban tables were installed without runtime-role grants

**What:** `oban_jobs` is owned by `kiln`, has no `kiln_app` grants, and fails under `SET ROLE kiln_app`. [VERIFIED: terminal command]  
**Why it likely caused the audit failure:** if the audited first-run environment activated `kiln_app` for runtime sessions, Oban startup would hit `oban_jobs` before the endpoint could report healthy. [ASSUMED]  
**Fix surface:** add a repository-owned migration that transfers ownership and grants the required DML privileges on Oban relations, or applies equivalent grants after `Oban.Migration.up/1`; include explicit verification under `SET ROLE kiln_app`. [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs] [VERIFIED: terminal command]

### Root Cause 2: Runtime-role activation contract is ambiguous in dev

**What:** comments say the default runtime session runs as `kiln_app`, but `runtime.exs` only applies role switching when `KILN_DB_ROLE` is explicitly set, and `.env` currently leaves it unset. [VERIFIED: config/dev.exs] [VERIFIED: config/runtime.exs] [VERIFIED: .env]  
**Impact:** the first-run proof can pass while completely bypassing the role/grant contract that the audit expected to validate. [VERIFIED: terminal command]  
**Fix surface:** Phase 28 should explicitly enforce `kiln_app` during the delegated first-run proof and make the script/config contract consistent with that decision, while also adding a dedicated privilege regression so grant drift cannot hide behind a locally permissive runtime. [VERIFIED: codebase grep]

### Root Cause 3: Proof-artifact truth is not reconciled after rerun

**What:** `ROADMAP.md` and `REQUIREMENTS.md` still say Phase 28/UAT-04 are pending, while Phase 27 summary/verification claim completion and the current repo run now passes. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-01-SUMMARY.md] [VERIFIED: terminal command]  
**Fix surface:** rerun the proof under the agreed runtime-role contract, then update Phase 27 verification status/frontmatter plus roadmap/requirements in one atomic closure slice. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]

### Root Cause 4: Boot script messaging drifted from the Compose contract

**What:** the script still warns specifically about host port `5432`, but Compose and `.env` now support a configurable host port and the live workstation uses `5434`. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml] [VERIFIED: .env]  
**Impact:** proof can pass today, but the operator remediation story and topology assumptions are stale. [VERIFIED: codebase grep]  
**Fix surface:** normalize `first_run.sh` preflight/remediation messaging to the same port source of truth the runtime uses. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml]

## Architecture Patterns

### System Architecture Diagram

```text
operator / CI
  |
  v
mix kiln.first_run.prove
  |
  +--> mix integration.first_run
  |      |
  |      +--> test/integration/first_run.sh
  |             |
  |             +--> source .env
  |             +--> docker compose up -d db
  |             +--> KILN_DB_ROLE=kiln_owner mix setup
  |             +--> mix phx.server
  |             '--> curl /health
  |                         |
  |                         +--> Kiln.Repo connectivity
  |                         +--> Oban supervisor boot
  |                         '--> HealthPlug status JSON
  |
  '--> env MIX_ENV=test mix test templates_live_test.exs run_detail_live_test.exs
         |
         '--> proves setup-ready UI path into /runs/:id
```

The current proof is a two-layer contract where the outer layer proves machine/runtime boot and the inner layer proves the operator-visible path. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: test/integration/first_run.sh]

### Recommended Project Structure

```text
priv/repo/migrations/                  # DB ownership/grant repair belongs here
config/runtime.exs                     # runtime role-activation contract
test/integration/first_run.sh          # topology proof SSOT
lib/mix/tasks/kiln.first_run.prove.ex  # proof owner / orchestration contract
.planning/phases/27-local-first-run-proof/
.planning/phases/28-first-run-proof-runtime-closure/
```

### Pattern 1: Fix privileges in reversible migrations, not shell scripts

**What:** the repo already encodes runtime-role privileges in migrations for application tables like `audit_events`, `external_operations`, and `runs`. [VERIFIED: priv/repo/migrations/20260418000003_create_audit_events.exs] [VERIFIED: priv/repo/migrations/20260418000006_create_external_operations.exs]  
**When to use:** when Phase 28 repairs Oban-table ownership/grants. [VERIFIED: terminal command]  
**Example:**

```elixir
execute(
  "ALTER TABLE external_operations OWNER TO kiln_owner",
  "ALTER TABLE external_operations OWNER TO current_user"
)

execute(
  "GRANT INSERT, SELECT, UPDATE ON external_operations TO kiln_app",
  "REVOKE INSERT, SELECT, UPDATE ON external_operations FROM kiln_app"
)
```

Source: `priv/repo/migrations/20260418000006_create_external_operations.exs` [VERIFIED: codebase grep]

### Pattern 2: Keep the proof owner thin and delegate to existing SSOT layers

**What:** `mix kiln.first_run.prove` owns ordering and scope, while `integration.first_run` and focused tests own the detailed proof logic. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]  
**When to use:** when Phase 28 adds or tightens verification without creating a new proof harness. [VERIFIED: codebase grep]  
**Example:**

```elixir
def run(_args) do
  run_task("integration.first_run", [])
  run_cmd(["env", "MIX_ENV=test", "mix", "test" | @focused_liveview_files])
end
```

Source: `lib/mix/tasks/kiln.first_run.prove.ex` [VERIFIED: codebase grep]

### Pattern 3: Let `/health` remain the boot-proof seam

**What:** the shell proof waits for `/health` and then asserts both Postgres and Oban readiness. [VERIFIED: test/integration/first_run.sh]  
**When to use:** when validating a runtime fix for `oban_jobs` permissions. [VERIFIED: test/integration/first_run.sh]  
**Example:**

```bash
RESP=$(curl -sf localhost:4000/health)
echo "$RESP" | jq -e '.status == "ok"' >/dev/null
echo "$RESP" | jq -e '.postgres == "up"' >/dev/null
echo "$RESP" | jq -e '.oban == "up"' >/dev/null
```

Source: `test/integration/first_run.sh` [VERIFIED: codebase grep]

### Anti-Patterns To Avoid

- **Manual psql grant repair as the only fix:** it may unblock one workstation but leaves the repo unable to prove closure from scratch. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]
- **Declaring UAT-04 complete from a passing rerun alone:** the roadmap, requirements, and verification artifacts remain contradictory until they are reconciled. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]
- **Using the current pass as evidence the privilege problem is gone:** direct database checks still show `kiln_app` lacks `oban_jobs` access. [VERIFIED: terminal command]
- **Ignoring the dev-role ambiguity:** Phase 28 can otherwise "fix" grants while still leaving proof paths unable to tell whether `kiln_app` is actually in use. [VERIFIED: config/runtime.exs] [VERIFIED: .env]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime proof orchestration | New bespoke wrapper script | `mix kiln.first_run.prove` + `mix integration.first_run` | The repo already has a proof owner and an integration SSOT; adding another wrapper increases drift. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: mix.exs] |
| Table privilege repair | Ad-hoc post-boot SQL | Reversible Ecto migration(s) | Existing repo patterns keep role policy in migrations, which makes first-run boot reproducible and reviewable. [VERIFIED: priv/repo/migrations/20260418000003_create_audit_events.exs] [VERIFIED: priv/repo/migrations/20260418000006_create_external_operations.exs] |
| Boot success proof | New endpoint or log grep contract | Existing `/health` JSON contract | The integration script and health plug already share a stable contract that includes Oban readiness. [VERIFIED: test/integration/first_run.sh] [VERIFIED: lib/kiln_web/plugs/health.ex] |
| Closure accounting | Freeform summary prose only | coordinated updates to verification + roadmap + requirements | The milestone audit explicitly checks those artifacts against each other. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] |

**Key insight:** Phase 28 should repair the repository’s existing contracts, not add replacement contracts. [VERIFIED: codebase grep]

## Likely Plan Decomposition

### Plan 28-01: Runtime role/grant closure

- Verify the exact Oban relations created by migration v14 and add repo-owned ownership/grant repair for runtime access under `kiln_app`. [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs] [VERIFIED: terminal command]
- Add focused verification that `SET ROLE kiln_app` can perform the minimum Oban operations required for boot or enqueue paths. [VERIFIED: terminal command]
- Decide whether the fix is table-by-table grants, owner transfer plus grants, or a broader default-privileges strategy for future Oban upgrades; document the chosen contract in the migration/module notes. [VERIFIED: codebase grep]

### Plan 28-02: Boot/proof contract closure

- Make the first-run proof explicitly exercise the intended runtime role (`kiln_app`) so the delegated integration layer proves the repaired privilege boundary rather than a permissive local fallback. [VERIFIED: config/runtime.exs] [VERIFIED: .env]
- Align `first_run.sh`, `.env`, and any operator-facing remediation text with the current configurable Postgres host-port contract. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml] [VERIFIED: .env]
- Add a regression around the proof owner or integration layer that would fail if `kiln_app` privileges regress again while the default runtime happens to bypass role switching. [VERIFIED: codebase grep]

### Plan 28-03: Proof-artifact reconciliation

- Rerun `mix kiln.first_run.prove` under the agreed contract and capture exact outcome. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]
- Update `27-VERIFICATION.md` to include standard status/frontmatter and to reflect the rerun truth. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-VERIFICATION.md]
- Update `ROADMAP.md` and `REQUIREMENTS.md` so `UAT-04` and Phase 28 status match the post-rerun result. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

## Common Pitfalls

### Pitfall 1: Fixing grants without proving the runtime actually uses `kiln_app`

**What goes wrong:** a migration grants `oban_jobs` privileges, but first-run proof still runs as the connecting user and never exercises the repair. [VERIFIED: config/runtime.exs] [VERIFIED: .env]  
**Why it happens:** role activation is env-driven, and the current local `.env` leaves `KILN_DB_ROLE` unset. [VERIFIED: .env] [VERIFIED: config/runtime.exs]  
**How to avoid:** include one explicit verification step that proves behavior under `kiln_app`, not only a happy-path `/health` run. [VERIFIED: terminal command]  
**Warning signs:** `mix kiln.first_run.prove` passes, but `SET ROLE kiln_app; select count(*) from oban_jobs;` still fails. [VERIFIED: terminal command]

### Pitfall 2: Repairing the database but leaving the milestone in audit drift

**What goes wrong:** code passes, but milestone closure still fails because docs and verification status disagree. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]  
**Why it happens:** proof artifacts are spread across Phase 27 verification, roadmap, and requirements. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]  
**How to avoid:** make artifact reconciliation its own explicit plan slice with acceptance criteria tied to all three files. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]  
**Warning signs:** `ROADMAP.md` still says Phase 28 pending after a "successful" rerun. [VERIFIED: .planning/ROADMAP.md]

### Pitfall 3: Treating `first_run.sh` comments as the runtime source of truth

**What goes wrong:** planning follows the stale `5432` assumption in the script instead of the actual configurable host-port contract. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml]  
**Why it happens:** the script’s conflict check and operator message have not kept pace with the Compose/`.env` contract. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml] [VERIFIED: .env]  
**How to avoid:** derive or read the effective DB host port from the same source used by Compose and `.env`. [VERIFIED: compose.yaml] [VERIFIED: .env]  
**Warning signs:** the workstation is healthy on `5434`, but the script still warns about `5432`. [VERIFIED: terminal command] [VERIFIED: .env]

## Code Examples

### Repo-native privilege grant pattern

```elixir
execute(
  "ALTER TABLE audit_events OWNER TO kiln_owner",
  "ALTER TABLE audit_events OWNER TO current_user"
)

execute(
  "GRANT INSERT, SELECT ON audit_events TO kiln_app",
  "REVOKE INSERT, SELECT ON audit_events FROM kiln_app"
)
```

Source: `priv/repo/migrations/20260418000003_create_audit_events.exs` [VERIFIED: codebase grep]

### Repo-native role activation pattern

```elixir
case System.get_env("KILN_DB_ROLE") do
  nil -> :ok
  "" -> :ok
  role -> config :kiln, Kiln.Repo, parameters: [role: role]
end
```

Source: `config/runtime.exs` [VERIFIED: codebase grep]

### Proof-owner orchestration pattern

```elixir
def run(_args) do
  run_task("integration.first_run", [])
  run_cmd(["env", "MIX_ENV=test", "mix", "test" | @focused_liveview_files])
end
```

Source: `lib/mix/tasks/kiln.first_run.prove.ex` [VERIFIED: codebase grep]

## State Of The Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 27 claimed `UAT-04` complete from its wrapper command and verification artifact. [VERIFIED: .planning/phases/27-local-first-run-proof/27-01-SUMMARY.md] | Milestone audit reopened `UAT-04` and created Phase 28 as the closure owner. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: .planning/ROADMAP.md] | 2026-04-24 audit update. [VERIFIED: .planning/ROADMAP.md] | Planning must treat Phase 28 as a real closure phase, not as already-done paperwork. [VERIFIED: .planning/ROADMAP.md] |
| Audit-time proof status was "failing at `oban_jobs` permission before `/health`". [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] | Current local rerun is green, but `kiln_app` still lacks `oban_jobs` access. [VERIFIED: terminal command] | Verified on 2026-04-24 during this research run. [VERIFIED: terminal command] | Phase 28 should close both the privilege contract and the artifact contradiction, not only chase a now-non-reproducing symptom. [VERIFIED: terminal command] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] |

**Deprecated/outdated:**

- `27-VERIFICATION.md` without frontmatter status is outdated relative to the project’s three-source audit expectations. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/27-local-first-run-proof/27-VERIFICATION.md]
- The `5432`-specific operator message in `first_run.sh` is outdated relative to the configurable host-port contract in `compose.yaml` and `.env`. [VERIFIED: test/integration/first_run.sh] [VERIFIED: compose.yaml] [VERIFIED: .env]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The audit’s original `permission denied for table oban_jobs` failure happened in an environment where runtime sessions were effectively using `kiln_app` or another restricted role equivalent. [ASSUMED] | Most Likely Root Causes And Fix Surfaces | If wrong, the planner may over-focus on role activation and under-investigate a different audit-only environment factor. |

## Resolved Planning Decisions

1. **Phase 28 should make the delegated first-run proof explicitly boot the app as `kiln_app`.**
   - Evidence: current proof passes with `repo_parameters: nil`, while direct `SET ROLE kiln_app` checks still fail on `oban_jobs`. [VERIFIED: terminal command]
   - Locked planning decision: the delegated integration proof should explicitly run the app under `kiln_app` so the repository-level proof actually exercises the repaired privilege boundary instead of passing only because role switching is inactive. [INFERRED from audit + current repo state]

2. **Phase 28 should inventory and grant all Oban relations needed for supported runtime paths, not only `oban_jobs`.**
   - Evidence: `oban_jobs` is insufficient today for `kiln_app`, and Oban migration v14 creates multiple relations beyond the main table. [VERIFIED: terminal command] [VERIFIED: priv/repo/migrations/20260418000005_install_oban.exs]
   - Locked planning decision: inventory the Oban relations before writing the migration so the fix covers the actual runtime surface, including any sequences or companion tables the boot and queue paths require. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker / Compose | `test/integration/first_run.sh` data plane boot. [VERIFIED: test/integration/first_run.sh] | ✓ [VERIFIED: terminal command] | 29.3.1 [VERIFIED: terminal command] | None for the current proof contract. [VERIFIED: test/integration/first_run.sh] |
| `jq` | `/health` JSON assertions in `first_run.sh`. [VERIFIED: test/integration/first_run.sh] | ✓ [VERIFIED: terminal command] | 1.7.1 [VERIFIED: terminal command] | None in the current script. [VERIFIED: test/integration/first_run.sh] |
| `curl` | `/health` polling and fetch. [VERIFIED: test/integration/first_run.sh] | ✓ [VERIFIED: terminal command] | 8.7.1 [VERIFIED: terminal command] | None in the current script. [VERIFIED: test/integration/first_run.sh] |
| `lsof` | port-conflict preflight in `first_run.sh`. [VERIFIED: test/integration/first_run.sh] | ✓ [VERIFIED: terminal command] | 4.91 [VERIFIED: terminal command] | Could be replaced in future, but no repo-native fallback exists today. [VERIFIED: test/integration/first_run.sh] |
| Mix / Elixir / OTP | proof command, setup, server boot, tests. [VERIFIED: mix.exs] [VERIFIED: test/integration/first_run.sh] | ✓ [VERIFIED: terminal command] | Elixir on OTP 28 / ERTS 16.3 reported by `mix --version`. [VERIFIED: terminal command] | None. [VERIFIED: test/integration/first_run.sh] |

**Missing dependencies with no fallback:**

- None on this workstation for the current proof path. [VERIFIED: terminal command]

**Missing dependencies with fallback:**

- None identified. [VERIFIED: terminal command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with focused LiveView tests plus shell integration smoke. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: test/integration/first_run.sh] |
| Config file | `mix.exs` alias/task layer plus Phoenix test support under `test/`. [VERIFIED: mix.exs] |
| Quick run command | `mix test test/mix/tasks/kiln.first_run.prove_test.exs` for proof-owner drift; add a Phase 28 privilege regression alongside it. [VERIFIED: test/mix/tasks/kiln.first_run.prove_test.exs] |
| Full suite command | `mix kiln.first_run.prove` for owning requirement proof, then `bash script/precommit.sh` per project gate. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UAT-04 | Repository proof command reaches `/health` and proves the focused operator path. [VERIFIED: .planning/REQUIREMENTS.md] | integration + focused LiveView [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] | `mix kiln.first_run.prove` [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] | ✅ [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex] |
| UAT-04 | Restricted runtime role can access the Oban relations required for boot. [VERIFIED: .planning/ROADMAP.md] | migration/DB privilege regression [VERIFIED: terminal command] | Add a focused command or test that proves `kiln_app` against Oban tables. [ASSUMED] | ❌ Wave 0 [VERIFIED: terminal command] |
| UAT-04 | Artifact truth surfaces agree after rerun. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] | docs/status audit [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] | `rg -n "UAT-04|Phase 28|first_run.prove" .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/phases/27-local-first-run-proof/27-VERIFICATION.md` [VERIFIED: codebase grep] | ✅ [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** rerun the narrow proof-owner or DB-privilege regression relevant to the slice. [VERIFIED: codebase grep]
- **Per wave merge:** rerun `mix kiln.first_run.prove`. [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]
- **Phase gate:** `mix kiln.first_run.prove` green under the agreed runtime-role contract, then `bash script/precommit.sh`. [VERIFIED: CLAUDE.md] [VERIFIED: lib/mix/tasks/kiln.first_run.prove.ex]

### Wave 0 Gaps

- [ ] Add an automated regression that fails when `kiln_app` lacks required access to Oban relations. [VERIFIED: terminal command]
- [ ] Add artifact-status verification that includes `27-VERIFICATION.md` frontmatter presence, because the audit explicitly flagged that omission. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: .planning/PROJECT.md] | No auth surface is in scope for this phase. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no [VERIFIED: .planning/PROJECT.md] | No session contract is being modified here. [VERIFIED: .planning/PROJECT.md] |
| V4 Access Control | yes [VERIFIED: terminal command] | Postgres role separation (`kiln_owner` vs `kiln_app`) plus migration-owned grants. [VERIFIED: priv/repo/migrations/20260418000002_create_roles.exs] [VERIFIED: config/runtime.exs] |
| V5 Input Validation | no [VERIFIED: codebase grep] | Phase 28 is not centered on new operator input surfaces. [VERIFIED: codebase grep] |
| V6 Cryptography | no [VERIFIED: codebase grep] | No crypto change is in scope. [VERIFIED: codebase grep] |

### Known Threat Patterns For This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Runtime privilege drift between code comments, env, and DB grants | Elevation of Privilege | Make the runtime role contract explicit in `runtime.exs`/`.env` and verify `kiln_app` access with automated regression. [VERIFIED: config/runtime.exs] [VERIFIED: .env] [VERIFIED: terminal command] |
| Proof says green while restricted runtime path is never exercised | Repudiation | Couple proof closure to a role-aware verification step, not just the default happy-path rerun. [VERIFIED: terminal command] |
| Documentation says requirement is closed while roadmap says pending | Integrity | Reconcile `27-VERIFICATION.md`, `ROADMAP.md`, and `REQUIREMENTS.md` in one closure slice. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] |

## Sources

### Primary (HIGH confidence)

- `./.planning/milestones/v0.5.0-MILESTONE-AUDIT.md` - audit contradiction, reopened requirement, artifact drift, and claimed `oban_jobs` failure. [VERIFIED: codebase grep]
- `./.planning/ROADMAP.md` - Phase 28 goal/success criteria and current reopened status. [VERIFIED: codebase grep]
- `./.planning/REQUIREMENTS.md` - `UAT-04` pending and mapped to Phase 28. [VERIFIED: codebase grep]
- `./lib/mix/tasks/kiln.first_run.prove.ex` - actual proof owner implementation. [VERIFIED: codebase grep]
- `./mix.exs` - `integration.first_run` alias and shell delegation contract. [VERIFIED: codebase grep]
- `./test/integration/first_run.sh` - delegated boot/proof script behavior. [VERIFIED: codebase grep]
- `./config/runtime.exs` - runtime role-activation logic. [VERIFIED: codebase grep]
- `./lib/kiln/application.ex` - boot ordering with Repo and Oban before endpoint. [VERIFIED: codebase grep]
- `./lib/kiln_web/plugs/health.ex` - health contract and Oban/Postgres status behavior. [VERIFIED: codebase grep]
- `./priv/repo/migrations/20260418000002_create_roles.exs` - role creation and base grants. [VERIFIED: codebase grep]
- `./priv/repo/migrations/20260418000005_install_oban.exs` - Oban install migration without grant repair. [VERIFIED: codebase grep]
- Terminal verification on 2026-04-24 - current proof rerun, `repo_parameters: nil`, installed tool versions, and direct `SET ROLE kiln_app` failures on `oban_jobs`. [VERIFIED: terminal command]

### Secondary (MEDIUM confidence)

- `./.planning/phases/27-local-first-run-proof/27-01-PLAN.md` - original expected proof-owner contract to compare with the current implementation. [VERIFIED: codebase grep]
- `./.planning/phases/27-local-first-run-proof/27-01-SUMMARY.md` - claimed completion state for Phase 27. [VERIFIED: codebase grep]

### Tertiary (LOW confidence)

- None. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - every recommendation is grounded in current repo code and direct command output, not external ecosystem comparison. [VERIFIED: codebase grep] [VERIFIED: terminal command]
- Architecture: MEDIUM - the repo makes the current flow clear, but the intended dev/runtime role contract still has one unresolved decision point. [VERIFIED: config/runtime.exs] [ASSUMED]
- Pitfalls: HIGH - the main pitfalls are directly reproduced or directly contradicted by repository artifacts and database checks. [VERIFIED: .planning/milestones/v0.5.0-MILESTONE-AUDIT.md] [VERIFIED: terminal command]

**Research date:** 2026-04-24 [VERIFIED: terminal command]  
**Valid until:** 2026-05-01 because the closure target is fast-moving and artifact state can change immediately after the next rerun or plan execution. [VERIFIED: .planning/ROADMAP.md]
