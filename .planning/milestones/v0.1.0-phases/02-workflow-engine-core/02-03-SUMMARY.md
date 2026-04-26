---
phase: 02-workflow-engine-core
plan: 03
subsystem: storage
tags: [cas, content-addressed-storage, sha256, ecto-migration, ecto-schema, fk-restrict, append-only-grants, ex-machina, factory, oban-maintenance, integrity-on-read, audit-pairing, 13th-context]

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: "uuid_generate_v7() extension, kiln_owner + kiln_app roles (D-48), audit_events + Kiln.Audit.append/1 JSV-validated boundary, Kiln.ExternalOperations.Operation pattern as template, Jason + Ecto 3.13 (Repo.transact/2 new API)"
  - phase: 02-workflow-engine-core
    provides: "Plan 02-00 Kiln.Factory.Artifact SHELL (replaced here with live body) + Kiln.CasTestHelper; Plan 02-01 Kiln.Audit.EventKind 25-kind taxonomy (incl. :artifact_written + :integrity_violation) + audit schemas for both kinds; Plan 02-02 runs + stage_runs tables (FK targets); Plan 02-02 Kiln.Factory.Run + Kiln.Factory.StageRun live factories"

provides:
  - "priv/repo/migrations/20260419000004_create_artifacts.exs — artifacts table: uuidv7 PK, FK(stage_run_id, run_id) both ON DELETE RESTRICT (D-81), sha256 format CHECK, size non-negative CHECK, content_type controlled-vocab CHECK, unique(stage_run_id, name), (run_id, inserted_at) + (sha256) indexes, owner=kiln_owner, kiln_app INSERT+SELECT only (append-only grant pattern — D-48, mirrors audit_events)"
  - "lib/kiln/artifacts/artifact.ex — Kiln.Artifacts.Artifact Ecto schema: 5-value Ecto.Enum content_type, inserted_at only (no updated_at — D-81), changeset wires all 3 check_constraints + 2 foreign_key_constraints + unique_constraint, 50 MB size cap (D-75)"
  - "lib/kiln/artifacts/cas.ex — streaming SHA-256 (:crypto.hash_init(:sha256) + :crypto.hash_update/2 in Enum.reduce) + atomic rename to <cas_root>/<aa>/<bb>/<sha> + File.chmod 0o444 read-only blob. Application.compile_env/3 for cas_root + tmp_root. Module docstring flags cross-filesystem rename pitfall"
  - "lib/kiln/artifacts/corruption_error.ex — Exception struct with artifact_id, expected, actual, path, message fields; message/1 renders artifact_id + expected vs actual sha"
  - "lib/kiln/artifacts.ex — 13th bounded context (D-97). Public API: put/4 (Repo.transact: CAS write → Artifact insert → :artifact_written audit append), get/2, read!/1 (re-hash, audit :integrity_violation, raise CorruptionError), stream!/1 (no integrity check), ref_for/1 (D-75 artifact_ref shape), by_sha/1 (dedup visibility)"
  - "lib/kiln/artifacts/gc_worker.ex — Oban :maintenance worker, max_attempts: 1, unique period 20h; perform/1 no-op (P5 activates refcount-based 24h-grace GC per D-83)"
  - "lib/kiln/artifacts/scrub_worker.ex — Oban :maintenance worker, max_attempts: 1, unique period 6 days; perform/1 no-op (P5 activates weekly table-walk re-hash per D-84)"
  - "test/support/factories/artifact_factory.ex — LIVE ExMachina.Ecto factory replacing Plan 02-00 SHELL; stage_run_id + run_id intentionally nil (caller must supply — mirrors StageRun factory pattern)"
  - "test/kiln/artifacts/cas_test.exs — 6 CAS tests: round-trip + empty body, dedup (chunking-invariant), cas_path fan-out + <4-char FunctionClauseError, read-only mode 0o444"
  - "test/kiln/artifacts_test.exs — 10 integration tests: put→audit pairing, content_type atom/string coercion, unique (stage_run_id, name), read! on match, read! on tampered blob raises + audits, get found + not_found, ref_for shape, by_sha dedup visibility, stream!/1 round-trip"
  - "config/test.exs — stable per-env CAS + tmp roots under System.tmp_dir!() (validate_compile_env-safe)"

