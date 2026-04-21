defmodule Kiln.Sandboxes.DTU.HealthPollTest do
  use Kiln.AuditLedgerCase, async: false

  import Ecto.Query

  alias Kiln.Audit.Event
  alias Kiln.Sandboxes.DTU.HealthPoll

  setup do
    topic = "dtu_health"
    Phoenix.PubSub.subscribe(Kiln.PubSub, topic)
    :ok
  end

  test "init defers boot via a :poll message" do
    assert {:ok, %HealthPoll{} = state, {:continue, :schedule_initial_poll}} =
             HealthPoll.init(url: "http://127.0.0.1:9/healthz")

    assert state.misses == 0
  end

  test "after three consecutive misses it emits audit and PubSub signals" do
    state = %HealthPoll{url: "http://127.0.0.1:9/healthz", req_options: [retry: false]}

    assert {:noreply, state1, {:continue, :schedule_next_poll}} =
             HealthPoll.handle_info(:poll, state)

    assert {:noreply, state2, {:continue, :schedule_next_poll}} =
             HealthPoll.handle_info(:poll, state1)

    assert {:noreply, state3, {:continue, :schedule_next_poll}} =
             HealthPoll.handle_info(:poll, state2)

    assert state3.misses == 3
    assert_receive {:dtu_unhealthy, :consecutive_misses}

    event =
      Repo.one!(
        from e in Event,
          where: e.event_kind == :dtu_health_degraded,
          order_by: [desc: e.inserted_at],
          limit: 1
      )

    assert event.payload["consecutive_misses"] == 3
    assert event.payload["endpoint"] == "/healthz"
  end

  test "catch-all handle_info does not crash on stray messages" do
    state = %HealthPoll{url: "http://127.0.0.1:9/healthz"}

    assert {:noreply, ^state} = HealthPoll.handle_info(:unexpected, state)
  end
end
