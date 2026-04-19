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
    # Allow Mix.env() inside mix.exs (project config) AND inside
    # config/*.exs (compile-time app config — Config import is evaluated
    # at compile time, not runtime). Plan 06 adds `env: Mix.env()` to
    # config/config.exs so `Kiln.BootChecks.run!/0` can read a runtime
    # :kiln, :env value via `Application.get_env/3`.
    if compile_time_config_file?(filename) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  # mix.exs OR any file under config/ (matching both "config/foo.exs" and
  # "./config/foo.exs" absolute forms Credo may pass). Normalise with
  # `Path.split/1` so the check is separator-agnostic.
  defp compile_time_config_file?(filename) do
    if Path.basename(filename) == "mix.exs" do
      true
    else
      segments = filename |> Path.split()
      "config" in segments
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
