---
title: Configuration
description: Environment variables, runtime secrets references, and operator-facing knobs.
---

## Environment

`config/runtime.exs` reads all environment variables. Use `.env.sample` as the authoritative list for local development.

## Secrets

Store secret **names**, not values. Fetch from `persistent_term` at point-of-use and redact in logs and UI.

## Further reading

See `README.md` in the repository for day-to-day commands and health checks.