affects:
  - "02-05 (Kiln.Stages.StageWorker) — uses Kiln.Artifacts.ref_for/1 to populate cross-stage artifact_ref fields in its stage-input envelopes"
  - "02-06 (Kiln.Runs.Transitions) — no direct dependency, but :escalated / :failed audit payloads may reference artifact ids once StageWorker emits them"
  - "02-07 (Kiln.Runs.RunDirector) — no rehydration dependency; RunDirector doesn't interact with artifacts directly"
  - "02-08 (end-to-end tests) — exercise the full Kiln.Artifacts.put/4 → Audit.append(:artifact_written) flow from a StageWorker-driven stage completion"
  - "Phase 3+ BLOCK-01 / SPEC-02 / OBS-04 — GcWorker + ScrubWorker bodies filled in Phase 5 per D-83/D-84"

# Tech tracking
tech-stack:
  added:
    - "None — :crypto, :file, and ExMachina already in the stack (ExMachina locked in Plan 02-00)"
  patterns:
    - "Content-addressed blob storage with streaming SHA-256 + atomic rename + mode 0o444: tmp file under <tmp_root>/<uuid>, Enum.reduce over the body enumerable chaining :crypto.hash_update/2 and :file.write/2 per chunk, :crypto.hash_final at end, Path.join([@cas_root, aa, bb, sha]), File.rename/2 (errors caught via catch/throw and translated to {:error, {:rename_failed, reason}}). Verbatim from 02-RESEARCH.md Pattern 5"
    - "Repo.transact/2 (Ecto 3.13 new API) for atomic multi-operation writes. The inner function returns {:ok, val} or {:error, reason}; transact/2 unwraps to {:ok, val} | {:error, reason} on commit/rollback. Used instead of Repo.transaction/1 because it's the documented forward-compat API and matches the idiomatic Elixir `with` flow the plan spec calls out"
    - "Append-only Postgres grant pattern: GRANT INSERT, SELECT only (NOT UPDATE, NOT DELETE, NOT TRUNCATE). Second use of this pattern in the project (first: audit_events in migration 3). Appropriate for any table where a row's identity is its content — mutating the row would violate the content-addressing / audit-integrity invariant"
    - "Integrity-on-read with audit-before-raise: Kiln.Artifacts.read!/1 re-hashes every opened blob, appends an :integrity_violation audit event BEFORE raising CorruptionError, so the forensic record survives even if the caller catches the exception. Mirrors the durability-floor D-32 loud-on-violation ethos"
    - "Factory SHELL → LIVE swap discipline: Plan 02-00 shipped SHELL with placeholder_artifact_attrs/0; this plan replaces the entire module with use ExMachina.Ecto + artifact_factory/0. The SHELL marker is deleted, not supplemented — per the Plan 02-00 SUMMARY exit criterion"

key-files:
  created:
    - "priv/repo/migrations/20260419000004_create_artifacts.exs (137 lines)"
    - "lib/kiln/artifacts.ex (197 lines)"
    - "lib/kiln/artifacts/artifact.ex (110 lines)"
    - "lib/kiln/artifacts/cas.ex (118 lines)"
    - "lib/kiln/artifacts/corruption_error.ex (44 lines)"
    - "lib/kiln/artifacts/gc_worker.ex (33 lines)"
    - "lib/kiln/artifacts/scrub_worker.ex (24 lines)"
    - "test/kiln/artifacts_test.exs (206 lines, 10 tests)"
    - "test/kiln/artifacts/cas_test.exs (100 lines, 6 tests)"
  modified:
    - "config/test.exs — added :kiln, :artifacts cas_root + tmp_root config pointing at stable paths under System.tmp_dir!()"
    - "test/support/factories/artifact_factory.ex — SHELL → LIVE (use ExMachina.Ecto, artifact_factory/0 returns %Kiln.Artifacts.Artifact{})"

