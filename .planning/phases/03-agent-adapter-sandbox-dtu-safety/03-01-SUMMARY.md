---
phase: 03-agent-adapter-sandbox-dtu-safety
plan: "01"
subsystem: security
tags:
  - phase-3
  - wave-1
  - secrets
  - sec-01
  - persistent_term
  - logger_json
  - redactor

# Dependency graph
requires:
  - phase: 01-foundation-durability-floor
    provides: LoggerJSON Basic formatter wired into `:default_handler`, `Kiln.Logger.Metadata.default_filter/2` filter slot, `ArgumentError`-on-missing convention from `Kiln.BootChecks`
  - phase: 02-workflow-engine-core
    provides: bounded-context SSOT pattern (13-context list in BootChecks + mix check_bounded_contexts), `config/config.exs` LoggerJSON block as the anchor for new registrations
  - phase: 03-agent-adapter-sandbox-dtu-safety
    plan: "00"
    provides: `test/support/fixtures/secrets/fake_keys.exs` (the `sk-ant-FAKE…` / `ghp_FAKE…` / `AIzaFAKE…` corpus the redactor tests exercise — not imported here but shapes match)

provides:
  - "Kiln.Secrets context facade (put/2, get/1, get!/1, reveal!/1, present?/1) over :persistent_term"
  - "%Kiln.Secrets.Ref{name: atom()} struct with @derive {Inspect, except: [:name]} + custom defimpl rendering #Secret<name>"
  - "Kiln.Logging.SecretRedactor @behaviour LoggerJSON.Redactor impl scrubbing 5 key-name substrings + 5 value-prefixes"
  - "config/config.exs registers redactor BOTH in :default_handler formatter tuple AND at top-level :logger_json :redactors key"
  - "D-133 Layers 1 + 2 + 4 of the six-layer redaction defense (Layer 3 + 5 applied by downstream Ecto schemas; Layer 6 is Wave 6 adversarial suite)"

