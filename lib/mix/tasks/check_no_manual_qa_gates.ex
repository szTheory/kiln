defmodule Mix.Tasks.CheckNoManualQaGates do
  @moduledoc """
  Stub in Phase 1 (Plan 02) — full enforcement lands in Phase 5 (UAT-01).

  Future behavior: grep `lib/` for `TODO|FIXME|ASK-HUMAN` markers in code
  paths that would pause a run for human review. Any such marker is a Kiln
  bug (CLAUDE.md: "zero manual QA"). See also `ROADMAP.md` Phase 5.
  """

  use Mix.Task

  @shortdoc "[stub — Phase 5 fleshes out for UAT-01]"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info(
      "check_no_manual_qa_gates: stub — full enforcement in Phase 5 (UAT-01)"
    )

    :ok
  end
end
