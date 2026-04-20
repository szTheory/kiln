defmodule Kiln.DtuCase do
  @moduledoc """
  Shared ExUnit case template for Digital Twin Universe (DTU) sidecar
  integration tests. The DTU mock service is a separate `priv/dtu`
  mix project that serves the GitHub API shape at `http://172.28.0.10:80`
  on the `kiln-sandbox` Docker bridge network (plan 03-09 ships the
  service; Wave 4 tests consume it via this case).

  `setup_all` brings the `dtu` service up with `docker compose up -d dtu`
  once per module; tests assume DTU is reachable at its static IP.
  Gated by both `@moduletag :docker` and `@moduletag :dtu` so CI workers
  without docker OR without DTU fixtures skip cleanly.

  ## Usage

      defmodule Kiln.Sandboxes.DTU.HealthPollTest do
        use Kiln.DtuCase, async: false

        test "health probe succeeds on DTU" do
          {:ok, %{status: 200}} = Req.get("http://172.28.0.10/healthz")
        end
      end

  Both `:docker` and `:dtu` tags are on the default-exclude list in
  `test/test_helper.exs` — these tests run only when tags are explicitly
  included (`mix test --include dtu`).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :docker
      @moduletag :dtu

      import Kiln.DockerHelper
    end
  end

  setup_all do
    cond do
      !Kiln.DockerHelper.docker_available?() ->
        {:skip, "docker CLI not available"}

      true ->
        case System.cmd("docker", ["compose", "up", "-d", "dtu"],
               stderr_to_stdout: true
             ) do
          {_output, 0} ->
            :ok

          {output, code} ->
            {:skip, "docker compose up -d dtu failed (#{code}): #{output}"}
        end
    end
  end
end
