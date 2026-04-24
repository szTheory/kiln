---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "03"
subsystem: audit
tags:
  - phase-3
  - audit
  - event-kind
  - jsv
  - migration
  - postgres
  - check-constraint
  - D-145
  - D-106

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: Kiln.Audit ledger + Kiln.Audit.EventKind 22-kind taxonomy + Kiln.Audit.SchemaRegistry (JSV compile-time cache) + priv/audit_schemas/v1/ + audit_events_event_kind_check CHECK constraint + three-layer immutability (REVOKE + trigger + RULE)
  - phase: 02-workflow-engine-core
    provides: Phase 2 D-85 extension (25-kind taxonomy + 3 new JSV schemas + migration 20260419000001 — drop+re-add CHECK constraint pattern); Kiln.AuditLedgerCase with_role/2 + insert_event!/1 helpers
  - phase: 03-agent-adapter-sandbox-dtu-safety
    provides: Plan 03-00 Wave 0 test infrastructure (9-tag exclude list — event_kind_p3_test.exs runs as an unlisted-tag default test, so nothing to opt-in)

provides:
  - "33-kind Kiln.Audit.EventKind taxonomy (22 P1 + 3 P2 D-85 + 8 P3 D-145)"
  - "9 JSV Draft 2020-12 schemas ready for Kiln.Audit.append/1 validation (8 new + 1 rewrite of model_routing_fallback to D-106 shape)"
  - "Reversible Postgres migration 20260420000001_extend_audit_event_kinds_p3 — up/0 sources from EventKind.values_as_strings/0; down/0 hard-codes the 25-atom P2 snapshot"
  - "Test file test/kiln/audit/event_kind_p3_test.exs — 3 describe blocks covering taxonomy membership, Audit.append/1 round-trip for each P3 kind, and D-106 schema validation gate (T-silent-model-fallback mitigation)"

