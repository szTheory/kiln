---
phase: 22
slug: merge-authority-operator-docs
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-22
---

# Phase 22 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail. Phase 22 is documentation-only (DOCS-08); risks are misleading merge guidance, not new executable attack surface.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Reader → CI | Docs describe GitHub Actions as merge oracle; must not imply optional scripts are branch-protected gates | Expectations / operator behavior |
| Contributor → repo | Mis-stating tiers could cause merges without intended checks or block healthy merges | Trust in documented CI job names |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-22-01 | I | README / PROJECT prose | mitigate | Optional local commands in a subsection explicitly **not** merge authority; `12-01-SUMMARY.md` cited for local PARTIAL vs CI | closed |
| T-22-02 | E | Wrong job names in docs | mitigate | Tier table + workflow SSOT repeat **exact** job `name:` strings from `.github/workflows/ci.yml` | closed |

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

**Verification evidence**

- **T-22-01:** `.planning/PROJECT.md` — `## Merge authority` tier table (lines ~140–145) followed by `### Recommended before push (optional, not merge authority)` (lines ~149–156) and `### Local vs CI` with path `.planning/phases/12-local-docker-dx/12-01-SUMMARY.md` (line ~160). `README.md` links `.planning/PROJECT.md#merge-authority` and the same Phase 12 summary for PARTIAL language.
- **T-22-02:** `.github/workflows/ci.yml` job `name:` values **`mix check`**, **`integration smoke (first_run.sh)`**, **`tag vs mix.exs version`** match literals in `.planning/PROJECT.md` table and **Workflow SSOT** sentence (lines ~142–147).

### Unregistered flags (from SUMMARY `## Threat Flags`)

`22-01-SUMMARY.md` has no `## Threat Flags` section — **none**.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-22 | 2 | 2 | 0 | gsd-secure-phase (Cursor agent) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (none)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-22
