defmodule Kiln.Sandboxes.Hydrator do
  @moduledoc """
  Materialize input artifact refs from CAS into the sandbox workspace.

  This module is intentionally synchronous and stateless. Stage workers
  call it before the sandbox launches.
  """

  alias Kiln.Artifacts

  @type artifact_ref :: %{
          required(:name) => String.t(),
          required(:sha256) => String.t(),
          optional(:size_bytes) => non_neg_integer()
        }

  @spec hydrate([artifact_ref()], String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def hydrate(artifact_refs, workspace_dir)
      when is_list(artifact_refs) and is_binary(workspace_dir) do
    File.mkdir_p!(workspace_dir)

    artifact_refs
    |> Enum.reduce_while({:ok, []}, fn artifact_ref, {:ok, paths} ->
      case hydrate_one(artifact_ref, workspace_dir) do
        {:ok, path} -> {:cont, {:ok, [path | paths]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, paths} -> {:ok, Enum.reverse(paths)}
      {:error, _reason} = error -> error
    end
  end

  defp hydrate_one(%{name: name, sha256: sha256}, workspace_dir) do
    target_path = Path.join(workspace_dir, name)
    File.mkdir_p!(Path.dirname(target_path))

    case Artifacts.by_sha(sha256) do
      [%_{} = artifact | _] ->
        stream_to_file(Artifacts.stream!(artifact), target_path)

      [] ->
        {:error, {:missing_artifact, sha256}}
    end
  end

  defp stream_to_file(stream, target_path) do
    File.open!(target_path, [:write, :binary, :raw], fn file ->
      Enum.each(stream, &:file.write(file, &1))
    end)

    {:ok, target_path}
  end
end
