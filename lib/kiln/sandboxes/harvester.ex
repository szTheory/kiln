defmodule Kiln.Sandboxes.Harvester do
  @moduledoc """
  Stream sandbox output files from `out/` into the artifact store.

  This module stays pure and synchronous so stage completion can compose
  it directly with the existing `Kiln.Artifacts.put/4` transaction flow.
  """

  alias Kiln.Artifacts

  @type artifact_record :: %{
          name: String.t(),
          sha256: String.t(),
          size_bytes: non_neg_integer()
        }

  @spec harvest(String.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, [artifact_record()]} | {:error, term()}
  def harvest(workspace_dir, run_id, stage_run_id)
      when is_binary(workspace_dir) and is_binary(run_id) and is_binary(stage_run_id) do
    out_dir = Path.join(workspace_dir, "out")

    if File.dir?(out_dir) do
      out_dir
      |> File.ls!()
      |> Enum.sort()
      |> Enum.reduce_while({:ok, []}, fn name, {:ok, records} ->
        full_path = Path.join(out_dir, name)

        cond do
          File.regular?(full_path) ->
            case put_output(full_path, name, run_id, stage_run_id) do
              {:ok, record} -> {:cont, {:ok, [record | records]}}
              {:error, _reason} = error -> {:halt, error}
            end

          true ->
            {:cont, {:ok, records}}
        end
      end)
      |> case do
        {:ok, records} -> {:ok, Enum.reverse(records)}
        {:error, _reason} = error -> error
      end
    else
      {:ok, []}
    end
  end

  defp put_output(full_path, name, run_id, stage_run_id) do
    case Artifacts.put(stage_run_id, name, File.stream!(full_path, [], 64 * 1024),
           run_id: run_id,
           content_type: guess_content_type(name),
           producer_kind: "sandbox_harvest"
         ) do
      {:ok, artifact} ->
        {:ok, %{name: name, sha256: artifact.sha256, size_bytes: artifact.size_bytes}}

      {:error, _reason} = error ->
        error
    end
  end

  defp guess_content_type(name) do
    case Path.extname(name) do
      ".ex" -> :"text/x-elixir"
      ".exs" -> :"text/x-elixir"
      ".json" -> :"application/json"
      ".diff" -> :"application/x-diff"
      ".patch" -> :"application/x-diff"
      ".md" -> :"text/markdown"
      _other -> :"text/plain"
    end
  end
end