key-decisions:
  - "Test-env CAS path is STABLE (not per-invocation-unique). Initial attempt used System.unique_integer([:positive]) in config/test.exs to generate unique per-run paths; Elixir's :validate_compile_env raised because the compile-time and runtime-start-time values differed (integers are process-global counters). Fix: use fixed paths `kiln_test_cas` + `kiln_test_tmp` under System.tmp_dir!(). Safe because content-addressed dedup makes collisions harmless — same bytes always produce the same sha, so any 'collision' is actually a correct dedup hit. See Deviation #1."
  - "Kiln.CasTestHelper (shipped Plan 02-00) is NOT used by the CAS tests in this plan. The helper uses Application.put_env to override :kiln, :artifacts at runtime, but Kiln.Artifacts.CAS captures those paths via Application.compile_env/3 at module compile time — runtime put_env is ignored. The stable-test-path strategy above obsoletes the per-test isolation the helper offered. The helper remains in the codebase for future consumers that read :artifacts via Application.get_env (e.g. future GC worker runtime-configurable tuning)."
  - "Content-type Ecto.Enum values use Elixir atom literals with MIME-type strings (`:\"text/markdown\"`, etc.) rather than atom-safe identifiers (`:text_markdown`). Matches the on-disk content_type column's string form 1:1 so the Ecto.Enum cast produces clean round-tripping. normalize_content_type/1 uses String.to_existing_atom/1 (never to_atom) so a malicious string input can't exhaust the atom table (D-63 defence)."
  - "Factory defaults stage_run_id + run_id to nil (not auto-inserted). Mirrors the Plan 02-02 StageRun factory decision: auto-insert would hide FK deps and produce surprise orphans when tests use build/1 without persisting. Caller contract documented in moduledoc."
  - "artifact_factory.ex was REPLACED wholesale (not merged). Per the Plan 02-00 SUMMARY fill-in-obligation table exit criterion, the live body + ExMachina.Ecto directive replaces the SHELL's placeholder_artifact_attrs/0 marker. Same shape as Plan 02-02's Run + StageRun factory swap."

patterns-established:
  - "CAS streaming-hash + atomic-rename pattern concretised. Any future content-addressed storage (v2 object-store backend, scenario-bundle storage, etc.) follows this template: tmp-file write under same FS, :crypto.hash_init/update/final inside Enum.reduce, File.rename into two-level fan-out, chmod 0o444. Test strategy locked: content-addressed tests are inherently async-unsafe on the filesystem level; `async: false` is the default for anything that touches CAS"
  - "Repo.transact/2 for multi-write atomicity (new Ecto 3.13 API). Use this in preference to Repo.transaction/1 for future contexts that need CAS-write + row-insert + audit-append atomicity. The {:ok, val} | {:error, reason} return contract is cleaner than Repo.transaction's {:ok, val} | {:error, Ecto.Multi-key | reason}"
  - "Append-only Postgres grants as table-level invariant. Applied second time in the project (audit_events was first). Any table where row mutation would break the invariant (content-addressing here, append-only ledger there) gets GRANT INSERT, SELECT only. The pattern is now established enough to reference by name: 'append-only grant pattern' (D-81)"
  - "Audit-before-raise for loud-on-violation integrity paths. Kiln.Artifacts.read!/1 appends :integrity_violation BEFORE raising so the forensic record survives caller exception handling. Generalisable: any detect-violation path should audit first, raise second — the audit trail must outlive the control-flow decision"
  - "Phase 2's P5 activation path for Oban workers: ship with queue + max_attempts + unique period configured + perform/1 no-op body, cron entry in config/config.exs commented out until P5. Captures the scheduling intent now (stable shape across phases) without incurring activation risk"

requirements-completed: [ORCH-04, ORCH-07]

# Metrics
duration: ~8min
completed: 2026-04-20
---

# Phase 02 Plan 03: Kiln.Artifacts — Content-Addressed Blob Store

