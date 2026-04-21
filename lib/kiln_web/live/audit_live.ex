defmodule KilnWeb.AuditLive do
  @moduledoc false
  use KilnWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Audit")}
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
