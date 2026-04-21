---
phase: 09
slug: dogfood-release-v0-1-0
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-21
---

# Phase 9 — Validation Strategy

> Sampling contract for `/gsd-execute-phase` — Elixir/Phoenix + OTel + release gates.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + LiveViewTest |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `mix check` |
| **Integration script** | `bash test/integration/first_run.sh` (manual / optional CI job) |
| **Estimated runtime** | `mix check` ~minutes (Dialyzer cold); cached CI faster |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors` (and targeted `mix test path` when tests exist for touched modules)
- **After every plan wave:** `mix check`
- **Before `/gsd-verify-work`:** `mix check` green; `first_run.sh` if README/compose/health changed
- **OTel wiring complete:** Manual Jaeger pass once (full span tree) — record in SUMMARY

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 09-01-* | 01 | 1 | GIT-04 | T-09-ci | No secrets in workflow YAML | compile + yaml review | `mix compile --warnings-as-errors` | ⬜ |
| 09-02-* | 02 | 1 | OBS-02 | T-09-otel | No secrets in span attrs | unit + manual trace | `mix test test/kiln/telemetry` (TBD paths) | ⬜ |
| 09-03-* | 03 | 1 | LOCAL-03 | — | Docs only | script + LV test | `bash test/integration/first_run.sh`; `mix test test/kiln_web/live/onboarding_live_test.exs` | ⬜ |
| 09-04-* | 04 | 2 | GIT-04, OBS-02, LOCAL-03 | T-09-gh | Token never logged | integration + mix | `mix check` + selective integration | ⬜ |
| 09-05-* | 05 | 3 | GIT-04, LOCAL-03 | — | Changelog accuracy | grep + mix | `mix check` | ⬜ |

---

## Wave 0 Requirements

- **Existing infrastructure** covers Elixir/Phoenix — no new test framework install.
- [ ] Confirm `mix check` alias includes all gates in `mix.exs` before Phase 9 execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Jaeger span tree | OBS-02 | Needs collector + browser | `docker compose up` stack with Jaeger; run one dogfood stage; confirm parent/child across Oban |
| Second-machine cold clone | LOCAL-03 | Physical second env | README-only clone; friction log per `09-CONTEXT` D-930 |

---

## Validation Sign-Off

- [ ] All tasks include automated `mix` verify or explicit manual row above
- [ ] No watch-mode flags in commands
- [ ] `nyquist_compliant: true` set after first execute wave

**Approval:** pending
