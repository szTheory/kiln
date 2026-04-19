defmodule Kiln.Credo.NoProcessPut do
  @moduledoc false
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      `Process.put/1,2` is banned by the Kiln project (CLAUDE.md → Conventions →
      Elixir-specific anti-patterns). Use explicit threading or function args
      for state; use `Kiln.Telemetry.pack_ctx/0` / `unpack_ctx/1` for cross-process
      context propagation.
      """
    ]

  alias Credo.Code
  alias Credo.IssueMeta
  alias Credo.SourceFile

  @impl true
  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)
    Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  defp traverse(
         {{:., _, [{:__aliases__, _, [:Process]}, :put]}, meta, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast, [issue_for(issue_meta, meta[:line]) | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line) do
    format_issue(issue_meta,
      message: "Process.put/* is banned — use explicit threading (Kiln.Telemetry.pack_ctx/0).",
      line_no: line
    )
  end
end
