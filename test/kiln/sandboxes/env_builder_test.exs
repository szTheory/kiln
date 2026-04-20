defmodule Kiln.Sandboxes.EnvBuilderTest do
  use ExUnit.Case, async: false

  import Bitwise

  alias Kiln.Sandboxes.EnvBuilder

  setup do
    File.rm_rf!("priv/run")

    on_exit(fn ->
      File.rm_rf!("priv/run")
    end)

    :ok
  end

  test "build/2 writes an env file for allowed keys" do
    env = %{
      "DTU_BASE_URL" => "http://172.28.0.10",
      "DTU_TOKEN" => "short-lived-token",
      "MIX_ENV" => "test",
      "LANG" => "C.UTF-8"
    }

    assert {:ok, path} = EnvBuilder.build(env, "stage-run-1")
    assert File.exists?(path)

    body = File.read!(path)
    assert body =~ "DTU_BASE_URL=http://172.28.0.10"
    assert body =~ "DTU_TOKEN=short-lived-token"
    assert body =~ "MIX_ENV=test"
    assert body =~ "LANG=C.UTF-8"
  end

  test "build/2 rejects forbidden secret-like names" do
    assert {:error, :sandbox_env_contains_secret, "OPENAI_API_KEY"} =
             EnvBuilder.build(%{"OPENAI_API_KEY" => "x"}, "stage-run-2")
  end

  test "build/2 rejects non-allowlisted names" do
    assert {:error, :sandbox_env_not_allowlisted, "RANDOM_KEY"} =
             EnvBuilder.build(%{"RANDOM_KEY" => "x"}, "stage-run-3")
  end

  test "build/2 writes mode 0600" do
    assert {:ok, path} = EnvBuilder.build(%{"MIX_ENV" => "test"}, "stage-run-4")
    assert {:ok, %File.Stat{mode: mode}} = File.stat(path)
    assert band(mode, 0o777) == 0o600
  end

  test "delete!/1 removes the env file" do
    assert {:ok, path} = EnvBuilder.build(%{"MIX_ENV" => "test"}, "stage-run-5")
    assert :ok = EnvBuilder.delete!(path)
    refute File.exists?(path)
  end

  test "delete!/1 is idempotent for missing files" do
    assert :ok = EnvBuilder.delete!("priv/run/never-there.env")
  end
end
