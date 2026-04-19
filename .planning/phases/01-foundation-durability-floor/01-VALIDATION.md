---
phase: 1
slug: foundation-durability-floor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5) + LiveViewTest + Mox + StreamData |
| **Config file** | `test/test_helper.exs`, `.check.exs` (ex_check 0.16) |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix check` |
| **Estimated runtime** | ~60–90 seconds (cold Dialyzer adds 5–10 min; warm cache ~30 s) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale` (≤30 s)
- **After every plan wave:** Run `mix check` (~60–90 s with warm Dialyzer PLT)
- **Before `/gsd-verify-work`:** Full `mix check` must be green AND `docker compose up` fresh-clone boot must pass
- **Max feedback latency:** 90 seconds per task commit

---

## Per-Task Verification Map

> Populated by the planner in step 8 — each plan's tasks map back to this table with
> an `<automated>` command that proves the behavior from the Validation Architecture
> section of RESEARCH.md. Status stays ⬜ pending until the executor fills it during
> `/gsd-execute-phase`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | LOCAL-01 / LOCAL-02 / OBS-01 / OBS-03 | — | Filled by planner | unit / integration | Filled by planner | ✅ / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Phase 1 is greenfield — there is no existing test infrastructure. Wave 0 must install the
ExUnit baseline via `mix phx.new` AND add the supporting tooling:

- [ ] `mix.exs` — Phoenix 1.8.5, LiveView 1.1.28, Ecto 3.13, Oban 2.21, Oban.Web 2.12, logger_json 7.0, JSV 0.18, Req 0.5, Anthropix 0.6, Finch (named `Kiln.Finch`), ex_check 0.16, Credo, Dialyxir, Sobelow, mix_audit, credo_envvar, ex_slop, stream_data, mox, lazy_html
- [ ] `.check.exs` — ex_check config invoking mix format, compile --warnings-as-errors, Credo --strict, Dialyzer, Sobelow HIGH-only, mix_audit, `mix xref graph --format cycles`, `mix check_no_compile_time_secrets`
- [ ] `test/test_helper.exs` — ExUnit.start, Ecto sandbox config, `Mox` config
- [ ] `test/support/` — test fixtures dir (.gitkeep OK until plans fill it)
- [ ] `test/support/audit_ledger_case.ex` — ExUnit case template providing a `kiln_app`-roled DB connection helper for audit immutability tests (three-layer enforcement requires role-switching inside tests)
- [ ] `test/support/logger_capture_helper.ex` — helper wrapping `ExUnit.CaptureLog` + JSON decode for metadata-threading assertions (D-47)
- [ ] `priv/audit_schemas/v1/.gitkeep` — JSV schema dir; per-kind schemas land as plans ship them
- [ ] `priv/repo/migrations/` — Ecto migrations dir; first migration installs `pg_uuidv7` extension
- [ ] `.github/workflows/ci.yml` — GHA workflow running `mix check` against Postgres 16 service container
- [ ] `.tool-versions` — Elixir 1.19.5-otp-28 / Erlang 28.1.2 / nodejs 22 LTS

---

## Manual-Only Verifications

Phase 1 automates everything except the fresh-clone onboarding UX, which depends on the
operator's machine state (asdf installed, Docker Desktop running, direnv installed).

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh-clone first-run UX works end-to-end | LOCAL-01 | Depends on operator's local toolchain (asdf, Docker, direnv); can't be automated inside `mix check` | On a fresh macOS machine: `git clone`, `asdf install`, `cp .env.sample .env`, `docker compose up -d`, `mix setup`, `mix phx.server`, `curl localhost:4000/health` returns `{"status":"ok",...}` with all four dependency fields present |
| Operator-facing boot error messages are readable | LOCAL-01 | Subjective — "does the operator understand what to fix?" — codified only by test-time string matching, but the actual UX quality requires eyes | Deliberately break `DATABASE_URL`, boot, confirm `Kiln.BootChecks.Error` message names the failing invariant + the remediation step |

---

## Observable Behaviors (from RESEARCH.md § Validation Architecture)

The planner MUST express each task's `<automated>` assertion in terms of one of these
42 distinguishable behaviors. Each behavior is tied to a locked decision ID in
CONTEXT.md. A test that does not observe one of these behaviors does not contribute
to Nyquist coverage.

The authoritative list lives in `01-RESEARCH.md` § Validation Architecture (line 1602+).
Representative examples:

- **AUD-01:** `kiln_app` role attempting `UPDATE audit_events` raises `Postgrex.Error` with code `:insufficient_privilege` (SQLSTATE 42501) [D-12 Layer 1]
- **AUD-02:** `kiln_owner` role (or any role with REVOKE bypassed) attempting `UPDATE audit_events` raises the immutability trigger exception with substring `"audit_events is append-only"` [D-12 Layer 2]
- **AUD-03:** With triggers disabled and role elevated, the RULE no-ops the UPDATE (`UPDATE 0` rows affected, no exception, row content unchanged) [D-12 Layer 3]
- **IDEM-01:** Two `fetch_or_record_intent/2` calls with the same `idempotency_key` return the same row (one INSERT, one re-read) — UNIQUE INDEX enforces [D-15]
- **LOG-01:** A log line emitted from a spawned `Task.async_stream` worker contains `correlation_id` matching the parent's value (JSON-parsed via `logger_json`) [D-45, D-47]
- **LOG-02:** A log line emitted from an Oban job execution contains `correlation_id` matching the enqueueing caller's value (propagated via `Oban.Job.meta["kiln_ctx"]`) [D-45, D-47]
- **BOOT-01:** `Kiln.BootChecks.run!/0` raises with a structured `Kiln.BootChecks.Error` when the `REVOKE UPDATE ON audit_events` is absent [D-32]
- **BOOT-02:** `Kiln.BootChecks.run!/0` raises when any of the 12 contexts is uncompiled (`Code.ensure_compiled?/1` fails) [D-32]
- **CI-01:** `mix check_no_compile_time_secrets` exits non-zero when any of `config/{config,dev,prod}.exs` contains `System.get_env` or `System.fetch_env!` [D-26]
- **CI-02:** `Kiln.Credo.NoProcessPut` flags `Process.put(:key, :value)` in a source file [D-24]

Full enumeration (42 behaviors) in RESEARCH.md § Validation Architecture.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (no framework shipped yet — Wave 0 installs ExUnit via `mix phx.new`)
- [ ] No watch-mode flags (no `--watch`, no long-running helpers)
- [ ] Feedback latency < 90s per task commit
- [ ] `nyquist_compliant: true` set in frontmatter after plans fill the per-task verification map

**Approval:** pending