**The 13th bounded context ships. One migration + six source files (artifact.ex / cas.ex / corruption_error.ex / artifacts.ex + 2 Oban worker stubs) + factory swap + 16 tests. Every Phase 2+ stage output now has a durable immutable content-addressed home — integrity-on-read + in-tx audit pairing + dedup for free.**

## Performance

- **Duration:** ~8 min (~454 s)
- **Started:** 2026-04-20T01:47:33Z
- **Completed:** 2026-04-20T01:55:07Z
- **Tasks:** 2 / 2 complete
- **Files created:** 9
- **Files modified:** 2 (`config/test.exs`, `test/support/factories/artifact_factory.ex`)
- **New tests:** 16 (6 CAS + 10 Artifacts context)
- **Full suite:** 163 tests / 0 failures (up from 147 at end of Plan 02-02)

## Accomplishments

- **CAS storage is live, durable, and integrity-guaranteed.** `Kiln.Artifacts.put/4` atomically: (1) streams the body through SHA-256 while writing to a UUID-named tmp file, (2) renames into `<cas_root>/<aa>/<bb>/<sha>` with chmod 0o444, (3) inserts the lookup row, (4) appends a paired `:artifact_written` audit event — all inside a single `Repo.transact/2` (Ecto 3.13 new API). `read!/1` re-hashes every open and raises `CorruptionError` (after appending `:integrity_violation`) on any mismatch — the durability-floor contract holds for CAS the same way it holds for `audit_events`.
- **Append-only grant pattern applied for the second time.** `artifacts` ships with `kiln_app` INSERT + SELECT only, no UPDATE/DELETE/TRUNCATE (same pattern as `audit_events`). Content-addressing makes row mutation nonsensical — the sha IS the row's identity. Four-grep invariant proofs (greps 1-4 in the acceptance list) pass.
- **FK policy enforces the 3-way integrity chain.** `artifacts.stage_run_id` → `stage_runs.id` (RESTRICT) → `runs.id` (RESTRICT, shipped Plan 02-02). Deleting a run while any artifact references its stage_runs fails at the DB boundary. Forensic preservation holds transitively.
- **Content-addressed dedup is visible and tested.** Two `put/4` calls with identical bytes produce the same `sha256` and land at the same CAS path (rename-over-existing is idempotent on POSIX). `by_sha/1` returns both rows — future Phase 5 GC will refcount by sha and only delete blobs with refcount 0 after a 24h grace.
- **Phase 5 activation path is scaffolded, not activated.** `GcWorker` + `ScrubWorker` both `use Oban.Worker, queue: :maintenance` with no-op `perform(_job), do: :ok`. Cron entries in `config/config.exs` are commented out. Phase 5 fills the bodies (refcount-based GC + weekly integrity scrub) without touching the queue wiring, the `unique` periods, or any caller.
- **Factory SHELL → LIVE swap complete.** Plan 02-00's `placeholder_artifact_attrs/0` marker is gone; `test/support/factories/artifact_factory.ex` now has the full `use ExMachina.Ecto` body with a realistic default shape. Plan 02-00's fill-in-obligation table is fully discharged (Run + StageRun swapped in Plan 02-02; Artifact here).

## Task Commits

Each task was committed atomically:

1. **Task 1: migration + Artifact schema + CAS + CorruptionError + config + CAS tests** — `fc4c21d` (feat)
2. **Task 2: Kiln.Artifacts context + 2 Oban worker stubs + live factory + integration tests** — `cdc109c` (feat)

## Files Created / Modified

### Created (9)

**Migration (1):**
- `priv/repo/migrations/20260419000004_create_artifacts.exs` — 137 lines

**Elixir source (6):**
- `lib/kiln/artifacts.ex` — 197 lines (public facade with 6 fns)
- `lib/kiln/artifacts/artifact.ex` — 110 lines (Ecto schema)
- `lib/kiln/artifacts/cas.ex` — 118 lines (streaming hash + atomic rename)
- `lib/kiln/artifacts/corruption_error.ex` — 44 lines
- `lib/kiln/artifacts/gc_worker.ex` — 33 lines (no-op scaffold)
- `lib/kiln/artifacts/scrub_worker.ex` — 24 lines (no-op scaffold)

