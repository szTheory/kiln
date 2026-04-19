defmodule Mix.Tasks.CheckNoCompileTimeSecrets do
  @moduledoc """
  Fail if any compile-time config file (`config/config.exs`, `config/dev.exs`,
  `config/prod.exs`, `config/test.exs`) reads environment variables via
  `System.get_env` or `System.fetch_env!`. Env-var reads must live only in
  `config/runtime.exs`.

  Mitigates T-02 (compile-time secrets leakage). Wired into `mix check` via
  `.check.exs` so the grep gate runs on every CI build.
  """

  use Mix.Task

  @shortdoc "Fail if config/*.exs (non-runtime) reads env vars (T-02)."

  @files ~w(config/config.exs config/dev.exs config/prod.exs config/test.exs)

  @impl Mix.Task
  def run(_args) do
    offenders =
      @files
      |> Enum.filter(&File.exists?/1)
      |> Enum.flat_map(&scan_file/1)

    case offenders do
      [] ->
        :ok

      list ->
        detail =
          list
          |> Enum.map(fn {file, line_no, line} -> "  #{file}:#{line_no}  #{line}" end)
          |> Enum.join("\n")

        Mix.raise(
          "Compile-time secret read detected (move to config/runtime.exs):\n" <> detail
        )
    end
  end

  defp scan_file(path) do
    path
    |> File.stream!()
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _index} ->
      String.contains?(line, "System.get_env") or
        String.contains?(line, "System.fetch_env!")
    end)
    |> Enum.map(fn {line, index} -> {path, index, String.trim(line)} end)
  end
end