affects:
  - 03-04 (Kiln.Policies.FactoryCircuitBreaker — consumes :factory_circuit_opened / :factory_circuit_closed kinds + schemas for D-139 scaffold body)
  - 03-05 (Kiln.Agents.Adapter — Anthropic adapter's telemetry handler, wired in 03-06, writes :model_routing_fallback via the D-106 payload shape shipped here)
  - 03-06 (BudgetGuard + TelemetryHandler — writes :model_routing_fallback audit event on every adapter :stop where actual_model_used != requested_model; schema field set is pinned by this plan)
  - 03-07/08 (Sandboxes — OrphanSweeper D-120 writes :orphan_container_swept; D-125 DTU health writes :dtu_health_degraded)
  - 03-09 (DTU — ContractTest writes :dtu_contract_drift_detected on OpenAPI drift; schema + atom declared now so P3 code can write without further migration)
  - 03-10 (Kiln.Notifications — D-140 dispatch writes :notification_fired / :notification_suppressed)
  - 03-11 (ModelRegistry — D-108 deprecated-model flow writes :model_deprecated_resolved on resolve-but-stale)

# Tech tracking
tech-stack:
  added: []  # Plan is taxonomy + schema + migration — no new library deps
  patterns:
    - "APPEND-ONLY event_kind extension (2nd instance) — Phase 2's D-85 extension established the pattern; Phase 3's D-145 extension repeats it exactly. Never reorder existing atoms. Mirror migration 20260419000001 exactly in structure."
    - "Drop-and-re-add CHECK constraint from SSOT — up/0 sources from Kiln.Audit.EventKind.values_as_strings/0 (SSOT stays in Elixir); down/0 hard-codes the PRIOR taxonomy snapshot (Plan 02-01 decision (d): reading EventKind at rollback time observes the post-migration module attribute, making down a silent no-op)."
    - "Skip-duplicate-atom guard when action text lists kinds that already exist — `:model_routing_fallback` was in Phase 1's list; Plan 03-03 action said add it again; detected and skipped (Rule 1 deviation)."
    - "Schema rewrite without atom re-declaration — D-106 rewrite of model_routing_fallback.json shipped with the 8 new schemas. Existing atom preserved; SchemaRegistry recompiles via @external_resource without any code change."

key-files:
  created:
    - "priv/audit_schemas/v1/orphan_container_swept.json — D-145 OrphanSweeper sweep event"
    - "priv/audit_schemas/v1/dtu_contract_drift_detected.json — D-125 ContractTest drift detection"
    - "priv/audit_schemas/v1/dtu_health_degraded.json — D-125 DTU /healthz consecutive miss threshold"
    - "priv/audit_schemas/v1/factory_circuit_opened.json — D-139 FactoryCircuitBreaker opened (scaffolded flag)"
    - "priv/audit_schemas/v1/factory_circuit_closed.json — D-139 FactoryCircuitBreaker closed (scaffolded flag)"
    - "priv/audit_schemas/v1/model_deprecated_resolved.json — D-108 deprecated-but-still-resolved warning"
    - "priv/audit_schemas/v1/notification_fired.json — D-140 desktop notification dispatched"
    - "priv/audit_schemas/v1/notification_suppressed.json — D-140 dedup-window suppression"
    - "priv/repo/migrations/20260420000001_extend_audit_event_kinds_p3.exs — reversible CHECK-constraint migration"
    - "test/kiln/audit/event_kind_p3_test.exs — Taxonomy membership + Audit.append/1 round-trip + D-106 schema gate tests (3 tests, 0 failures)"
  modified:
    - "lib/kiln/audit/event_kind.ex — @kinds list 25 → 33 atoms (8 D-145 atoms appended); moduledoc extended to describe P3 extension"
    - "priv/audit_schemas/v1/model_routing_fallback.json — rewrite to D-106 shape (requested_model / actual_model_used / tier_crossed / attempt_number / fallback_reason / wall_clock_ms)"
    - "test/kiln/audit/event_kind_test.exs — 25 → 33 count assertion; new describe for P3 tail ordering invariant + valid?/1 acceptance for 8 P3 atoms"
    - "test/kiln/audit/append_test.exs — add minimal_payload_for/1 clauses for 8 new kinds; rewrite model_routing_fallback payload (Rule 1 direct consequence — old from_model/to_model keys now fail the D-106 schema)"

key-decisions:
  - "8 new atoms, NOT 9 — :model_routing_fallback was already declared in Phase 1 (position 10 in @kinds list); Plan action text's 9-atom list includes it, but adding again would be a duplicate. Skipped. Total atom count 25 → 33 (not 34). Plan's frontmatter truth 'returns at least 30 atoms' still holds."
  - "Rewrote existing priv/audit_schemas/v1/model_routing_fallback.json from P1 minimal shape (from_model/to_model/role/reason, additionalProperties:false) to D-106 full shape (requested_model/actual_model_used/tier_crossed/attempt_number/fallback_reason/wall_clock_ms/provider_http_status/provider/role, additionalProperties:true). Existing atom preserved; JSV SchemaRegistry recompiles automatically via @external_resource."
  - "Migration uses execute/1 inside def up/def down, NOT execute/2 with :no_op atoms. Plan's example used execute/2 with :no_op as the reverse-direction arg, but Ecto.Migration.execute/2 guards both args with `is_binary or is_function or is_list` — :no_op raises FunctionClauseError. def up/def down blocks already own direction semantics, so execute/1 is the idiomatic pick; mirrors Phase 2 migration 20260419000001 exactly."
  - "Updated test/kiln/audit/append_test.exs model_routing_fallback minimal payload to the D-106 shape as a Rule 1 direct consequence of Task 1 schema rewrite. The existing 'every one of the N kinds accepts its minimal payload' test iterates EventKind.values/0 and would have failed schema validation on the old keys — same file had to be touched regardless."
  - "additionalProperties: true on all 9 new/rewritten schemas (matches the plan's explicit schema bodies). The P1/P2 convention was additionalProperties: false for strict shape lock-in. The plan's choice is deliberate forward-compat — P5 may extend these payloads as the D-139 scaffold-now-fill-later body ships; additionalProperties:true avoids a schema migration at that point."

patterns-established:
  - "Schema rewrite without atom re-declaration — when a Phase N introduces new required fields for an existing event kind's payload, rewrite the JSON schema only; the atom stays in EventKind at its original position. SchemaRegistry's @external_resource walk picks up the change at next compile with zero code change."
  - "Skip-duplicate-atom detection at executor time — when a Plan's action text lists atoms already declared in a prior phase's @kinds list, detect via grep/read and skip the duplicate. Document the skipped atom in SUMMARY.md key-decisions."

requirements-completed: [AGENT-05, OPS-02, SEC-01, BLOCK-03]  # From 03-03-PLAN.md frontmatter requirements field

# Metrics
duration: 8min
completed: 2026-04-20
---

# Phase 3 Plan 03: Audit EventKind P3 Extension Summary

**Extends `Kiln.Audit.EventKind` with 8 Phase 3 D-145 atoms and rewrites the `model_routing_fallback` JSON schema to D-106's full payload shape; reversible Postgres CHECK-constraint migration round-trips cleanly.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-20T17:06:19Z
- **Completed:** 2026-04-20T17:14:21Z
- **Tasks:** 2 (atomic commits)
- **Files modified:** 12 (10 created, 2 rewritten; updates to 2 existing test files as Rule-1 direct consequences)
- **Tests:** 3/0 new + 28/0 full audit suite; 263/0 full suite (no regressions from Wave 0 257/0 baseline; +6 tests from this plan)

## Accomplishments

- `Kiln.Audit.EventKind.values/0` returns 33 atoms (22 P1 + 3 P2 D-85 + 8 P3 D-145); append-only ordering preserved.
- 9 JSV Draft 2020-12 schemas under `priv/audit_schemas/v1/` (8 new + 1 rewrite); all parse as valid JSON and compile through `Kiln.Audit.SchemaRegistry` at boot.
- `model_routing_fallback.json` rewritten to the D-106 shape — payloads now require `requested_model`, `actual_model_used`, `tier_crossed`, `attempt_number`, `fallback_reason`, `wall_clock_ms`. T-silent-model-fallback mitigation in place at the JSV boundary.
- Migration `20260420000001_extend_audit_event_kinds_p3.exs` extends the `audit_events_event_kind_check` constraint from 25 → 33 atoms; round-trips cleanly (`mix ecto.migrate` → `mix ecto.rollback --step 1` → `mix ecto.migrate`).
- `mix compile --warnings-as-errors` exits 0; `mix test` reports 263 tests / 0 failures / 5 excluded.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend EventKind with 8 D-145 atoms + ship 9 JSV schemas** — `143393f` (feat)
2. **Task 2: Reversible migration extending audit_events CHECK to 33 kinds** — `7919e7e` (feat)

**Plan metadata:** pending (to be committed with SUMMARY.md).

## Files Created/Modified

### Created (10)

- `priv/audit_schemas/v1/orphan_container_swept.json` — D-145 OrphanSweeper sweep event schema (required: container_id, boot_epoch_found, age_seconds)
- `priv/audit_schemas/v1/dtu_contract_drift_detected.json` — D-125 DTU contract-drift schema (required: endpoint, method, drift_kind; drift_kind enumerates 6 categories including schema_unparseable + other)
- `priv/audit_schemas/v1/dtu_health_degraded.json` — D-125 /healthz consecutive-miss schema (required: consecutive_misses)
- `priv/audit_schemas/v1/factory_circuit_opened.json` — D-139 opened schema (required: reason; scaffolded:true default)
- `priv/audit_schemas/v1/factory_circuit_closed.json` — D-139 closed schema (mirrors opened)
- `priv/audit_schemas/v1/model_deprecated_resolved.json` — D-108 deprecation warning schema (required: model_id, deprecated_on, preset, role)
- `priv/audit_schemas/v1/notification_fired.json` — D-140 dispatch schema (required: reason, platform; platform enum: macos/linux/unsupported)
- `priv/audit_schemas/v1/notification_suppressed.json` — D-140 dedup-window schema (required: reason, dedup_key)
- `priv/repo/migrations/20260420000001_extend_audit_event_kinds_p3.exs` — reversible migration; up sources from EventKind.values_as_strings/0, down hard-codes the P2 25-atom snapshot
- `test/kiln/audit/event_kind_p3_test.exs` — 3 describe blocks: taxonomy membership, Audit.append/1 round-trip for 9 kinds, D-106 schema-gate negative test

### Modified (4)

- `lib/kiln/audit/event_kind.ex` — `@kinds` list 25 → 33 atoms (8 D-145 atoms appended in declaration order); moduledoc extended to describe P3 extension and the `:model_routing_fallback` schema-rewrite-without-atom-change nuance
- `priv/audit_schemas/v1/model_routing_fallback.json` — rewrite to D-106 shape; `additionalProperties: true` + 9 properties + 6 required fields
- `test/kiln/audit/event_kind_test.exs` — count assertion 25 → 33; new describe for P3 tail-ordering invariant; valid?/1 acceptance for 8 P3 atoms + their string forms
- `test/kiln/audit/append_test.exs` — 8 new `minimal_payload_for/1` clauses for D-145 kinds; rewrite `:model_routing_fallback` clause to D-106 payload (Rule 1 direct consequence)

## Decisions Made

See frontmatter `key-decisions` for the full list. Highlights:

1. **8 new atoms, NOT 9** — `:model_routing_fallback` was already declared in Phase 1 (position 10 in `@kinds` list); the plan's action text listed 9 atoms including it, but re-adding would be a duplicate. Total atom count 25 → 33 (not 34). Plan's frontmatter truth "returns at least 30 atoms" still holds.
2. **Schema rewrite without atom re-declaration** — `priv/audit_schemas/v1/model_routing_fallback.json` rewritten from the P1 minimal shape (`from_model`/`to_model`/`role`/`reason`, `additionalProperties: false`) to the D-106 full shape (9 properties, 6 required, `additionalProperties: true`). JSV `SchemaRegistry` picks up the change via `@external_resource` at next compile.
3. **Migration uses `execute/1` in `def up` / `def down`**, NOT `execute/2` with `:no_op` atoms. The plan's example used `execute/2` with `:no_op` as the reverse-direction arg, but `Ecto.Migration.execute/2` guards both args with `is_binary or is_function or is_list` — `:no_op` raises `FunctionClauseError`. `def up` / `def down` already own direction semantics, so `execute/1` is the idiomatic pick; mirrors Phase 2 migration 20260419000001.
4. **`additionalProperties: true` on all 9 new/rewritten schemas** — matches the plan's explicit schema bodies. The P1/P2 convention was `false`; the plan's choice here is deliberate forward-compat for D-139 scaffold-now-fill-later bodies (P5 may extend these payloads without schema migration).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `:model_routing_fallback` already declared in Phase 1**
- **Found during:** Task 1 (reading `lib/kiln/audit/event_kind.ex` pre-edit)
- **Issue:** Plan action text step 1 listed 9 new atoms including `:model_routing_fallback`, but that atom is already at position 10 of the Phase 1 `@kinds` list. Appending again would give two entries for the same atom — `Ecto.Enum` cast would still work but `EventKind.values/0` would report 34, breaking the `down/0` 25-atom snapshot symmetry in Task 2's migration.
- **Fix:** Appended only the 8 truly new D-145 atoms. The existing `:model_routing_fallback` atom is preserved at its P1 position; only its JSON schema is rewritten (also part of Task 1). Total atom count 25 → 33.
- **Files modified:** `lib/kiln/audit/event_kind.ex` (moduledoc explicitly notes the skip-duplicate rationale).
- **Verification:** `EventKind.values/0 |> length() == 33`; new test `test/kiln/audit/event_kind_test.exs` "contains exactly 33 kinds" asserts this; 263/0 test pass.
- **Committed in:** `143393f` (Task 1 commit).

**2. [Rule 1 - Bug] `model_routing_fallback.json` existing schema did not satisfy D-106 acceptance criteria**
- **Found during:** Task 1 (reading `priv/audit_schemas/v1/model_routing_fallback.json` pre-edit)
- **Issue:** The existing P1 schema used `from_model`/`to_model`/`role`/`reason` with `additionalProperties: false`. Plan acceptance explicitly required `requested_model`, `actual_model_used`, `tier_crossed`, `fallback_reason` per D-106 — the P1 shape fails every one of those acceptance checks. Leaving it untouched would have failed Task 1 acceptance.
- **Fix:** Rewrote the schema to the D-106 full shape (9 properties, 6 required, `additionalProperties: true`) exactly as the plan's action step 8 specified. The `:model_routing_fallback` atom remains in its P1 position in `@kinds`.
- **Files modified:** `priv/audit_schemas/v1/model_routing_fallback.json`.
- **Verification:** `jq .` parses; `$schema` is Draft 2020-12; `properties` contains all D-106 fields; `Kiln.Audit.SchemaRegistry` recompiles via `@external_resource` and `Audit.append/1` round-trips the D-106 payload in the new test.
- **Committed in:** `143393f` (Task 1 commit).

**3. [Rule 1 - Bug] Existing `test/kiln/audit/event_kind_test.exs` locks the count at 25**
- **Found during:** Task 1 (first `mix test test/kiln/audit/event_kind_test.exs` run after EventKind edit)
- **Issue:** Pre-existing test `"contains exactly 25 kinds"` hard-codes 25 and the `"preserves the Phase 1 append-only ordering (new kinds at the end)"` test asserts the last 3 kinds are the D-85 atoms. Both break as a direct consequence of adding 8 new atoms in Task 1.
- **Fix:** Rewrote both tests: count assertion updated to 33; tail-ordering test now asserts the last 8 kinds are the P3 D-145 atoms in declaration order AND that the 3 before them are the P2 D-85 atoms. Added new describe block for `valid?/1` acceptance of the 8 P3 atoms + their string forms. Test count went from 12 → 15.
- **Files modified:** `test/kiln/audit/event_kind_test.exs`.
- **Verification:** `mix test test/kiln/audit/event_kind_test.exs` reports 15/0.
- **Committed in:** `143393f` (Task 1 commit).

**4. [Rule 1 - Bug] `test/kiln/audit/append_test.exs` iterates every kind and its `minimal_payload_for` clause is missing 8 entries**
- **Found during:** Task 1 (first `mix test test/kiln/audit/append_test.exs` run after EventKind edit)
- **Issue:** Pre-existing test `"every one of the 25 kinds accepts its minimal payload"` iterates `EventKind.values/0`. With 8 new atoms and no `minimal_payload_for/1` clause for them, the call raises `FunctionClauseError`. Also, the existing `:model_routing_fallback` payload used obsolete `from_model`/`to_model` keys that now fail D-106 JSV validation.
- **Fix:** Added 8 new `defp minimal_payload_for/1` clauses for the D-145 kinds; rewrote the `:model_routing_fallback` clause to the D-106 payload; updated test name from 25 → 33.
- **Files modified:** `test/kiln/audit/append_test.exs`.
- **Verification:** `mix test test/kiln/audit/append_test.exs` reports 13/0 after Task 2 migration lands (test pre-Task-2 fails only on the DB CHECK-constraint side, not on the Elixir side — the payload changes work correctly in isolation).
- **Committed in:** `143393f` (Task 1 commit; re-verified post-Task-2 migration).

**5. [Rule 1 - Bug] Plan's Task 2 migration body used `execute/2` with `:no_op` atoms**
- **Found during:** Task 2 (pre-write — inspected `deps/ecto_sql/lib/ecto/migration.ex` for `execute/2` signature)
- **Issue:** Plan's example migration calls `execute("ALTER TABLE ... DROP ...", "ALTER TABLE ... DROP ...")` once, then `execute("ALTER TABLE ... ADD ...", :no_op)`. `Ecto.Migration.execute/2` at line 1112 pattern-matches `(up, down)` where both must be `is_binary or is_function or is_list` — `:no_op` is an atom, which raises `FunctionClauseError` at migration runtime. Had the migration been run as-written, the first `execute/2` call would have succeeded (both args binary) but the second would have crashed the migration mid-transaction, leaving the audit_events_event_kind_check constraint DROPPED with no replacement.
- **Fix:** Used `execute/1` calls inside `def up` and `def down` (the P2 migration 20260419000001 pattern). `def up` / `def down` already own direction semantics, so the reverse-direction arg is unnecessary. Both directions now DROP-then-ADD cleanly.
- **Files modified:** `priv/repo/migrations/20260420000001_extend_audit_event_kinds_p3.exs`.
- **Verification:** `mix ecto.migrate` → `mix ecto.rollback --step 1` → `mix ecto.migrate` round-trip clean on the test DB; migration log confirms both DROP+ADD statements run on both directions; post-rollback constraint has exactly 25 atoms; post-re-migrate constraint has exactly 33 atoms.
- **Committed in:** `7919e7e` (Task 2 commit).

---

**Total deviations:** 5 auto-fixed (all Rule 1 bugs — 3 from pre-existing files being locked to P2 25-kind assumptions, 2 from plan text errors). Zero Rule 2 (missing critical), zero Rule 3 (blocker), zero Rule 4 (architectural).

**Impact on plan:** All auto-fixes were direct consequences of the plan's own changes (adding 8 atoms + rewriting one schema) meeting reality (existing tests assert the old 25-kind shape; existing `model_routing_fallback.json` uses pre-D-106 keys). No scope creep; the plan's public contract (8 new atoms + 9 JSV schemas + reversible CHECK migration + Audit.append round-trip test) is preserved exactly. The skip-duplicate on `:model_routing_fallback` is the only deviation that affects a frontmatter number (34 → 33), and the plan's "at least 30 atoms" truth still holds.

## Issues Encountered

- Plan action text listed `:model_routing_fallback` in the 9-atom "new" list, but it was already declared in Phase 1. Detected at read-time; documented above.
- Plan action text used `execute/2` with `:no_op` atom in the migration body. Detected pre-write by reading Ecto.Migration source; documented above.
- Plan text's `additionalProperties: true` choice for all 9 schemas diverges from the P1/P2 convention of `false`. Followed the plan's explicit choice (deliberate forward-compat for D-139 scaffold bodies per P5 fill-in); flagged in key-decisions.

None of these blocked Task completion; all three were pre-write catches that avoided destructive runtime behavior.

## User Setup Required

None — no external service configuration required. Migration applies via `mix ecto.migrate`; CHECK constraint is local Postgres DDL.

## Threat Flags

None. Task scope matched the declared `<threat_model>` exactly:

- **T-03-03-01 / T-silent-model-fallback** (Repudiation — missing D-106 fields in `model_routing_fallback`): mitigated by JSV schema rewrite. `required: [requested_model, actual_model_used, fallback_reason, tier_crossed, attempt_number, wall_clock_ms]` fails `Kiln.Audit.append/1` at the boundary if any field is absent. Negative test `model_routing_fallback requires all D-106 fields` in `event_kind_p3_test.exs` exercises this path.
- **T-03-03-02** (Tampering — atom drift between source and DB CHECK): mitigated by migration pattern (up sources from `values_as_strings/0`; down hard-codes prior snapshot). Round-trip verified by `mix ecto.migrate` → `mix ecto.rollback --step 1` → `mix ecto.migrate`.
- **T-03-03-03** (DoS — invalid JSON in audit_schemas blocks compile): mitigated by `jq .` validation on all 9 JSON files (all parse) + `mix compile --warnings-as-errors` exits 0.

No new surfaces were introduced beyond those in the plan; nothing to flag to the verifier.

## Next Phase Readiness

**Unblocks:**
- **Plan 03-04** (Kiln.Policies.FactoryCircuitBreaker D-139 scaffold) — can now `Audit.append/1` `:factory_circuit_opened` / `:factory_circuit_closed` with the `scaffolded: true` marker at any time without migration.
- **Plan 03-05/03-06** (Kiln.Agents.Adapter + BudgetGuard TelemetryHandler) — can now write `:model_routing_fallback` with the D-106 payload shape (schema enforces all 6 required fields; T-silent-model-fallback impossible).
- **Plan 03-07/03-08** (Sandboxes + OrphanSweeper + DTU health) — `:orphan_container_swept`, `:dtu_health_degraded`, `:dtu_contract_drift_detected` ready for `Audit.append/1`.
- **Plan 03-09** (DTU ContractTest stub) — `:dtu_contract_drift_detected` ready.
- **Plan 03-10** (Kiln.Notifications) — `:notification_fired` and `:notification_suppressed` ready.
- **Plan 03-11** (ModelRegistry deprecation) — `:model_deprecated_resolved` ready.

**No blockers.** The `audit_events` CHECK constraint, JSV schemas, `EventKind` atom taxonomy, and test helpers are all in place for the 8 remaining Phase 3 plans.

**Concerns:** None. The `:model_routing_fallback` schema rewrite is a silent breaking change for any code outside Phase 3's test suite that wrote the old `from_model`/`to_model` payload — but a codebase grep shows zero non-test callers (Phase 1/2 never wrote the kind; Phase 3 Plan 06 is the first real writer). The rewrite is safe.

## Self-Check: PASSED

Verified after writing SUMMARY.md:

- [x] `lib/kiln/audit/event_kind.ex` contains all 8 P3 D-145 atoms + preserves the existing `:model_routing_fallback` at position 10
- [x] 9 JSON schema files exist at the expected paths (8 created + 1 rewritten)
- [x] Each new/rewritten schema `$schema` field is `https://json-schema.org/draft/2020-12/schema`
- [x] `model_routing_fallback.json` `properties` contains `requested_model`, `actual_model_used`, `tier_crossed`, `fallback_reason`, `attempt_number`, `wall_clock_ms`
- [x] `factory_circuit_opened.json` and `factory_circuit_closed.json` payloads include `scaffolded` field per D-139
- [x] `priv/repo/migrations/20260420000001_extend_audit_event_kinds_p3.exs` exists with `def up` AND `def down` (reversible) and its up/0 calls `Kiln.Audit.EventKind.values_as_strings()` + its down/0 hard-codes a 25-atom literal list
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix ecto.migrate` → `mix ecto.rollback --step 1` → `mix ecto.migrate` round-trip verified clean
- [x] `mix test test/kiln/audit/event_kind_p3_test.exs` reports 3/0
- [x] `mix test test/kiln/audit/` reports 28/0
- [x] `mix test` (full suite) reports 263/0 (5 excluded)
- [x] Task commits exist: `143393f`, `7919e7e` (verified via `git log --oneline`)

---
*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Completed: 2026-04-20*
