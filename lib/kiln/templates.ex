defmodule Kiln.Templates do
  @moduledoc """
  Built-in template catalog (Phase 17 — WFE-01 / ONB-01).

  Template bodies and metadata are shipped under `priv/templates/` with
  `priv/templates/manifest.json` as the **sole authority** for valid
  `template_id` values. Callers must resolve IDs through `fetch/1` before
  joining paths — never join untrusted strings into `priv/`.
  """

  alias Kiln.Templates.Manifest
  alias Kiln.Templates.Manifest.Entry

  @type entry :: Entry.t()

  @doc """
  Returns all manifest entries sorted by `id`.
  """
  @spec list() :: [entry()]
  def list do
    %Manifest.Root{templates: rows} = Manifest.read!()
    Enum.sort_by(rows, & &1.id)
  end

  @doc """
  Resolves a built-in template by id.

  Unknown ids return `{:error, :unknown_template}` without touching the
  filesystem beyond reading the manifest.
  """
  @spec fetch(String.t()) :: {:ok, entry()} | {:error, :unknown_template}
  def fetch(template_id) when is_binary(template_id) do
    %Manifest.Root{templates: rows} = Manifest.read!()

    case Enum.find(rows, fn %Entry{id: id} -> id == template_id end) do
      nil -> {:error, :unknown_template}
      %Entry{} = entry -> {:ok, entry}
    end
  end

  @doc """
  Reads the spec file for a manifest-backed template id.
  """
  @spec read_spec(String.t()) :: {:ok, String.t()} | {:error, :unknown_template | File.posix()}
  def read_spec(template_id) when is_binary(template_id) do
    with {:ok, %Entry{} = entry} <- fetch(template_id) do
      read_pack_file(entry, entry.spec_file)
    end
  end

  @doc """
  Reads the authoring workflow YAML bytes for a manifest-backed template id.
  """
  @spec read_workflow_yaml(String.t()) ::
          {:ok, String.t()} | {:error, :unknown_template | File.posix()}
  def read_workflow_yaml(template_id) when is_binary(template_id) do
    with {:ok, %Entry{} = entry} <- fetch(template_id) do
      read_pack_file(entry, entry.workflow_file)
    end
  end

  @doc """
  Absolute path to a shipped dispatcher workflow file under `priv/workflows/`.
  """
  @spec shipped_workflow_yaml_path(String.t()) :: String.t()
  def shipped_workflow_yaml_path(workflow_id) when is_binary(workflow_id) do
    Application.app_dir(:kiln, Path.join("priv/workflows", "#{workflow_id}.yaml"))
  end

  defp read_pack_file(%Entry{id: id}, relative) when is_binary(relative) do
    base = Application.app_dir(:kiln, "priv/templates")
    path = Path.join([base, id, relative])
    File.read(path)
  end
end
