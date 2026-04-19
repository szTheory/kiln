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
  parallel: true,
  skipped: false,
  fix: false,
  retry: false,
  tools: [
    # ---- Hard format gate ----
    {:formatter, "mix format --check-formatted"},

    # ---- Hard compile gate — no warnings allowed ----
    {:compiler, "mix compile --warnings-as-errors --all-warnings"},

    # ---- Full ExUnit suite ----
    {:ex_unit, "mix test"},

    # ---- Credo strict (includes Kiln.Credo.NoProcessPut +
    #      Kiln.Credo.NoMixEnvAtRuntime + credo_envvar + ex_slop) ----
    {:credo, "mix credo --strict"},

    # ---- Dialyzer fail-on-warning (PLT cached in priv/plts) ----
    {:dialyzer, "mix dialyzer"},

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
    {:no_manual_qa, "mix check_no_manual_qa_gates"}
  ]
]
