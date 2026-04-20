# Phase 3 Wave 0: load Mox defmocks BEFORE `ExUnit.start/1` so every
# test module observes the mocks at compile + run time. See
# `test/support/mocks.ex` for the defmock registry.
#
# `test/support/mocks.ex` is also auto-compiled via `elixirc_paths(:test)`
# in `mix.exs`, so its top-level `Mox.defmock/2` calls have already run
# by the time this file executes. The registration code is idempotent
# (guarded with `unless Code.ensure_loaded?(mock_name)`) so the
# `Code.require_file` below is a belt-and-braces re-entry — if the file
# has already been loaded, each guard short-circuits without producing
# "redefining module" warnings.
Code.require_file("support/mocks.ex", __DIR__)

ExUnit.start(
  exclude: [
    # Docker-gated integration suites (SandboxCase / DtuCase) — require a
    # Docker daemon on PATH.
    :docker,
    :dtu,
    # General integration umbrella — opt-in via `mix test --include integration`.
    :integration,
    # Live LLM-provider tests — burn a real PAT when run. Opt-in only.
    :live_anthropic,
    :live_openai,
    :live_google,
    :live_ollama,
    # Adversarial suites — costly to run; opt-in under `mix kiln.sandbox.adversarial`.
    :adversarial_egress,
    :secret_leak_hunt,
    :budget_overrun
  ]
)

Ecto.Adapters.SQL.Sandbox.mode(Kiln.Repo, :manual)

# Start Credo so custom-check tests can use `Credo.Test.Case` helpers,
# which rely on `Credo.Service.SourceFileAST` and friends being alive.
{:ok, _} = Application.ensure_all_started(:credo)
