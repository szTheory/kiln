defmodule Kiln.RemoteComposeProfileTest do
  use ExUnit.Case, async: false

  @compose_file "compose.yaml"
  @auth_key "tskey-test-remote-profile"
  @tunnel_target "http://host.docker.internal:4000"

  describe "docker compose config" do
    test "remote profile adds tailscale without changing the default service surface" do
      base = compose_config([])
      remote = compose_config(["--profile", "remote"])

      assert Map.delete(remote["services"], "tailscale") == base["services"]
      refute Map.has_key?(base["services"], "tailscale")

      tailscale = remote["services"]["tailscale"]

      assert tailscale["profiles"] == ["remote"]
      assert tailscale["environment"]["TS_AUTHKEY"] == @auth_key
      assert tailscale["environment"]["TAILSCALE_TUNNEL_TARGET"] == @tunnel_target
      assert tailscale["volumes"] |> Enum.any?(&(&1["target"] == "/var/lib/tailscale"))
      assert command_text(tailscale) =~ "tailscale serve --bg --https=443"
      assert command_text(tailscale) =~ "TS_AUTHKEY"
      assert command_text(tailscale) =~ "TAILSCALE_TUNNEL_TARGET"
      assert tailscale["ports"] in [nil, []]
    end
  end

  defp compose_config(profile_args) do
    argv = ["compose", "-f", @compose_file] ++ profile_args ++ ["config"]

    {output, status} =
      System.cmd("docker", argv,
        env: [{"TS_AUTHKEY", @auth_key}],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert {:ok, config} = YamlElixir.read_from_string(output)
    config
  end

  defp command_text(%{"command" => command}) when is_list(command) do
    Enum.join(command, " ")
  end

  defp command_text(%{"command" => command}) when is_binary(command), do: command
end
