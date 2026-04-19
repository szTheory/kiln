# Phase 1: Foundation & Durability Floor - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `01-CONTEXT.md` — this log preserves the alternatives considered, the research that informed each pick, and the operator's confirmation moments.

**Date:** 2026-04-18
**Phase:** 01-foundation-durability-floor
**Areas discussed:** Phoenix scaffold scope; `audit_events` + `external_operations` schema; CI strictness + custom Credo checks; DTU placeholder + health-check depth
**Mode:** advisor (4 parallel `gsd-advisor-researcher` agents spawned in research phase)

---

## Gray Area Selection

The operator was presented with four candidate gray areas (all four marked Recommended):

| Area | Selected | Notes |
|------|----------|-------|
| Phoenix scaffold scope | ✓ | |
| audit_events + external_operations schema | ✓ | |
| CI strictness + custom Credo checks | ✓ | |
| DTU placeholder + health-check depth | ✓ | |

**Operator instruction (verbatim):**

> "for each of these...---research using subagents, what is pros/cons/tradeoffs of each considering the example for each approach, what is idiomatic for elixir/plug/ecto/phoenix for this type of lib and in this ecosystem, lessons learned from other libs in same space even from other languages/frameworks if they are popular successful, what did they do right that we should learn from, what did they do wrong/footguns we can learn from, great developer ergonomics/dx emphasized... think deeply one-shot a perfect set of recommendations so I don't have to think, all recommendations are coherent/cohesive with each other and move us toward the goals/vision of this project... using great software architecture/engineering, principle of least surprise and great UI/UX where applicable great dev experience... STILL CONFIRM WITH ME but I want u to give high confidence recs before asking me final for each checkoff."

Four parallel `gsd-advisor-researcher` Task agents were spawned, one per area, in a single message. All four returned structured comparison tables + recommendations.

---

## Area 1 — Phoenix Scaffold Scope

| Option | Description | Selected |
|--------|-------------|----------|
| A. Full LiveView+assets scaffold | `mix phx.new kiln --database postgres --binary-id --no-mailer --no-gettext --install`; mount `/ops/dashboard` + `/ops/oban` in P1; stub `Kiln.Scope`; replace `PageController` with `Kiln.HealthController` | ✓ |
| B. Backend-only scaffold | `--no-html --no-assets`; defer LV/assets/dashboards/scopes to P7 | |
| C. Hybrid — full scaffold but defer dashboards/scopes to P7 | Same as A but skip mount + scope stub | |

**User's choice:** "Confirm Option A as recommended"
**Notes:** `--no-html` is hard to reverse; Phoenix generators silently assume HTML scaffolding. `--binary-id` matches Postgres UUID convention. Asset-pipeline cost (5–10s CI per build) is small vs cost of rebuilding it at P7. Mounting `/ops/dashboard` + `/ops/oban` in P1 is the operator-during-build-time UX win — debugging Phase 2's Oban two-phase semantics via raw SQL would be painful.

---

## Area 2 — `audit_events` + `external_operations` Schema

This area covered two interrelated tables. Research returned ~2000-word analysis with five sub-sections (enforcement mechanism, PK/taxonomy/payload, single-vs-per-context, key-shape/lifecycle, indexes/partitioning/naming).

| Option | Description | Selected |
|--------|-------------|----------|
| Confirm full bundle including spec upgrades | UUID v7 PK via `pg_uuidv7` ext; text+CHECK event_kind (22 initial values); JSV per-kind validation; 5 b-tree indexes; defense-in-depth INSERT-only enforcement (REVOKE + trigger + RULE); single `external_operations` table; flat string idempotency_key; 5-state enum; 10 op_kind values; 30-day TTL on `:completed` only. **Updates CLAUDE.md and ARCHITECTURE.md §9.** | ✓ |
| Keep CREATE RULE only (no spec upgrade) | Use only CREATE RULE per current CLAUDE.md. Trade: silent UPDATE-0 bypass risk. | |
| Use bigserial PK instead of UUID v7 | Skip pg_uuidv7 extension; bigint serial PKs. Trade: smaller indexes but audit IDs not externally meaningful. | |

**User's choice:** "Confirm full bundle including spec upgrades"
**Notes:** Two spec upgrades flagged for explicit operator OK:
1. **D-12 / D-50:** Defense-in-depth enforcement (REVOKE + trigger + RULE), not RULE alone — the PG community has documented silent-bypass modes for RULE; for an audit ledger, silent failure is the worst outcome. CLAUDE.md will be updated in the same Phase 1 commit chain.
2. **D-13 / D-51:** Resolve naming drift — ARCHITECTURE.md §9 says `events`; CLAUDE.md says `audit_events`. Standardize on `audit_events`.

