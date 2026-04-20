defmodule Kiln.Sandboxes.OrphanSweeper do
  @moduledoc """
  Sweeps stale sandbox containers left behind by a prior Kiln boot.

  Containers are identified through the Phase 3 Docker labels, in
  particular `kiln.boot_epoch`. Any container whose boot epoch differs
  from the current process boot epoch is treated as an orphan, removed
  with `docker rm -f`, and recorded as an `:orphan_container_swept`
  audit event.

  Supervisor boot never blocks on the sweep. `init/1` schedules an
  immediate `:boot_scan`, then re-arms a periodic safety scan for long
  lived hosts.
  """

  use GenServer

  alias Kiln.Audit
  alias Kiln.Sandboxes.DockerDriver

  @default_periodic_scan_ms :timer.minutes(5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec boot_epoch_now() :: integer()
  def boot_epoch_now do
    System.monotonic_time(:millisecond)
  end

  @impl true
  def init(_opts) do
    state = %{boot_epoch: config(:boot_epoch_fun, &boot_epoch_now/0).()}
    send(self(), :boot_scan)
    {:ok, state}
  end

  @impl true
  def handle_info(:boot_scan, %{boot_epoch: boot_epoch} = state) do
    do_scan(boot_epoch)
    schedule_next_scan()
    {:noreply, state}
  end

  def handle_info(:periodic_scan, %{boot_epoch: boot_epoch} = state) do
    do_scan(boot_epoch)
    schedule_next_scan()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp do_scan(boot_epoch) do
    boot_epoch
    |> config(:list_orphans_fun, &DockerDriver.list_orphans/1).()
    |> Enum.each(&sweep_orphan(&1, boot_epoch))
  end

  defp sweep_orphan(container_id, boot_epoch) when is_binary(container_id) do
    _ =
      config(:audit_append_fun, &Audit.append/1).(%{
        event_kind: :orphan_container_swept,
        correlation_id: Ecto.UUID.generate(),
        payload: %{
          "container_id" => container_id,
          "boot_epoch_found" => boot_epoch
        }
      })

    _ =
      config(:system_cmd_fun, &System.cmd/3).(
        "docker",
        ["rm", "-f", container_id],
        stderr_to_stdout: true
      )

    :ok
  end

  defp schedule_next_scan do
    case config(:periodic_scan_ms, @default_periodic_scan_ms) do
      interval when is_integer(interval) and interval <= 0 ->
        send(self(), :periodic_scan)

      interval ->
        Process.send_after(self(), :periodic_scan, interval)
    end
  end

  defp config(key, default) do
    :kiln
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
