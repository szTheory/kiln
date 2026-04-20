defmodule Kiln.Sandboxes.DTU.HealthPoll do
  @moduledoc """
  Polls the DTU `/healthz` endpoint and surfaces repeated failures.

  Three consecutive misses emit a `:dtu_health_degraded` audit event and a
  PubSub broadcast on the `"dtu_health"` topic. The poll loop is
  defensive: unexpected messages are ignored and scheduling stays
  explicit through `handle_continue/2`.
  """

  use GenServer

  alias Kiln.Audit

  @default_url "http://172.28.0.10:80/healthz"
  @poll_interval_ms :timer.seconds(30)
  @degrade_threshold 3

  defstruct misses: 0,
            last_success_at: nil,
            url: @default_url,
            req_options: [],
            poll_interval_ms: @poll_interval_ms

  @type t :: %__MODULE__{
          misses: non_neg_integer(),
          last_success_at: DateTime.t() | nil,
          url: String.t(),
          req_options: keyword(),
          poll_interval_ms: pos_integer()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      url: Keyword.get(opts, :url, @default_url),
      req_options: Keyword.get(opts, :req_options, []),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, @poll_interval_ms)
    }

    {:ok, state, {:continue, :schedule_initial_poll}}
  end

  @impl true
  def handle_continue(:schedule_initial_poll, state) do
    send(self(), :poll)
    {:noreply, state}
  end

  def handle_continue(:schedule_next_poll, state) do
    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %__MODULE__{} = state) do
    {:noreply, poll(state), {:continue, :schedule_next_poll}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp poll(%__MODULE__{} = state) do
    request_opts =
      [finch: Kiln.Finch, receive_timeout: 5_000, retry: false]
      |> Keyword.merge(state.req_options)

    case Req.get(state.url, request_opts) do
      {:ok, %{status: 200}} ->
        %__MODULE__{state | misses: 0, last_success_at: DateTime.utc_now()}

      _error ->
        misses = state.misses + 1
        new_state = %__MODULE__{state | misses: misses}

        if misses >= @degrade_threshold do
          emit_degraded_event(new_state)
        end

        new_state
    end
  end

  defp emit_degraded_event(state) do
    _ =
      Audit.append(%{
        event_kind: :dtu_health_degraded,
        correlation_id: Ecto.UUID.generate(),
        payload: %{
          "consecutive_misses" => state.misses,
          "endpoint" => "/healthz"
        }
      })

    Phoenix.PubSub.broadcast(Kiln.PubSub, "dtu_health", {:dtu_unhealthy, :consecutive_misses})
  end
end