**Tests (2):**
- `test/kiln/artifacts/cas_test.exs` — 100 lines, 6 tests
- `test/kiln/artifacts_test.exs` — 206 lines, 10 tests

### Modified (2)

- `config/test.exs` — added `config :kiln, :artifacts, cas_root: ..., tmp_root: ...` pointing at stable paths under `System.tmp_dir!()`
- `test/support/factories/artifact_factory.ex` — SHELL → LIVE (`use ExMachina.Ecto`, `artifact_factory/0` returns `%Kiln.Artifacts.Artifact{}`)

## DDL Snippet

### `artifacts` table (append-only grant pattern, 3 CHECKs, 2 RESTRICT FKs)

```sql
CREATE TABLE artifacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  stage_run_id UUID NOT NULL REFERENCES stage_runs(id) ON DELETE RESTRICT,
  run_id       UUID NOT NULL REFERENCES runs(id)       ON DELETE RESTRICT,
  name         TEXT NOT NULL,
  sha256       TEXT NOT NULL,
  size_bytes   BIGINT NOT NULL,
  content_type TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1,
  producer_kind TEXT,
  inserted_at TIMESTAMPTZ NOT NULL,         -- D-81: NO updated_at
  CONSTRAINT artifacts_sha256_format       CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  CONSTRAINT artifacts_size_nonneg         CHECK (size_bytes >= 0),
  CONSTRAINT artifacts_content_type_check  CHECK (content_type IN
    ('text/markdown', 'text/plain', 'application/x-diff',
     'application/json', 'text/x-elixir'))
);
CREATE UNIQUE INDEX artifacts_stage_run_name_idx ON artifacts (stage_run_id, name);
CREATE INDEX artifacts_run_inserted_idx  ON artifacts (run_id, inserted_at);
CREATE INDEX artifacts_sha256_idx        ON artifacts (sha256);

-- D-81 append-only grant pattern (mirrors audit_events):
ALTER TABLE artifacts OWNER TO kiln_owner;
GRANT INSERT, SELECT ON artifacts TO kiln_app;
REVOKE UPDATE, DELETE, TRUNCATE ON artifacts FROM kiln_app;  -- no-op but documentation
```

## CAS Fan-Out Scheme

Two-level fan-out using the first 4 hex chars of the sha256. Handles 65,536 first-level dirs × 65,536 second-level = 4.3B possible buckets; never breaches the ext4/APFS per-dir pathology threshold even at project-end blob counts.

```
<cas_root>/
├── ab/
│   ├── cd/
│   │   └── abcdef012...89...0000.blob   (full 64-hex sha filename)
│   └── ef/
│       └── abef...
└── e3/
    └── b0/
        └── e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855   (empty-body sha)
```

Pure-function derivation in `Kiln.Artifacts.CAS.cas_path/1`:

```elixir
def cas_path(<<aa::binary-size(2), bb::binary-size(2), _::binary>> = sha) do
  Path.join([@cas_root, aa, bb, sha])
end
```

The bit-size guard (`binary-size(2)` × 2) rejects any input shorter than 4 bytes with a `FunctionClauseError` — T1 path-traversal mitigation: non-hex-shaped input cannot produce a valid CAS path, so `name` (the user-visible field) is NEVER used as a path component.

## put/4 In-Tx Audit Pairing Snippet

The core idempotency proof — CAS write then row INSERT + audit append in one transaction:

