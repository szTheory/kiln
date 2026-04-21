defmodule KilnWeb.WorkflowLive do
  @moduledoc false
  use KilnWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workflows")
     |> assign(:workflow_id, Map.get(params, "workflow_id"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <p class="text-sm text-[var(--color-smoke)]">Loading…</p>
    </Layouts.app>
    """
  end
end
