# Phase 22: Merge authority & operator docs — Research

**Status:** Ready for planning  
**Question answered:** What do we need to know to PLAN this phase well?

## Summary

Phase 22 is **documentation-only** (DOCS-08): align **`README.md`** and **`.planning/PROJECT.md`** so merge authority is **single-sourced** in `PROJECT.md` and the README gives a **short, honest** pointer plus Phase 12 **PARTIAL** context. No CI YAML edits are in scope unless a missing link is discovered.

Mechanical facts (verified against `.github/workflows/ci.yml` at planning time):

| Job `name:` | When it runs | Merge relevance |
|-------------|----------------|-----------------|
| `mix check` | PR + push to `main` (not tag refs) | **Tier A** — `mix compile --warnings-as-errors`, `mix dialyzer --plt`, **`mix check`**. |
| *(step inside `check`)* `Kiln boot checks (CI parity — D-34)` | Same job, after `mix check` | **Tier B** — `KILN_DB_ROLE=kiln_owner mix ecto.migrate && mix kiln.boot_checks` against the workflow’s `postgres:16` service. |
| `integration smoke (first_run.sh)` | After `check` succeeds | **Tier C** — `bash test/integration/first_run.sh` (Compose + host-adjacent smoke; separate job). |
| `tag vs mix.exs version` | Tag pushes `v*` only | **Tier D** — `script/verify_tag_version.sh`; **not** every PR. |

**Not** merge gates today: `just planning-gates`, `just shift-left`, `script/precommit.sh`, `mix precommit`, `DOCS=1 mix docs.verify` — list under “Recommended before push” only unless CI is extended.

Evidence for honest “local may differ” copy: `.planning/phases/12-local-docker-dx/12-01-SUMMARY.md` documents **Self-Check: PARTIAL** for local `mix check` vs CI.

## Validation Architecture

Doc changes do not add runtime code paths. Verification is **content + link integrity**:

| Layer | Command / check | When |
|-------|-------------------|------|
| Anchor grep | `grep -n 'Merge authority' .planning/PROJECT.md` + heading stable for README link | After `PROJECT.md` edit |
| README pointer | `grep` proves README contains `.planning/PROJECT.md` fragment link and does **not** paste a second full tier table (no duplicate markdown pipe-table under merge callout) | After README edit |
| CI truth spot-check | Re-read `.github/workflows/ci.yml` job `name:` strings referenced in table footnote | Before final commit |
| Optional | `mix format` not required for markdown-only unless touched files include formatter scope | Per executor |

Nyquist note: **DOCS-08** is the sole REQ traceability ID for this phase; validation rows in `22-VALIDATION.md` map to plan tasks and grep-based acceptance.

## RESEARCH COMPLETE
