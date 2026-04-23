defmodule Mix.Tasks.Kiln.Ui.Lint do
  @moduledoc """
  `mix kiln.ui.lint` — Hard gate that fails when any retired Phase-reskin
  token reappears in `lib/kiln_web/**/*.{ex,heex}` or `assets/css/app.css`.

  Paired with `test/kiln_web/live/route_smoke_test.exs` (which checks
  rendered HTML per route): this task checks **source** so regressions
  caught at the template/string level surface even on files a LiveView
  test doesn't exercise.

  Fails on any match for:

    * `text-bone`, `text-ember`
    * `border-ash`, `border-clay`, `border-ember`
    * `bg-char`, `bg-iron`
    * `text-[var(--color-smoke)]`, `text-[var(--color-clay)]`
    * `kiln-btn` (any variant — the family was retired in favor of daisy `btn`)

  The check is pure string scan — no regex back-references — so runtime
  is O(files) with negligible overhead (<200ms for the `kiln_web` tree).

  Exit codes:
    * 0 — no offenders
    * 1 — one or more offenders, with vimgrep-style (`path:line:col: …`) listing

  Opt-out for a specific file: add an `# kiln-ui-lint:allow` marker on
  the same line; useful for historical HEEx comments that intentionally
  mention a retired token.
  """

  use Mix.Task

  @shortdoc "Fail when retired Phase-reskin tokens reappear in lib/kiln_web or assets/css"

  @retired_tokens [
    "text-bone",
    "text-ember",
    "border-ash",
    "border-clay",
    "border-ember",
    "bg-char",
    "bg-iron",
    "text-[var(--color-smoke)]",
    "text-[var(--color-clay)]",
    "kiln-btn"
  ]

  @scan_globs [
    "lib/kiln_web/**/*.ex",
    "lib/kiln_web/**/*.heex",
    "assets/css/app.css"
  ]

  @allow_marker "kiln-ui-lint:allow"

  @impl Mix.Task
  def run(_args) do
    offenders =
      @scan_globs
      |> Enum.flat_map(&Path.wildcard/1)
      |> Enum.flat_map(&scan_file/1)

    case offenders do
      [] ->
        Mix.shell().info(
          "kiln.ui.lint: OK — no retired reskin tokens in lib/kiln_web or assets/css"
        )

        :ok

      [_ | _] = matches ->
        Mix.shell().error(
          "kiln.ui.lint: VIOLATION — the following lines reference retired Phase-reskin tokens. " <>
            "Use daisy/Kiln semantic tokens instead " <>
            "(base-100/200/300, primary, warning, error; daisy `btn`/`card card-bordered`)."
        )

        Enum.each(matches, fn {path, line_no, col, token, line} ->
          Mix.shell().error("  #{path}:#{line_no}:#{col}: `#{token}` → #{String.trim(line)}")
        end)

        Mix.shell().error(
          "\n  allow one line intentionally: add `# #{@allow_marker}` on the same line"
        )

        exit({:shutdown, 1})
    end
  end

  defp scan_file(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_no} ->
      if allow?(line), do: [], else: line_offenders(path, line, line_no)
    end)
  end

  defp allow?(line), do: String.contains?(line, @allow_marker)

  defp line_offenders(path, line, line_no) do
    Enum.flat_map(@retired_tokens, fn token ->
      case :binary.match(line, token) do
        {col, _} -> [{path, line_no, col + 1, token, line}]
        :nomatch -> []
      end
    end)
  end
end
