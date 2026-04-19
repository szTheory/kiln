defmodule Mix.Tasks.Kiln.BootChecks do
  @moduledoc """
  Runs `Kiln.BootChecks.run!/0` from CI (D-34 — CI parity). Exits
  non-zero on any violated invariant. Wired into `.check.exs` so the
  `mix check` meta-runner calls it locally, AND into the GitHub
  Actions `ci.yml` as a dedicated step so a failure surfaces in its
  own log section.

  Typically you never call this directly — `mix check` runs it as part
  of the full gate. The task exists as a dedicated entry point because
  BootChecks asserts the DB state (REVOKE + trigger) which is a
  distinct signal from the compile / lint / type checks earlier in the
  ex_check pipeline.
  """
  use Mix.Task

  @shortdoc "Run Kiln boot-time invariant assertions (CI parity — D-34)."

  @impl true
  def run(_args) do
    # `app.start` boots the full Kiln supervision tree. BootChecks
    # ALREADY ran during `Kiln.Application.start/2`, so by this line
    # the invariants passed. We re-assert here to give CI a dedicated
    # positive log line + to cover the edge case where the task is
    # invoked with `--no-start` (not supported — task documented as
    # requiring the app).
    Mix.Task.run("app.start")

    try do
      Kiln.BootChecks.run!()
      Mix.shell().info("kiln.boot_checks: OK — all invariants satisfied")
    rescue
      e in Kiln.BootChecks.Error ->
        Mix.shell().error(Exception.message(e))
        Mix.raise("kiln.boot_checks failed")
    end
  end
end
