defmodule Kiln.Diagnostics.Snapshot do
  @moduledoc """
  OPS-05 — server-side diagnostic **zip** bundles (last 60 minutes window).

  Assembles a small manifest plus redacted sample payloads. Callers receive a
  **temp-file path** and should `File.rm/1` after `send_download` (or hand off
  to short-lived cleanup).
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Runs.Run

  @redacted "[REDACTED]"

  @doc """
  Builds a zip in `System.tmp_dir!/0` named `kiln-diagnostic-<random>.zip`.

  Options:

    * `:run_id` — required; always included in the manifest and log slice.
    * `:sample_log` — optional binary merged into `redacted-sample.log` (for tests).

  Returns `{:ok, path}` on success. Redacts `sk-ant-api…`, `sk-…`, `ghp_…`, `xoxb-…`
  lines to the literal `"[REDACTED]"` token.
  """
  @spec build_zip(keyword()) :: {:ok, String.t()} | {:error, term()}
  def build_zip(opts) when is_list(opts) do
    run_id = Keyword.fetch!(opts, :run_id)
    sample = Keyword.get(opts, :sample_log, "")

    since = DateTime.add(DateTime.utc_now(:microsecond), -60, :minute)

    run_ids =
      from(r in Run,
        where: r.id == ^run_id or r.inserted_at >= ^since,
        select: r.id,
        limit: 100
      )
      |> Repo.all()

    manifest = %{
      "generated_at" => DateTime.utc_now(:microsecond) |> DateTime.to_iso8601(),
      "window_minutes" => 60,
      "run_ids" => Enum.map(run_ids, &to_string/1),
      "config_paths" => ["config/runtime.exs (not bundled — redacted manifest only)"]
    }

    raw_log =
      [
        "Kiln diagnostic slice (redacted)\n",
        "run_id=#{run_id}\n",
        sample
      ]
      |> IO.iodata_to_binary()

    redacted_log = redact_text(raw_log)

    entries = [
      {~c"manifest.json", Jason.encode!(manifest)},
      {~c"redacted-sample.log", redacted_log}
    ]

    tmp =
      Path.join(
        System.tmp_dir!(),
        "kiln-diagnostic-#{:rand.uniform(1_000_000_000)}.zip"
      )

    case :zip.create(String.to_charlist(tmp), entries, []) do
      :ok -> {:ok, tmp}
      {:ok, _} -> {:ok, tmp}
      err -> {:error, err}
    end
  end

  @doc false
  @spec redact_text(String.t()) :: String.t()
  def redact_text(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&redact_line/1)
    |> Enum.join("\n")
  end

  defp redact_line(line) do
    line
    |> replace(~r/sk-ant-api[^\s]*/i)
    |> replace(~r/\bsk-[A-Za-z0-9_-]{8,}/i)
    |> replace(~r/ghp_[A-Za-z0-9]+/)
    |> replace(~r/xoxb-[A-Za-z0-9-]+/)
  end

  defp replace(line, %Regex{} = re) do
    Regex.replace(re, line, @redacted)
  end
end
