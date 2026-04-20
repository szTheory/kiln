defmodule Mix.Tasks.CheckNoSignatureBlock do
  @moduledoc """
  `mix check_no_signature_block` — Fails when any workflow YAML under
  `priv/workflows/*.yaml` has a top-level `signature:` populated with a
  non-null value.

  D-65 (Phase 2 CONTEXT.md) defers workflow signing to v2 (WFE-02) and
  reserves the `signature:` top-level key as `null` for all v1 workflows
  (sign via `git commit -S` instead — workflows live in the operator's
  own git repo, so git provides the v1 chain-of-custody). Any v1 workflow
  populating `signature:` is a signature-leak bug caught loudly at CI
  time here, mirroring the Phase 1 `mix check_no_compile_time_secrets`
  (D-26) pattern.

  Emits exit 0 when no offenders are found; exit 1 (via
  `{:shutdown, 1}`) plus a per-file listing on violation.

  The glob is strictly `priv/workflows/*.yaml` — test fixtures under
  `test/support/fixtures/workflows/` are deliberately out of scope so
  Plan 02-00's `signature_populated.yaml` rejection fixture doesn't
  trip the gate.
  """

  use Mix.Task

  @shortdoc "Assert no v1 workflow YAML has a non-null signature block."

  @workflows_glob "priv/workflows/*.yaml"

  @impl Mix.Task
  def run(_args) do
    # Starting :yaml_elixir is idempotent and keeps the task runnable
    # from a cold `iex -S mix` without `Mix.Task.run("app.start")`.
    Application.ensure_all_started(:yaml_elixir)

    offenders =
      @workflows_glob
      |> Path.wildcard()
      |> Enum.filter(&signature_populated?/1)

    case offenders do
      [] ->
        Mix.shell().info("check_no_signature_block: OK — no v1 workflow populates signature")
        :ok

      [_ | _] = files ->
        Mix.shell().error(
          "check_no_signature_block: VIOLATION — the following files have a non-null " <>
            "signature block (D-65 reserves signature: null for v1; sign via " <>
            "`git commit -S` instead):"
        )

        Enum.each(files, fn f -> Mix.shell().error("  - #{f}") end)
        exit({:shutdown, 1})
    end
  end

  defp signature_populated?(path) do
    # YamlElixir.read_from_file/2 defaults to `atoms: false` (string
    # keys). Do NOT override that default — atom-table exhaustion risk
    # per D-63 / threat-model T3.
    case YamlElixir.read_from_file(path) do
      {:ok, map} when is_map(map) ->
        case Map.get(map, "signature") do
          nil -> false
          _ -> true
        end

      _ ->
        # Unparseable YAMLs aren't this gate's concern — the workflow
        # loader (Plan 02-02+) owns YAML-shape rejection.
        false
    end
  end
end
