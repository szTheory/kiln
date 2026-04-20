defmodule Kiln.SandboxCase do
  @moduledoc """
  Shared ExUnit case template for `Kiln.Sandboxes` integration tests.

  Gated by `@tag :docker` so CI workers without a Docker daemon skip
  these tests (the tag is on the default-exclude list in
  `test/test_helper.exs`). Within a test, spawned container ids can be
  tracked through the `container_ids` ETS bag passed in the test
  context; `on_exit` `docker rm -f`'s every tracked container regardless
  of test outcome (defence-in-depth vs. `Kiln.Sandboxes.OrphanSweeper`).

  ## Usage

      defmodule Kiln.Sandboxes.DockerDriverTest do
        use Kiln.SandboxCase, async: false

        @tag :docker
        test "starts a container", %{container_ids: ids} do
          {id, 0} = System.cmd("docker", ["run", "-d", "alpine", "true"])
          track_container(ids, String.trim(id))
          # ...
        end
      end

  The `:docker` tag is also set as a `@moduletag` via the `using` hook
  so individual tests do not need to re-annotate.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :docker

      import Kiln.DockerHelper
    end
  end

  setup tags do
    cond do
      tags[:docker] && !Kiln.DockerHelper.docker_available?() ->
        {:skip, "docker CLI not available"}

      true ->
        container_ids = :ets.new(:sandbox_case_containers, [:public, :bag])

        on_exit(fn ->
          for {:container, id} <- :ets.tab2list(container_ids) do
            System.cmd("docker", ["rm", "-f", id], stderr_to_stdout: true)
          end
        end)

        {:ok, container_ids: container_ids}
    end
  end
end