affects:
  - 03-02 (Kiln.Blockers — :missing_api_key playbook calls Kiln.Secrets.present?/1)
  - 03-04 (FactoryCircuitBreaker — guards on LLM call failure but not on secret absence)
  - 03-05 (Kiln.Agents.Adapter.Anthropic — call_http/2 is the first Kiln.Secrets.reveal!/1 live site)
  - 03-06 (Pricing + BudgetGuard — no direct Secrets use but same D-131 boot-order)
  - 03-07 (Sandboxes.EnvBuilder — D-134 allowlist denies secret-named env vars, same provenance root)
  - 03-08 (adversarial secret-leak suite — Layer 6 greps against this module's redacted output)
  - 04-* (OpenAI + Google adapters — each adds a second + third Kiln.Secrets.reveal!/1 live site)

# Tech tracking
tech-stack:
  added: []  # no new deps — Kiln.Secrets is pure Elixir over :persistent_term; SecretRedactor uses the already-present logger_json 7.0 behaviour
  patterns:
    - "Reference-only secret store — facade returns `%Ref{}`; raw string produced only by `reveal!/1`. Grep audit target: Phase 3 must ship exactly 3 `Kiln.Secrets.reveal!/1` live call sites (one per remote-LLM adapter)."
    - "Custom `defimpl Inspect, for: %Struct{}` over `@derive {Inspect, except: [...]}` — the derive hides the field from the default printer, the custom impl renders a substantive human-readable token (`#Secret<name>`) that log-grep pipelines can assert shape on without leaking value."
    - "LoggerJSON redactor registered in TWO config locations — handler formatter tuple AND top-level `:logger_json :redactors` — so both the compile-time default handler AND any runtime-built formatter pick up the redactor without requiring the optional `new/1` callback."
    - "`:persistent_term.erase/1` + `:ok` as the nil-clear path — lets test `setup`/`on_exit` cycle the global VM store cleanly without a dedicated test-only escape hatch."

key-files:
  created:
    - "lib/kiln/secrets.ex — Kiln.Secrets context facade; put/2 + get/1 + get!/1 + reveal!/1 + present?/1"
    - "lib/kiln/secrets/ref.ex — %Kiln.Secrets.Ref{} struct + custom defimpl Inspect"
    - "lib/kiln/logging/secret_redactor.ex — LoggerJSON.Redactor impl (5 key substrings × 5 value prefixes)"
    - "test/kiln/secrets_test.exs — 14 tests covering put/get/reveal/present + Inspect emission"
    - "test/kiln/logging/secret_redactor_test.exs — 20 tests covering both triggers + pass-throughs + @behaviour conformance"
  modified:
    - "config/config.exs — registered Kiln.Logging.SecretRedactor under :default_handler formatter tuple AND at top-level :logger_json :redactors"

key-decisions:
  - "Dual registration of the redactor (handler-formatter tuple + top-level :logger_json app key) rather than a single top-level key — the formatter tuple form guarantees the current compile-time `LoggerJSON.Formatters.Basic` handler redacts on every log line; the top-level key guarantees any runtime-built formatter (config/runtime.exs, test harness overrides) picks it up too. Redactor is stateless, so dual registration is idempotent. Plan text suggested a single top-level key; expanded per D-133 Layer 4 intent + LoggerJSON 7.0 Redactor moduledoc."
  - "Custom `defimpl Inspect, for: Kiln.Secrets.Ref` renders `#Secret<name>` (exact literal, not `#Kiln.Secrets.Ref<...>`) — the `@derive {Inspect, except: [:name]}` alone would hide the value but still render the module path, leaking the fact that a Ref lives at this callsite. Plan PATTERNS §17 specified the `@derive` only; custom impl added for DX + grep-audit readability."
  - "Use `ArgumentError` (raised automatically by `:persistent_term.get/1` on missing key) rather than a custom `KeyError` — mirrors Phase 1's `Kiln.BootChecks` failure contract and avoids creating a new exception taxonomy for a one-off. Tests assert against `ArgumentError` accordingly."
  - "Test RED phase committed as a separate `test(...)` commit BEFORE the `feat(...)` GREEN commit for each of the two tasks — canonical TDD sequence (4 commits total: test→feat, test→feat). Preserves the plan-level TDD gate audit trail per the executor workflow."
  - "Redactor value-prefix rule matches only at string start (`String.starts_with?/2`) — a secret that appears mid-string in a free-form log message is not redacted. Rationale: a mid-string match would over-redact normal prose (`\"message containing sk-ant-...\"`) AND would still not catch arbitrary interpolation. The value-prefix rule is a belt-and-braces net for the unusual case where an operator stores a raw secret-prefix value in metadata; the primary protection is the key-name rule."

patterns-established:
  - "Custom `defimpl Inspect` over `@derive` when the struct's default render would itself leak context (module path, wrapper names). Future secret-like structs in Phase 4+ (model-registry snapshots, git-push credentials) should follow the same pattern."
  - "Two-site registration for LoggerJSON redactors — handler-level for the existing formatter + app-level for runtime-built formatters. Stateless redactors are safe to double-register."
  - "`:persistent_term.erase/1` as the standard test-cleanup path for `Kiln.Secrets.put/2` — no stateful Agent or ETS fixture required; the nil-clear overload makes `on_exit` a one-liner."

requirements-completed:
  - "SEC-01"

# Metrics
duration: 7min
completed: 2026-04-20
---

# Phase 3 Plan 01: Kiln.Secrets + Kiln.Logging.SecretRedactor Summary

**Reference-only secret store over `:persistent_term` (`put/get!/reveal!/present?`) plus a LoggerJSON.Redactor scrubbing five key-name substrings and five provider-specific value prefixes — D-133 Layers 1 + 2 + 4 of the six-layer secret-redaction defense.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-20T17:05:38Z (approximate — first plan read)
- **Completed:** 2026-04-20T17:13:19Z
- **Tasks:** 2 (each TDD: RED + GREEN)
- **Commits:** 4 (2 × `test`, 2 × `feat`)
- **Files modified:** 6 (5 created, 1 modified)
- **Tests:** 34/34 passing (14 secrets + 20 redactor); full suite 291/0 (5 excluded) — no regressions

## Accomplishments

- `Kiln.Secrets` context facade — write-once at boot, read via `%Ref{}` reference, sole raw-string boundary via `reveal!/1`
- `%Kiln.Secrets.Ref{}` struct with `@derive {Inspect, except: [:name]}` + custom `defimpl Inspect` rendering `#Secret<name>` (exact literal, grep-audit target)
- `Kiln.Logging.SecretRedactor` — `@behaviour LoggerJSON.Redactor` with 5 key substrings (`api_key`, `secret`, `token`, `authorization`, `bearer`) and 5 value prefixes (`sk-ant-`, `sk-proj-`, `ghp_`, `gho_`, `AIza`)
- `config/config.exs` dual registration — redactor wired into `:default_handler` formatter tuple AND at top-level `:logger_json :redactors` key
- `mix compile --warnings-as-errors` exits 0; `mix test` runs 291 tests green (257 baseline + 34 new)

## Task Commits

Each task was committed atomically with the canonical TDD test→feat pair:

1. **Task 1 RED: add failing tests for Kiln.Secrets reference store** — `b599134` (test)
2. **Task 1 GREEN: ship Kiln.Secrets + Ref struct on :persistent_term** — `f5d4e89` (feat)
3. **Task 2 RED: add failing tests for Kiln.Logging.SecretRedactor** — `5801685` (test)
4. **Task 2 GREEN: ship Kiln.Logging.SecretRedactor + register in config** — `197919b` (feat)

**Plan metadata commit:** pending (to be made by this executor once SUMMARY.md is in place).

## Files Created/Modified

### Created (5)

- `lib/kiln/secrets.ex` — context facade over `:persistent_term`; `put/2` + `get/1` + `get!/1` + `reveal!/1` + `present?/1`; `reveal!/1` is the sole raw-string boundary (grep-audit target)
- `lib/kiln/secrets/ref.ex` — `%Kiln.Secrets.Ref{name: atom()}`; `@derive {Inspect, except: [:name]}` + `defimpl Inspect, for: Kiln.Secrets.Ref` rendering `#Secret<name>`
- `lib/kiln/logging/secret_redactor.ex` — `@behaviour LoggerJSON.Redactor`; `cond`-dispatched `key_looks_secret?/1` (case-insensitive substring match) + `value_looks_secret?/1` (exact-start prefix match)
- `test/kiln/secrets_test.exs` — 14 tests: `put/present?` round-trip (inc. nil-clear idempotency), `get!/get` presence + absence, `reveal!/%Ref{}` vs atom, 3 Inspect rendering tests including a surrounding-container leak check + struct field-count audit
- `test/kiln/logging/secret_redactor_test.exs` — 20 tests: 5 atom key triggers + 3 mixed-case string key triggers + 3 substring match triggers + 5 value-prefix triggers + 1 mid-string non-trigger + 6 pass-throughs + 1 `@behaviour` conformance via `__info__/1`

### Modified (1)

- `config/config.exs` — added `redactors: [{Kiln.Logging.SecretRedactor, []}]` inside the existing `:default_handler` formatter tuple AND added a new top-level `config :logger_json, :redactors, [{Kiln.Logging.SecretRedactor, []}]` line

## Decisions Made

See frontmatter `key-decisions` for the five binding decisions. Highlights:

1. **Dual redactor registration** — both handler-level (inside the formatter tuple) and top-level app config. Stateless redactor, idempotent.
2. **Custom `defimpl Inspect` over `@derive`-only** — `@derive {Inspect, except: [:name]}` alone would render `#Kiln.Secrets.Ref<...>`, still leaking the module path; the custom impl renders exactly `#Secret<name>` for DX + grep-audit readability.
3. **`ArgumentError` (via `:persistent_term.get/1`) rather than a new `KeyError`** — reuses BEAM's built-in fail-loud path; no new exception taxonomy.
4. **TDD RED/GREEN committed as separate commits** per task — 4 commits total, preserves the plan-level TDD gate audit trail.
5. **Value-prefix rule is exact-start, not substring** — avoids over-redacting prose; the key-name rule is the primary net.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test-file ExUnit `test` name interpolation failed on `unquote`**

- **Found during:** Task 2 RED (first `mix test` run of `test/kiln/logging/secret_redactor_test.exs`)
- **Issue:** Plan's test template used `test "atom key #{inspect(unquote(key))} triggers redaction" do` inside a `for` comprehension. Elixir 1.19's `ExUnit.Case.test/2` macro expands the name string at `describe/test`-definition time (compile time), and the `unquote` there is not inside a `quote do...end` block, so the compiler raises `(CompileError) ... expanding macro: Kernel.to_string/1`. The plan's PATTERNS.md code assumed `unquote` would splice the generator variable; it does not in this context.
- **Fix:** Replaced the `unquote(key)` inside the test name with a plain `#{inspect(key)}` (the generator variable is directly in scope since the `for` is a module-level comprehension over a list literal) AND stashed the generator value in a module attribute (`@key key`, `@prefix prefix`) inside the `for` body so the `test` block body can reference it at runtime. Applied the same fix to the value-prefix `for` loop.
- **Files modified:** `test/kiln/logging/secret_redactor_test.exs`
- **Verification:** `mix test test/kiln/logging/secret_redactor_test.exs` — RED phase now shows 20 failing tests due to the missing target module (not a compile error); GREEN phase shows 20/20 passing.
- **Committed in:** `5801685` (Task 2 RED commit — the fix was applied before the RED commit landed)

### Auto-added Missing Critical Functionality

**2. [Rule 2 - Missing Critical] Inspect leak-check via surrounding-container test**

- **Found during:** Task 1 RED authoring
- **Issue:** Plan's Test 6 asserted `inspect(%Kiln.Secrets.Ref{name: :anthropic_api_key})` renders `#Secret<...>`. That proves the struct itself does not leak, but does NOT prove that when the Ref is wrapped in a map/list/struct, the outer container's inspect also does not leak via the default printer invoking the nested struct's derived Inspect. This is the realistic logging scenario (`Logger.debug(%{metadata: %{api_key: ref, ...}})`).
- **Fix:** Added a second Inspect test that wraps the Ref inside a 2-key map and asserts the rendered output (a) contains `#Secret<name>` and (b) does NOT contain the fake-key value. Plus a third test that audits the struct's field list has exactly `[:name]` — catching any accidental future `defstruct [:name, :value]` regression that would survive the other two tests.
- **Files modified:** `test/kiln/secrets_test.exs`
- **Verification:** All 3 Inspect tests pass against the shipped implementation.
- **Committed in:** `b599134` (Task 1 RED commit)

**3. [Rule 2 - Missing Critical] Missing-key behaviour asymmetry on `reveal!/1`**

- **Found during:** Task 1 GREEN implementation review
- **Issue:** Plan's Test 5 covered `reveal!(:missing_key)` raising on a bare atom. It did not cover the same case via a `%Ref{}` — an operator could construct a `%Kiln.Secrets.Ref{name: :not_there}` directly (not via `get!/1`) and call `reveal!/1` on it, which needs to raise the same way.
- **Fix:** Added a fourth `reveal!/1` test covering `reveal!(%Ref{name: :not_there_at_all})` raising `ArgumentError`. The shipped implementation routes `reveal!(%Ref{name: n})` through `reveal!(n)`, so the same `:persistent_term.get/1` ArgumentError is raised — no code change needed, but the test codifies the expectation.
- **Files modified:** `test/kiln/secrets_test.exs`
- **Verification:** Test passes.
- **Committed in:** `b599134` (Task 1 RED commit)

---

**Total deviations:** 3 auto-fixed (1 × Rule 1 bug in plan's test-template `unquote` usage, 2 × Rule 2 test-coverage additions for realistic leak scenarios)

**Impact on plan:** All three auto-fixes preserve the plan's public contract (modules, functions, @specs, redaction shapes). The Rule-1 fix was required for the test file to compile at all; the two Rule-2 additions strengthen the D-133 Layer 2 threat-model coverage without changing the implementation. No scope creep.

## Issues Encountered

- The Elixir 1.19 `ExUnit.Case.test/2` macro does not expand `unquote/1` splices in the `name` string when used inside a plain `for` comprehension. The plan's PATTERNS.md copy-ready template appears to assume otherwise. Fix is a module-attribute ping-pong (`@key key`) + plain `#{inspect(key)}` in the test-name string — documented above as Rule-1 deviation.
- `Kiln.Secrets.reveal!` greps `lib/` yields 4 hits against the pattern — ALL are docstring mentions inside `lib/kiln/secrets.ex` and `lib/kiln/secrets/ref.ex`. Zero live call sites exist, which matches the plan's verification expectation ("should be 0 in this plan; Wave 2/3 ships 3 sites"). The plan's grep command is actually too loose to be meaningful; Wave 5 will ship a compile-time auditor per D-133 that discriminates docstring mentions from live calls.

## Threat Flags

None. Implementation matches the declared `<threat_model>`:

- **T-03-01-01** (Ref leaked in log line): mitigated by custom `defimpl Inspect` + the added surrounding-container test.
- **T-03-01-02** (raw key persisted): mitigated by the type-system boundary — `%Ref{}` has exactly one field (`:name`), audited by a dedicated test.
- **T-03-01-03** (secret-shaped value in metadata): mitigated by the redactor's 5 key-substrings + 5 value-prefixes; 20 tests exercise every positive + negative path.

No new threat surface introduced. No new network endpoints, no new auth paths, no new file access, no schema changes.

## User Setup Required

None — no external service configuration required. Kiln.Secrets writes happen at boot via `config/runtime.exs`, which Phase 3 Wave 2 (plan 03-05) lands. The redactor is a pure stateless module registered in compile-time config.

## Next Phase Readiness

**Unblocks:**

- Plan 03-05 (Kiln.Agents.Adapter.Anthropic) — the first live `Kiln.Secrets.reveal!/1` call site can be wired directly against this module.
- Plan 03-02 (Kiln.Blockers `:missing_api_key` playbook) — calls `Kiln.Secrets.present?/1` to decide whether to emit the blocker.
- Plan 03-07 (Kiln.Sandboxes.EnvBuilder) — the D-134 env-allowlist denies any key matching the redactor's `@secret_key_substrings` list; the constant can be extracted + shared at that time.
- Future waves 4, 5, 6 — the adversarial secret-leak suite (plan 03-08) will assert the redactor produces `"**redacted**"` against the `test/support/fixtures/secrets/fake_keys.exs` corpus shipped by plan 03-00.

**No blockers.** Compile is clean, full suite green, dep tree untouched.

**Concerns:** The plan's grep-check for `Kiln.Secrets.reveal!` in `lib/` is loose — it counts docstring mentions. A stricter grep (e.g. `grep -n "^[^#]*Kiln\.Secrets\.reveal!"` or the D-133 compile-time auditor in Wave 5) would be more meaningful. Flagged for the plan-check pass on Wave 2/3/4 plans that consume `reveal!/1`.

## Self-Check: PASSED

Verified after writing SUMMARY.md:

- [x] `lib/kiln/secrets.ex` exists and contains `@spec put(atom(), binary() | nil) :: :ok`, `@spec reveal!(Ref.t() | atom()) :: binary()`, `@spec present?(atom()) :: boolean()`, `:persistent_term.put/2`, `:persistent_term.get/1`, `:persistent_term.erase/1` (file grep confirmed)
- [x] `lib/kiln/secrets/ref.ex` exists and contains `defstruct [:name]`, `@derive {Inspect, except: [:name]}`, `defimpl Inspect, for: Kiln.Secrets.Ref`
- [x] `lib/kiln/logging/secret_redactor.ex` exists and contains `@behaviour LoggerJSON.Redactor`, `@impl LoggerJSON.Redactor`, `@secret_key_substrings ~w(api_key secret token authorization bearer)`, `@secret_value_prefixes ~w(sk-ant- sk-proj- ghp_ gho_ AIza)`
- [x] `config/config.exs` contains `Kiln.Logging.SecretRedactor` (3 occurrences: 2 tuple registrations + 1 comment)
- [x] `mix test test/kiln/secrets_test.exs test/kiln/logging/secret_redactor_test.exs` reports `34 tests, 0 failures`
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test` full suite reports `291 tests, 0 failures (5 excluded)` — no regressions from 257 baseline
- [x] Task commits exist: `b599134`, `f5d4e89`, `5801685`, `197919b` (verified via `git log --oneline c8cddd4..HEAD`)
- [x] `inspect(%Kiln.Secrets.Ref{name: :foo})` renders exactly `#Secret<foo>` (verified via `mix run --no-start`)

---

*Phase: 03-agent-adapter-sandbox-dtu-safety*
*Completed: 2026-04-20*
