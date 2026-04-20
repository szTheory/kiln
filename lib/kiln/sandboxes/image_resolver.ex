defmodule Kiln.Sandboxes.ImageResolver do
  @moduledoc """
  Resolve a sandbox language to the pinned image reference and digest in
  `priv/sandbox/images.lock`.

  Phase 3 ships the Elixir image only. Additional languages can be added
  by extending the lock file without changing this module.
  """

  @lock_path Path.expand("../../../priv/sandbox/images.lock", __DIR__)
  @external_resource @lock_path

  @lock_data (case YamlElixir.read_from_file(@lock_path) do
                {:ok, data} when is_map(data) -> data
                _ -> %{}
              end)

  @spec resolve(String.t() | atom()) ::
          {:ok, {String.t(), String.t()}} | {:error, :unsupported_language}
  def resolve(language) when is_binary(language) or is_atom(language) do
    key = to_string(language)

    case Map.get(@lock_data, key) do
      %{"image_ref" => image_ref, "image_digest" => image_digest} ->
        {:ok, {image_ref, image_digest}}

      _ ->
        {:error, :unsupported_language}
    end
  end

  @spec all_supported_languages() :: [String.t()]
  def all_supported_languages do
    Map.keys(@lock_data)
  end
end
