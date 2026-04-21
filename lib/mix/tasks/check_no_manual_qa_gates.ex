defmodule Mix.Tasks.CheckNoManualQaGates do
  @moduledoc """
  UAT-02 — fail the build if forbidden “manual QA gate” tokens appear in
  application code paths (`lib/kiln/**/*.ex`, `lib/kiln_web/**/*.ex`).

  Matches are suppressed for files whose **relative path** contains any
  non-comment line from `priv/qa_gate_allowlist.txt` (substring match).
  """

  use Mix.Task

  @shortdoc "Reject manual-review escape hatches in Kiln code paths"

  @patterns [
    ~r/MANUAL_REVIEW/,
    ~r/ASK_HUMAN/,
    ~r/ASK-HUMAN/,
    ~r/manual\s+review/i
  ]

  @scan_roots ["lib/kiln", "lib/kiln_web"]

  @impl Mix.Task
  def run(_args) do
    allow = load_allowlist()

    hits =
      Enum.flat_map(@scan_roots, fn root ->
        root
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.flat_map(fn path ->
          if File.regular?(path) and not allowlisted?(path, allow) do
            scan_lines(path)
          else
            []
          end
        end)
      end)

    case hits do
      [] ->
        Mix.shell().info("check_no_manual_qa_gates: OK (no banned tokens)")
        :ok

      _ ->
        Mix.shell().error("check_no_manual_qa_gates: banned token(s) found:\n")

        for {path, line_no, pat, text} <- hits do
          Mix.shell().error("  #{path}:#{line_no}  #{inspect(pat.source)}  #{text}")
        end

        exit({:shutdown, 1})
    end
  end

  defp scan_lines(path) do
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Enum.flat_map(fn {line, ln} ->
      for pat <- @patterns, Regex.match?(pat, line), do: {path, ln, pat, String.trim(line)}
    end)
  end

  defp load_allowlist do
    p = Path.join(["priv", "qa_gate_allowlist.txt"])

    if File.exists?(p) do
      p
      |> File.read!()
      |> String.split("\n", trim: false)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    else
      []
    end
  end

  defp allowlisted?(rel_path, allow) do
    Enum.any?(allow, fn token -> String.contains?(rel_path, token) end)
  end
end