```elixir
def put(stage_run_id, name, body, opts) do
  content_type = Keyword.fetch!(opts, :content_type)
  run_id       = Keyword.fetch!(opts, :run_id)

  # CAS write is OUTSIDE the tx — the blob can land on-disk even if the
  # tx rolls back. The ScrubWorker cleans orphans (T5 residual risk).
  with {:ok, sha, size} <- CAS.put_stream(body) do
    Repo.transact(fn ->
      cs = Artifact.changeset(%Artifact{}, %{
        stage_run_id: stage_run_id, run_id: run_id,
        name: name, sha256: sha, size_bytes: size,
        content_type: normalize_content_type(content_type),
        schema_version: 1,
        producer_kind: Keyword.get(opts, :producer_kind)
      })

      with {:ok, artifact} <- Repo.insert(cs),
           {:ok, _ev} <-
             Audit.append(%{
               event_kind: :artifact_written,
               run_id: artifact.run_id,
               stage_id: artifact.stage_run_id,
               correlation_id:
                 Logger.metadata()[:correlation_id] || Ecto.UUID.generate(),
               payload: %{
                 "name" => name, "sha256" => sha,
                 "size_bytes" => size,
                 "content_type" => to_string(content_type)
               }
             }) do
        {:ok, artifact}
      end
    end)
  end
end
```

Note `Repo.transact/2` (Ecto 3.13 new API): the inner fn must return `{:ok, val}` or `{:error, reason}`; the outer call unwraps to `{:ok, val} | {:error, reason}`. Cleaner than `Repo.transaction/1`'s tuple-with-multi-key return shape.

## Integrity-On-Read Flow (D-84)

```elixir
def read!(%Artifact{sha256: expected} = artifact) do
  path   = CAS.cas_path(expected)
  bytes  = File.read!(path)
  actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  if actual != expected do
    # Audit BEFORE raising — forensic record survives caller rescue.
    _ = Audit.append(%{event_kind: :integrity_violation, ...,
                       payload: %{"artifact_id" => artifact.id,
                                  "expected_sha" => expected,
                                  "actual_sha" => actual,
                                  "path" => path}})

    raise CorruptionError, artifact_id: artifact.id,
                           expected: expected, actual: actual, path: path
  end

  bytes
end
```

The `_ = Audit.append(...)` pattern is deliberate — if the audit append itself fails (e.g. DB down, schema missing), `read!/1` STILL raises `CorruptionError`. Never silently return corrupted bytes, even when the ledger can't record the violation.

## P5 Activation Path for GC / Scrub Workers

Phase 2 ships the workers as no-ops with the queue + max_attempts + unique period pre-configured. Phase 5 activates:

### `Kiln.Artifacts.GcWorker` — activate by (Phase 5):

1. Fill in `perform/1`:
   - Elevate role via `SET LOCAL ROLE kiln_owner` (kiln_app has no DELETE).
   - Query `artifacts` grouped by `sha256`, compute refcounts.
   - For every sha with refcount 0 AND `max(inserted_at) > now() - 24h`, delete the CAS blob.
   - Skip blobs from runs in `:failed` / `:escalated` state (D-19 forensic retention).
