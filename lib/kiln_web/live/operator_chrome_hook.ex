defmodule KilnWeb.OperatorChromeHook do
  @moduledoc """
  Phase **999.2** / **OPS-01**: on_mount hook that assigns operator shell chrome
  (`:operator_runtime_mode`, `:operator_snapshots`) and refreshes them on a
  timer while the LiveView stays connected (same order of magnitude as
  `ProviderHealthLive` polling).
  """

  import Phoenix.Component

  @poll_ms 5_000

  alias Kiln.ModelRegistry
  alias Kiln.OperatorRuntime

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:operator_runtime_mode, OperatorRuntime.mode())
      |> assign(:operator_snapshots, ModelRegistry.provider_health_snapshots())

    socket =
      if Phoenix.LiveView.connected?(socket) do
        Process.send_after(self(), :operator_chrome_tick, @poll_ms)
        socket
      else
        socket
      end

    socket =
      Phoenix.LiveView.attach_hook(socket, :operator_chrome, :handle_info, fn
        :operator_chrome_tick, sock ->
          sock =
            sock
            |> assign(:operator_runtime_mode, OperatorRuntime.mode())
            |> assign(:operator_snapshots, ModelRegistry.provider_health_snapshots())

          Process.send_after(self(), :operator_chrome_tick, @poll_ms)
          {:cont, sock}

        _msg, sock ->
          {:cont, sock}
      end)

    {:cont, socket}
  end
end
