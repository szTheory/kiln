defmodule Kiln.Telemetry.OtelSmokeTest do
  use ExUnit.Case, async: true

  alias Kiln.Telemetry.Spans

  test "manual span helpers run without raising" do
    assert :ok =
             Spans.with_run_stage(%{run_id: Ecto.UUID.generate()}, fn ->
               :ok
             end)

    assert {:ok, :pong} =
             Spans.with_llm_request(%{provider: "test"}, fn ->
               {:ok, :pong}
             end)

    assert :ok =
             Spans.with_docker_op(%{command: "docker", op: "noop"}, fn ->
               :ok
             end)
  end
end
