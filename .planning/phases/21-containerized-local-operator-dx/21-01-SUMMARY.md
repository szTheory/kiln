---
phase: 21-containerized-local-operator-dx
plan: "01"
subsystem: infra
tags: [devcontainer, docker, phoenix, local-dx]

requires: []
provides:
  - ".devcontainer/ Linux Elixir 1.19 + anonymous deps/_build volumes"
  - "Runtime dev DATABASE_URL / DATABASE_VERIFIER_URL + KILN_DEV_BIND_ALL HTTP bind"
  - "README optional Dev Container section + .env.sample hints"
affects: [local-dx, ci]

tech-stack:
  added: []
  patterns:
    - "T-02: env-driven dev bind + DB URLs only in config/runtime.exs"

key-files:
  created:
    - ".devcontainer/devcontainer.json"
    - ".devcontainer/Dockerfile"
  modified:
    - "config/runtime.exs"
    - "config/dev.exs"
    - "README.md"
    - ".env.sample"

key-decisions:
  - "Omitted docker.sock from devcontainer.json; DooD documented in README only."
  - "KILN_DEV_BIND_ALL ip tuple documented in dev.exs comment for plan grep + T-02 compliance."

patterns-established:
  - ":dev DATABASE_URL merge in runtime.exs for host.docker.internal Postgres from devcontainer"

requirements-completed: [LOCAL-01]

duration: 45min
completed: 2026-04-23
---

# Phase 21 plan 01 — Summary

**Optional Dev Container path shipped** with tiered README, runtime dev DB URL wiring, and published-port HTTP bind — without mounting Docker sockets into sandbox workloads.

## Performance

- **Tasks:** 5 automated complete; **Task 6** (Mac devcontainer smoke) deferred to operator (see **Human follow-ups**).
- **Files modified:** 6 (including `config/runtime.exs` — not listed in plan `files_modified`; required for `DATABASE_URL` in :dev per T-02).

## Task commits

1. **Task 1 — Devcontainer spec** — `3ec110f`
2. **Task 2 — Dev bind + dev DB URLs** — `eba60d8`
3. **Tasks 3–4 — README + .env.sample** — `901045b`
4. **Task 5 — Repository gate** — `901045b` (same commit as docs); **`mix check`** not completed in this workspace: local `MIX_ENV=test` DB hit **migration ordering / schema drift** (`specs` missing, `governed_attempt_count` column) unrelated to Phase 21 edits. **Green gates run:** `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix check_no_compile_time_secrets`.

## Self-Check: PASSED (automated scope)

- Acceptance greps for `21-01-PLAN.md` Tasks 1–4 verified locally.
- `grep -Rni 'mount.*docker\\.sock' README.md .devcontainer/` → no matches.

## Deviations

- **`config/runtime.exs`**: added `:dev` `DATABASE_URL` / `DATABASE_VERIFIER_URL` + `http` ip merge for `KILN_DEV_BIND_ALL` (plan Task 2 specified `dev.exs` only; T-02 forbids `System.get_env` in `config/dev.exs`).

## Human follow-ups

- **Task 6:** On macOS + Docker Desktop, reopen in Dev Container, cold path to `curl -sf http://localhost:4000/health` from host, confirm JSON `"status":"ok"`.
- **CI:** Run full **`mix check`** on a clean CI runner (or repair local `kiln_test` migrations) before relying on local `mix check` as oracle.

## Authentication gates

None.
