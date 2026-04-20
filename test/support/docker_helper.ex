defmodule Kiln.DockerHelper do
  @moduledoc """
  Helpers for live-docker integration tests. Designed to be used via the
  `Kiln.SandboxCase` / `Kiln.DtuCase` case templates, which wire in the
  `@tag :docker` skip path and orphan-container cleanup on exit.

  Docker-dependent tests are gated behind the `:docker` tag and excluded
  by default from `mix test` (see `test/test_helper.exs` exclude list).

  ## Public API

    * `track_container/2` — insert a container id into the per-test ETS
      bag so `Kiln.SandboxCase`'s `on_exit` can `docker rm -f` it.
    * `docker_available?/0` — cheap PATH lookup; returns `false` on CI
      workers without a Docker daemon (triggers `:skip` in case setups).
    * `exec_in_container/2` — `docker exec <id> <argv>` with stderr
      merged to stdout.
  """

  @spec track_container(:ets.tid(), String.t()) :: true
  def track_container(ets_tid, id) when is_binary(id) do
    :ets.insert(ets_tid, {:container, id})
  end

  @spec docker_available?() :: boolean()
  def docker_available? do
    System.find_executable("docker") != nil
  end

  @spec exec_in_container(String.t(), [String.t()]) ::
          {Collectable.t(), non_neg_integer()}
  def exec_in_container(container_id, args)
      when is_binary(container_id) and is_list(args) do
    System.cmd("docker", ["exec", container_id | args], stderr_to_stdout: true)
  end
end
