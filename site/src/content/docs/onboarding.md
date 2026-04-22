---
title: Onboarding
description: From zero to a first local run — environment, database roles, and verification.
---

## Goals

You will install prerequisites, configure secrets references, boot Postgres, migrate with the owner role, and start the Phoenix application.

## Outline

1. Copy `.env.sample` to `.env` and load it.
2. Start Postgres (`docker compose up -d db`).
3. Run `KILN_DB_ROLE=kiln_owner mix setup` once for DDL-capable migrations.
4. Run `mix phx.server` and open the onboarding wizard at `/onboarding`.

Details stay in the application; this page tracks the **happy path** only.