2. Uncomment the cron entry in `config/config.exs` (Phase 2's Oban plugin config ships with the maintenance cron lines commented out).
3. Add integration tests driving the full put → delete-parent-refs → run-worker → verify-blob-removed cycle.

### `Kiln.Artifacts.ScrubWorker` — activate by (Phase 5):

1. Fill in `perform/1`:
   - Stream-iterate `artifacts` rows in chunks of 1000.
   - For each row, re-read the CAS path + re-hash + compare to `sha256`.
   - On mismatch, `Audit.append(%{event_kind: :integrity_violation, ...})` (same payload shape as `read!/1`'s violation path).
   - Log summary metrics (rows scanned, violations found).
2. Uncomment the weekly cron entry in `config/config.exs`.
3. Add integration tests driving corrupted-blob → run-worker → audit-event-appended cycle.

The queue + max_attempts + unique-period (`60*60*20` for GC, `60*60*24*6` for scrub) are locked by this plan — Phase 5 does NOT change them. This keeps the P5 PR a pure-body-fill, not a config churn.

## Decisions Made

See `key-decisions` frontmatter for the five decisions. Highlights:

- **Test-env CAS path is stable, not per-invocation-unique.** The initial attempt used `System.unique_integer([:positive])` for unique paths per test run, but Elixir's `:validate_compile_env` raised at boot because compile-time (post-compile) and runtime-start (fresh process-global counter) values differed. Content-addressed dedup makes stable paths safe — same bytes produce the same sha, so any collision is a correct dedup.
- **`Kiln.CasTestHelper` bypassed; unused this plan.** The helper uses `Application.put_env` at runtime, but CAS pins paths via `Application.compile_env/3` — runtime put_env is ignored. The helper remains in the codebase for future non-CAS consumers that read `:kiln, :artifacts` via `Application.get_env`.
- **Factory stage_run_id + run_id default nil (not auto-inserted).** Mirrors Plan 02-02 StageRun factory — auto-insert would hide FK deps and produce orphans on `build/1`-without-persist.
- **`artifact_factory.ex` replaced wholesale, not merged.** Per Plan 02-00 SUMMARY fill-in-obligation contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `:validate_compile_env` rejected unique-per-run test CAS paths**

- **Found during:** Task 1 first run of `MIX_ENV=test mix test test/kiln/artifacts/cas_test.exs`
- **Issue:** Plan spec for `config/test.exs` used `System.unique_integer([:positive])` to build per-run unique CAS + tmp paths. This integer is a process-global counter; the compile-time value (captured in the `.beam`) differed from the runtime-start value, and Elixir's `:validate_compile_env` at application boot raised with: *"application :kiln has a different value set for path [:cas_root] inside key :artifacts during runtime compared to compile time."* Full test suite couldn't even start.
- **Fix:** Replaced `System.unique_integer([:positive])` with stable paths `"kiln_test_cas"` + `"kiln_test_tmp"` under `System.tmp_dir!()`. Safe because content-addressed dedup means same bytes always produce the same sha + path — "collisions" are correct dedup hits. This also matches the CAS module's `Application.compile_env/3` semantics (whatever the value was at compile, it's the value at runtime).
- **Files modified:** `config/test.exs`
- **Verification:** Full 163-test suite passes; the 6 new CAS tests and 10 new Artifacts tests all green.
- **Committed in:** `fc4c21d`

**2. [Rule 1 — Plan spec vs compile_env semantics mismatch] CAS tests bypass `Kiln.CasTestHelper`**

- **Found during:** Task 1 test authoring
- **Issue:** Plan spec's `test/kiln/artifacts/cas_test.exs` calls `setup :setup_cas_roots` → `Kiln.CasTestHelper.setup_tmp_cas/0`. But the helper uses `Application.put_env(:kiln, :artifacts, ...)` at runtime; `Kiln.Artifacts.CAS` captures its paths via `Application.compile_env/3` at module compile time. Runtime put_env is therefore ignored by CAS — the helper would do nothing for CAS-level tests (though it would work for other future consumers that read via `Application.get_env`).
- **Fix:** The CAS tests now rely on the stable test-env paths set in `config/test.exs` (Deviation #1 fix). Content-addressed dedup makes per-test isolation unnecessary at the CAS level — different tests that write identical bytes converge on the same sha by design. Tests that need row-level isolation rely on `Kiln.DataCase`'s Ecto sandbox (which rolls back every INSERT at test end). `Kiln.CasTestHelper` remains in the codebase unchanged for future runtime-configurable consumers.
- **Files modified:** `test/kiln/artifacts/cas_test.exs` (does not call the helper); moduledoc explains the design.
- **Verification:** 6 CAS tests pass; compile clean.
- **Committed in:** `fc4c21d`

### Plan Spec Adjustments (not bugs — test widening)

- **Added "empty body" and "invalid sha fan-out" CAS tests.** Plan spec called for 3 CAS tests (round-trip, dedup, fan-out); shipped with 6 — added an empty-body round-trip (asserts the well-known `e3b0c44...` SHA-256 of `<empty>`), a `<4-char sha → FunctionClauseError` (T1 path-traversal defence proof), and a `0o444` read-only mode check (graceful-degrades on filesystems that ignore chmod).
- **Artifact tests include `content_type` as atom AND string paths.** Plan spec didn't call out the string→atom normalization boundary explicitly; shipped two variants so the coercion path in `normalize_content_type/1` is covered.
- **Added `get/2` not_found + found tests, `stream!/1` round-trip test.** Plan spec called for put/4, read!/1, ref_for/1, by_sha/1 coverage; shipped with `get/2` + `stream!/1` coverage too so the full 6-function public surface is tested.

**Total deviations:** 2 auto-fixed (Rule 3 blocking compile_env validation, Rule 1 plan spec vs compile-env semantics), 3 non-breaking test-widening adjustments. No scope creep.

## Issues Encountered

None beyond the deviations above.

## Authentication Gates

None required.

## Verification Evidence

- `MIX_ENV=test mix ecto.migrate` — 20260419000004 applied cleanly
- `MIX_ENV=test mix ecto.rollback --step 1 && MIX_ENV=test mix ecto.migrate` — clean round-trip verified
- `MIX_ENV=test mix compile --warnings-as-errors` — 0 warnings
- `mix compile --warnings-as-errors` (dev) — 0 warnings
- `MIX_ENV=test mix test test/kiln/artifacts/cas_test.exs test/kiln/artifacts_test.exs` — 16 tests, 0 failures
- `MIX_ENV=test mix test --exclude pending` — 163 tests, 0 failures (no regression from 147 at end of Plan 02-02 +6 CAS +10 Artifacts = 163)
- Task 1 acceptance grep checks (8 items) — all pass
- Task 2 acceptance grep checks (10 items) — all pass (including `! grep -q placeholder_artifact_attrs` and `grep -q "use ExMachina.Ecto"` on the new live factory)

## Next Plan Readiness

- `Kiln.Artifacts.put/4` is live for Plan 02-05 (StageWorker) to call when stages produce outputs.
- `Kiln.Artifacts.ref_for/1` is live for Plan 02-05 to populate cross-stage `artifact_ref` envelope fields the `Kiln.Stages.ContractRegistry` (Plan 02-01) validates.
- `Kiln.Artifacts.read!/1` integrity-on-read is live; any future consumer reading a stored blob gets the durability-floor guarantee.
- `Kiln.Factory.Artifact.insert/1` is live for Plan 02-05+ tests that need pre-seeded artifacts without round-tripping through CAS.
- P5 obligations: activate `GcWorker` + `ScrubWorker` bodies + uncomment cron entries (scaffold shipped here; bodies deferred per D-83/D-84).

## Known Stubs

Two worker modules ship as Phase 2 scaffolds with no-op bodies — these are deliberate, documented, and part of the plan's success criteria:

| File | Stub reason | Activation plan |
|------|------------|-----------------|
| `lib/kiln/artifacts/gc_worker.ex` | P2 scaffold per D-83; P5 activates with full refcount + 24h-grace GC body | Phase 5 plan |
| `lib/kiln/artifacts/scrub_worker.ex` | P2 scaffold per D-84; P5 activates with weekly table-walk + re-hash body | Phase 5 plan |

Both are registered on the Oban `:maintenance` queue with production-grade `unique` periods already configured. Cron entries in `config/config.exs` are intentionally commented out until Phase 5. The moduledocs on both workers name the activation phase explicitly so a future agent grep finds the obligations.

No accidental stubs (hardcoded empty values flowing to UI, "coming soon" placeholders, un-wired data sources). The single `placeholder` grep hit in the codebase is a moduledoc comment on the factory's test-only default sha256 — semantically appropriate naming, not a stub.

## Self-Check: PASSED

- All 9 claimed-created files exist on disk (verified with `[ -f <path> ] && echo FOUND`).
- Both task commits (`fc4c21d`, `cdc109c`) present in `git log --all --oneline`.
- Full `MIX_ENV=test mix test --exclude pending` suite: 163 tests, 0 failures.
- `MIX_ENV=test mix compile --warnings-as-errors` + `mix compile --warnings-as-errors` (dev) both clean.
- Migration `20260419000004` status = up after final round-trip.
- No unexpected file deletions in either task commit (the `artifact_factory.ex` change is a modification, not a deletion — verified via `git diff --diff-filter=D`).
- Placeholder-scan clean: 0 real stubs; 2 deliberate documented worker-body stubs listed in Known Stubs above.

---

*Phase: 02-workflow-engine-core*
*Completed: 2026-04-20*