Research cited: Brandur's Stripe-pattern reference (`brandur.org/idempotency-keys`, `rocket-rides-atomic`); Plausible/Sequin/Oban/Close.com convergence on text+CHECK over Postgres ENUM; PG18 native `uuidv7()` with `pg_uuidv7` ext as PG16 fallback; jsonschema benchmarks (50× perf gap vs `pg_jsonschema`); Carbonite (bitcrowd) as comparable Elixir audit-trail reference.

---

## Area 3 — CI Strictness + Custom Credo Checks

| Option | Description | Selected |
|--------|-------------|----------|
| A. Minimal-strict (CI-first, defer custom checks) | ex_check defaults + format + warnings-as-errors + Credo `--strict` + Dialyzer warnings-only + Sobelow HIGH + mix_audit. No custom Credo. | |
| B. Balanced | All of A + `credo_envvar` + `ex_slop` + 2 hand-written Credo checks (`NoProcessPut`, `NoMixEnvAtRuntime`) + xref-cycles hard gate + Dialyzer fail-on-warning + Sobelow HIGH-only baseline + mix_audit allowlist + 2 pre-created Mix tasks (`check_no_compile_time_secrets`, `check_no_manual_qa_gates`) + `make check` (no lefthook) + single runner | ✓ |
| C. Maximalist | All of B + 4 more custom Credo checks (NoStatelessGenServer, NoUnsupervisedSpawn, NoApplyHotPath, BooleanObsession) + lefthook pre-commit + Postgres 16+17 matrix + branded mix kiln.check wrapper | |

**User's choice:** "Confirm Option B as recommended"
**Notes:** Custom checks needing flow analysis (NoStatelessGenServer, NoUnsupervisedSpawn, NoApplyHotPath) excluded — high false-positive rate trains the engineer to ignore the linter. Lefthook bypassed in solo-engineer practice (documented pattern); `make check` makes local + CI run identically. Sobelow MEDIUM excluded due to over-reporting on Phoenix 1.8 (paraxial sobelow_guide noted).

---

## Area 4 — DTU Placeholder + Health-Check Depth

| Option | Description | Selected |
|--------|-------------|----------|
| A. Minimal | Single `/health` Plug; Postgres ping; no anchor container; `.env.sample` only | |
| B. Standard | Single `/health` JSON; `Kiln.BootChecks.run!/0` raises on Application start; idle anchor container behind `profiles:`; `.env.sample` + direnv recipe in README | ✓ |
| C. Maximal | `/healthz` + `/readyz` split; `BootChecks` + adversarial sandbox-egress probe at boot; nginx-stub on the DTU bridge | |

**User's choice:** "Confirm Option B as recommended"
**Notes:** `/healthz` + `/readyz` split is over-engineering for solo + local-only (PROJECT.md Out of Scope: hosted cloud runtime). Adversarial egress probe at boot pulls Phase 3 work into Phase 1 (rejected — keep phase boundaries clean). `compose.yaml` (Compose v2 canonical filename) over `docker-compose.yml`. direnv as the Elixir-community gold standard with shell fallback for non-direnv operators. `Kiln.BootChecks.run!/0` generalizes Plausible's SECRET_KEY_BASE-at-boot pattern with `KILN_SKIP_BOOTCHECKS=1` escape hatch.

---

## Operator-Raised Future Work (mid-discussion, marked for capture, NOT folded into P1)

The operator surfaced a meta-concern about Kiln's self-evaluation / continuous-improvement loop after the four areas were resolved. Verbatim quote and proposed sub-themes captured in `01-CONTEXT.md` under `<deferred>` → "Future-work seed".

The operator explicitly said: *"don't have to adjust everything right now but mark this for perhaps future work."*

Recommended capture mechanism (proposed but not yet executed):
- Add a v2 / v1.5 requirement cluster to `.planning/REQUIREMENTS.md` under "Self-Evaluation & Continuous Improvement"
- Plant a seed via `gsd-plant-seed` triggered to surface at "Phase 9 verification" or "v1 release prep"

Will offer the operator the explicit `gsd-add-backlog` + `gsd-plant-seed` invocation paths in the post-commit summary message.

---

## Claude's Discretion (areas not raised; planner has flexibility)

- Module file names within each context's directory (follow ARCHITECTURE.md §15 layout).
- `mix.exs` aliases composition.
- README structure beyond ensuring it documents the four-step first-run UX.
- CHANGELOG.md format.
- Test fixtures structure under `test/support/`.
- Whether `Kiln.HealthPlug` lives in `lib/kiln_web/plugs/` or `lib/kiln_web/health/`.
- Specific `description:` text in custom Credo checks.
- Exact wording of operator-facing trigger error message (must include "audit_events is append-only" substring).

---

## Deferred Ideas (out-of-phase-scope)

See `01-CONTEXT.md` `<deferred>` section for the canonical list.
