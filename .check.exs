# ex_check 0.16 configuration for Kiln.
#
# This is the SINGLE ENTRY POINT for Kiln's CI gate — both locally (`mix check`)
# and in GitHub Actions. Anything added here runs in both places identically.
# See .planning/phases/01-foundation-durability-floor/01-CONTEXT.md D-22..D-30.
#
# Tools are listed in rough cost order: cheap format/compile checks first so
# failures surface quickly; Dialyzer (expensive, cold-cache ~5-10 min) near
# the end so cheaper gates break early.

[
  # Serial execution avoids `_build` lock contention between `mix dialyzer`,
  # `mix compile`, and `mix test`, which otherwise surfaces as flaky Repo /
  # Sandbox startup failures under `mix check`.
  parallel: false,
  skipped: false,
  fix: false,
  retry: false,
  tools: [
    # Drop stale generated spec scenarios (gitignored); leftover `assert false`
    # fixtures break `mix test --include kiln_scenario` and confuse the format gate.
    # Shell `rm` avoids a `mix run` round-trip that would compile `:dev` while
    # the rest of `mix check` runs under `MIX_ENV=test` (CI + local).
    {:prune_generated_scenarios, "rm -rf test/generated/kiln_scenarios"},

    # ---- Hard format gate ----
    {:formatter, "mix format --check-formatted"},

    # ---- Hard compile gate — no warnings allowed ----
    {:compiler, "mix compile --warnings-as-errors --all-warnings"},

    # Dialyzer must run before ExUnit: its analysis pass recompiles/consolidates
    # artifacts in a way that breaks Ecto SQL Sandbox + Repo if tests run first
    # (repro: `mix test && mix dialyzer && mix test` → mass Repo lookup failures).
    #
    # ex_check keeps the **default** tool order (see `ExCheck.Config.Default`) when
    # merging `.check.exs` — `ex_unit` is still scheduled before `dialyzer` unless we
    # declare an explicit dependency edge:
    {:dialyzer, "mix dialyzer"},

    # ---- Full ExUnit suite ----
    {:ex_unit, "mix test", deps: [:dialyzer]},

    # `scenario_compiler_test` writes throwaway modules under `test/generated/`; a
    # second full-suite pass with `--include kiln_scenario` would pick up stray
    # `assert false` files and fail unless we prune between runs.
    {:prune_generated_scenarios_after_unit, "rm -rf test/generated/kiln_scenarios"},

    # ---- Generated spec scenarios (UAT-01 / SPEC-02): `@moduletag :kiln_scenario`
    #     tests are excluded by default in test_helper — run them explicitly here
    #     so CI exercises holdouts + compiled scenario modules.
    {:ex_unit_kiln_scenarios, "mix test --include kiln_scenario"},

    # ---- Credo strict (includes Kiln.Credo.NoProcessPut +
    #      Kiln.Credo.NoMixEnvAtRuntime + credo_envvar + ex_slop) ----
    {:credo, "mix credo"},

    # ---- Sobelow HIGH-only with --mark-skip-all baseline (.sobelow-skips) ----
    {:sobelow, "mix sobelow --skip --threshold high --exit"},

    # ---- mix_audit fail-on-any (allowlist in .mix_audit.exs) ----
    {:mix_audit, "mix deps.audit"},

    # ---- xref cycles gate (no-op until P2 contexts exist;
    #      activates the 12-context DAG discipline early).
    #      Uses --label compile-connected per Elixir's xref docs
    #      — runtime cycles in the Phoenix scaffold
    #      (router<->controllers<->layouts) are harmless; compile-time
    #      cycles are the recompilation tax we actually want to catch. ----
    {:xref_cycles, "mix xref graph --format cycles --label compile-connected --fail-above 0"},

    # ---- Kiln-specific grep gates (D-26) ----
    {:no_compile_secrets, "mix check_no_compile_time_secrets"},
    {:no_manual_qa, "mix check_no_manual_qa_gates"},

    # ---- Phase 2 D-65: no v1 workflow populates the reserved
    #      `signature:` top-level key (workflow signing defers to v2
    #      WFE-02; sign via `git commit -S` for v1). Scans
    #      priv/workflows/*.yaml; test-support fixtures are out of scope. ----
    {:no_signature_block, "mix check_no_signature_block"},

    # ---- Phase 2 D-97: 13 bounded contexts (was 12 in P1; Plan 02-03
    #      admitted Kiln.Artifacts as the 13th). Gate is ACTIVE as of
    #      Plan 02-07 Task 2: Kiln.BootChecks.@context_modules was
    #      extended from 12 → 13 in lockstep with the Mix task's
    #      @expected list, so the two SSOTs are in sync and
    #      `mix check_bounded_contexts` asserts the 13-context
    #      invariant on every CI build (Plan 02-04 shipped the source
    #      with deferred activation per checker issue #5 option (b);
    #      Plan 02-07 is the paired activation). ----
    {:bounded_contexts, "mix check_bounded_contexts"},

    # ---- Plan 06 / D-34: boot-time invariants (REVOKE + trigger + contexts + secrets).
    #      Runs the same `Kiln.BootChecks.run!/0` the Application.start/2
    #      flow calls, so CI and local get identical "durability floor
    #      intact?" signal. Depends on a live Postgres (CI provides one
    #      via the `postgres:16` service container). ----
    {:kiln_boot_checks, "mix kiln.boot_checks"}
  ]
]
