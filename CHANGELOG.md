# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-21

### Added

- Initial public milestone for the solo-operator “dark factory” loop:
  specs, runs, sandboxes, GitHub automation scaffolds, and operator UI
  surfaces through Phase 9.

### Requirements

Shipped v0.1.0 scope maps **55** v1 REQ-IDs across `.planning/REQUIREMENTS.md`
(phases 1–9). Highlights called out for this release:

- **GIT-04** — tag and CI gates so `v*` tags match `mix.exs` `:version`;
  GitHub Actions `ci.yml` remains the canonical `mix check` gate.
- **OBS-02** — OpenTelemetry trace instrumenters (Phoenix, Bandit, Ecto,
  Oban) plus local OTLP → Jaeger compose stack for operator proof.
- **LOCAL-03** — README / `first_run.sh` / `.env.sample` aligned to the
  real onboarding path (`/onboarding`, `KILN_DB_ROLE=kiln_owner mix setup`).
