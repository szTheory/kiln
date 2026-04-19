defmodule Kiln.Credo.NoMixEnvAtRuntime do
  @moduledoc false
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      `Mix.env()` at runtime is banned (CLAUDE.md Elixir anti-patterns). Mix is
      unavailable in release builds — `Mix.env/0` at runtime raises
      `UndefinedFunctionError`. Use `Application.get_env(:kiln, :env)`, set from
      `config/*.exs`, or runtime-config flags in `config/runtime.exs`.
      """
    ]

  alias Credo.Code
  alias Credo.IssueMeta
  alias Credo.SourceFile

  @impl true
  def run(%SourceFile{filename: filename} = source_file, params \\ []) do
    # Allow Mix.env() inside the mix.exs project file (compile-time project config).
    if Path.basename(filename) == "mix.exs" do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp traverse(
         {{:., _, [{:__aliases__, _, [:Mix]}, :env]}, meta, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast, [issue_for(issue_meta, meta[:line]) | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line) do
    format_issue(issue_meta,
      message:
        "Mix.env/0 is unavailable in releases — use Application.get_env(:kiln, :env) instead.",
      line_no: line
    )
  end
end
