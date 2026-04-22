defmodule Mix.Tasks.Templates.Verify do
  @moduledoc """
  Verifies every built-in template in `priv/templates/manifest.json`:

    * `spec.md` (or configured `spec_file`) is non-empty UTF-8
    * authoring `workflow_file` loads via `Kiln.Workflows.load/1` and its
      compiled `id` matches the manifest `workflow_id`
    * `priv/workflows/<workflow_id>.yaml` exists for dispatcher parity

  Wired into `mix precommit` and `.check.exs` (see `mix.exs` / `.check.exs`).
  """
  use Mix.Task

  @shortdoc "Verify shipped built-in templates (manifest + workflow compile)"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    entries = Kiln.Templates.list()

    Enum.each(entries, &verify_entry!/1)

    Mix.shell().info("templates.verify: OK — #{length(entries)} template(s)")
  end

  defp verify_entry!(entry) do
    case Kiln.Templates.read_spec(entry.id) do
      {:ok, spec} ->
        if String.trim(spec) == "" do
          Mix.raise("templates.verify: empty spec for template #{entry.id}")
        end

      {:error, reason} ->
        Mix.raise("templates.verify: cannot read spec for #{entry.id}: #{inspect(reason)}")
    end

    authoring =
      Path.join([
        Application.app_dir(:kiln, "priv/templates"),
        entry.id,
        entry.workflow_file
      ])

    unless File.exists?(authoring) do
      Mix.raise("templates.verify: missing authoring workflow #{authoring}")
    end

    case Kiln.Workflows.load(authoring) do
      {:ok, cg} ->
        if cg.id != entry.workflow_id do
          Mix.raise(
            "templates.verify: workflow id mismatch for #{entry.id} — manifest workflow_id=#{inspect(entry.workflow_id)} compiled id=#{inspect(cg.id)}"
          )
        end

      {:error, reason} ->
        Mix.raise(
          "templates.verify: Kiln.Workflows.load/1 failed for #{entry.id}: #{inspect(reason)}"
        )
    end

    shipped = Kiln.Templates.shipped_workflow_yaml_path(entry.workflow_id)

    unless File.exists?(shipped) do
      Mix.raise(
        "templates.verify: missing shipped dispatcher workflow #{shipped} (manifest workflow_id=#{entry.workflow_id})"
      )
    end
  end
end
