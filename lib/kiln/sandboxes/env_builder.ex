defmodule Kiln.Sandboxes.EnvBuilder do
  @moduledoc """
  Build per-stage env files for `docker run --env-file` while enforcing
  the sandbox allowlist (D-134).

  Secret-shaped names are rejected before any file is written. `DTU_TOKEN`
  is the only token-shaped exception in Phase 3 because it is a short-
  lived DTU-scoped credential.
  """

  @allowlist ["DTU_BASE_URL", "MIX_ENV", "LANG"]
  @secret_regex ~r/(api_key|secret|token|authorization|bearer)/i
  @env_dir "priv/run"

  @spec build(map(), String.t()) :: {:ok, String.t()} | {:error, atom(), String.t()}
  def build(env_map, stage_run_id) when is_map(env_map) and is_binary(stage_run_id) do
    with :ok <- validate(env_map) do
      File.mkdir_p!(@env_dir)

      path = Path.join(@env_dir, "#{stage_run_id}.env")
      body = render(env_map)

      File.write!(path, body)
      File.chmod!(path, 0o600)

      {:ok, path}
    end
  end

  @spec delete!(String.t()) :: :ok
  def delete!(path) when is_binary(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> raise "failed to delete sandbox env file #{path}: #{inspect(reason)}"
    end
  end

  defp validate(env_map) do
    Enum.reduce_while(env_map, :ok, fn {key, _value}, :ok ->
      key_string = to_string(key)

      cond do
        key_string in @allowlist ->
          {:cont, :ok}

        key_string == "DTU_TOKEN" ->
          {:cont, :ok}

        Regex.match?(@secret_regex, key_string) ->
          {:halt, {:error, :sandbox_env_contains_secret, key_string}}

        true ->
          {:halt, {:error, :sandbox_env_not_allowlisted, key_string}}
      end
    end)
  end

  defp render(env_map) do
    env_map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join("\n", fn {key, value} -> "#{key}=#{value}" end)
  end
end
