defmodule Kiln.Runs.RunSchedulingTelemetryTest do
  use Kiln.DataCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.Runs.Transitions

  test "emits queued dwell stop once on queued -> planning" do
    parent = self()
    ref = make_ref()
    handler_id = {:handler, ref}

    :ok =
      :telemetry.attach(
        handler_id,
        [:kiln, :run, :scheduling, :queued, :stop],
        fn _event_name, measurements, metadata, _config ->
          send(parent, {:telemetry, measurements, metadata, ref})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    run = RunFactory.insert(:run, state: :queued)
    assert {:ok, _} = Transitions.transition(run.id, :planning)

    assert_receive {:telemetry, measurements, metadata, ^ref}
    assert is_integer(measurements.duration)
    assert measurements.duration >= 0
    assert metadata.run_id == to_string(run.id)
    assert metadata.next_state == "planning"
    refute_receive {:telemetry, _, _, ^ref}, 50
  end
end
