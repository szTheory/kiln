defmodule KilnWeb.RunBoardLive do
  @moduledoc """
  UI-01 / Phase 07 — operator run board (`/`).

  **Streams (Plan 07-02):** one PubSub topic `runs:board` (mirror `Kiln.Runs.Transitions`).
  Board uses **separate LiveView streams per run state** (`:runs_queued`, …, `:runs_escalated`)
  so each kanban column can host its own `phx-update="stream"` region without splitting a
  single stream across multiple parents (streams are not enumerable for client-side grouping).
  """

  use KilnWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Runs")}
  end

  @impl true
  def handle_event("noop", _params, socket) do
    unless allow?(socket), do: raise("forbidden")
    {:noreply, socket}
  end

  defp allow?(_socket), do: true

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="run-board" class="space-y-6">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold text-bone">Runs</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            Active and terminal runs for this factory.
          </p>
        </div>

        <section class="rounded border border-ash bg-char/80 p-8">
          <h2 class="text-lg font-semibold text-bone">No runs in flight</h2>
          <p class="mt-2 max-w-xl text-sm leading-relaxed text-[var(--color-smoke)]">
            Start a run from the workflow registry when you are ready. New activity appears here in real time.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
