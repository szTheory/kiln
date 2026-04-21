defmodule KilnWeb.FactorySummaryHook do
  @moduledoc """
  Subscribes LiveViews to **`factory:summary`** and keeps `@factory_summary` fresh (UI-07).
  """

  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      if Phoenix.LiveView.connected?(socket) do
        Phoenix.PubSub.subscribe(Kiln.PubSub, "factory:summary")
        socket
      else
        socket
      end

    socket =
      socket
      |> assign(:factory_summary, %{active: 0, blocked: 0})
      |> Phoenix.LiveView.attach_hook(:factory_summary, :handle_info, fn
        {:factory_summary, summary}, sock ->
          {:cont, assign(sock, :factory_summary, summary)}

        _msg, sock ->
          {:cont, sock}
      end)

    {:cont, socket}
  end
end
