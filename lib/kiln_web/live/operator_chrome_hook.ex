defmodule KilnWeb.OperatorChromeHook do
  @moduledoc """
  Phase **999.2** / **OPS-01**: on_mount hook that assigns operator shell chrome
  (`:operator_runtime_mode`, `:operator_snapshots`) and refreshes them on a
  timer while the LiveView stays connected (same order of magnitude as
  `ProviderHealthLive` polling).
  """

  import Phoenix.Component

  @poll_ms 5_000

  alias Kiln.DemoScenarios
  alias Kiln.ModelRegistry
  alias Kiln.OperatorRuntime

  def on_mount(:default, params, _session, socket) do
    mode = current_mode(socket)
    scenario = current_scenario(socket, params || %{})

    socket =
      socket
      |> assign(:operator_runtime_mode, mode)
      |> assign(:operator_demo_scenario, scenario)
      |> assign(:operator_demo_scenarios, DemoScenarios.list())
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
            |> assign(:operator_snapshots, ModelRegistry.provider_health_snapshots())

          Process.send_after(self(), :operator_chrome_tick, @poll_ms)
          {:cont, sock}

        _msg, sock ->
          {:cont, sock}
      end)

    socket =
      Phoenix.LiveView.attach_hook(socket, :operator_runtime_mode_events, :handle_event, fn
        "operator:set_mode", %{"mode" => mode}, sock ->
          {:halt, assign(sock, :operator_runtime_mode, normalize_or_keep(mode, sock))}

        "operator:set_mode_form", %{"runtime_mode" => %{"operator_mode" => mode}}, sock ->
          {:halt, assign(sock, :operator_runtime_mode, normalize_or_keep(mode, sock))}

        "operator:set_scenario", %{"id" => id}, sock ->
          {:halt, assign(sock, :operator_demo_scenario, normalize_scenario_or_keep(id, sock))}

        "operator:set_scenario_form", %{"journey" => %{"scenario_id" => id}}, sock ->
          {:halt, assign(sock, :operator_demo_scenario, normalize_scenario_or_keep(id, sock))}

        _, _, sock ->
          {:cont, sock}
      end)

    {:cont, socket}
  end

  defp current_mode(socket) do
    socket
    |> connect_param("operator_runtime_mode")
    |> OperatorRuntime.normalize()
    |> case do
      :unknown -> OperatorRuntime.mode()
      mode -> mode
    end
  end

  defp current_scenario(socket, params) do
    candidate =
      cond do
        is_binary(params["scenario"]) and params["scenario"] != "" -> params["scenario"]
        true -> connect_param(socket, "operator_demo_scenario")
      end

    case DemoScenarios.fetch(candidate) do
      {:ok, scenario} -> scenario
      {:error, :unknown_scenario} -> DemoScenarios.default()
    end
  end

  defp connect_param(socket, key) do
    if Phoenix.LiveView.connected?(socket) do
      case Phoenix.LiveView.get_connect_params(socket) do
        %{^key => value} -> value
        _ -> nil
      end
    end
  end

  defp normalize_scenario_or_keep(id, socket) do
    case DemoScenarios.fetch(id) do
      {:ok, scenario} -> scenario
      {:error, :unknown_scenario} -> socket.assigns.operator_demo_scenario
    end
  end

  defp normalize_or_keep(mode, socket) do
    case OperatorRuntime.normalize(mode) do
      :unknown -> socket.assigns.operator_runtime_mode
      normalized -> normalized
    end
  end
end
