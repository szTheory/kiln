defmodule Mix.Tasks.CheckBoundedContexts do
  @moduledoc """
  `mix check_bounded_contexts` — Asserts that the 13 expected bounded-
  context modules are compiled and loaded (per D-97 / CLAUDE.md spec
  upgrade that admits `Kiln.Artifacts` as the 13th context).

  Was 12 in Phase 1; Plan 02-03 shipped `Kiln.Artifacts` (content-
  addressed storage, genuinely orthogonal to stage execution), and
  Plan 02-04 ships this Mix task's source file so the CI gate itself
  is ready.

  Activation deferred: the FIRST CI-gate invocation of this task
  happens in Plan 02-07 Task 2, which also extends
  `Kiln.BootChecks.@context_modules` from 12 to 13 (the two pointers
  to the 13-context SSOT must stay in sync; Plan 02-07 lands both in
  the same change).

  The task compiles cleanly now because `Code.ensure_loaded?/1` is a
  runtime call, not a compile-time dependency — the Wave 1 parallel
  execution safely ships the source file without activating the gate
  (see 02-04-PLAN.md `<objective>` / checker issue #5 option (b)).

  13 expected context modules:

      Kiln.Specs, Kiln.Intents, Kiln.Workflows, Kiln.Runs, Kiln.Stages,
      Kiln.Agents, Kiln.Sandboxes, Kiln.GitHub, Kiln.Audit,
      Kiln.Telemetry, Kiln.Policies, Kiln.ExternalOperations,
      Kiln.Artifacts

  Emits exit 0 when all 13 are compiled-and-loaded; exit 1 (via
  `{:shutdown, 1}`) plus a per-module listing on drift.
  """

  use Mix.Task

  @shortdoc "Assert 13 bounded contexts compiled; no drift."

  # One module per line — the 13-context SSOT is visually auditable and
  # `grep -c "Kiln\." lib/mix/tasks/check_bounded_contexts.ex` returns a
  # meaningful line-count (acceptance criterion: >= 13).
  @expected ~w(
    Kiln.Specs
    Kiln.Intents
    Kiln.Workflows
    Kiln.Runs
    Kiln.Stages
    Kiln.Agents
    Kiln.Sandboxes
    Kiln.GitHub
    Kiln.Audit
    Kiln.Telemetry
    Kiln.Policies
    Kiln.ExternalOperations
    Kiln.Artifacts
  )

  @impl Mix.Task
  def run(_args) do
    # Force a fresh compile so the check doesn't get fooled by stale
    # beams left behind after a rename/delete. Harmless when invoked
    # from the CI entry point (`mix check`) — compile will be a no-op.
    Mix.Task.run("compile")

    expected_mods = Enum.map(@expected, fn name -> Module.concat([name]) end)

    missing = Enum.reject(expected_mods, &Code.ensure_loaded?/1)

    case missing do
      [] ->
        Mix.shell().info(
          "check_bounded_contexts: OK — #{length(expected_mods)} contexts compiled"
        )

        :ok

      mods ->
        Mix.shell().error(
          "check_bounded_contexts: VIOLATION — the following bounded-context modules " <>
            "did not compile/load (expected per D-97; see CLAUDE.md Architecture):"
        )

        Enum.each(mods, fn m -> Mix.shell().error("  - #{inspect(m)}") end)
        exit({:shutdown, 1})
    end
  end
end
