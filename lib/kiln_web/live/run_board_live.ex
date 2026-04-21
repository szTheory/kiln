defmodule KilnWeb.RunBoardLive do
  @moduledoc """
  UI-01 / Phase 07 — operator run board (`/`).

  **Streams:** one PubSub topic `runs:board` (mirror `Kiln.Runs.Transitions`).
  The board uses **separate LiveView streams per run state** — mount uses the
  same shape as `stream(:runs_queued, rows, reset: true)` for every
  `stream(:runs_<state>, …)` key (`:runs_planning` … `:runs_escalated`) so each
  kanban column has its own `phx-update="stream"` container (streams are not
  enumerable for client-side grouping).

  Column order follows `Kiln.Runs.Run.states/0`.
  """

  use KilnWeb, :live_view

  alias Kiln.Runs
  alias Kiln.Runs.Run

  @stream_keys %{
    queued: :runs_queued,
    planning: :runs_planning,
    coding: :runs_coding,
    testing: :runs_testing,
    verifying: :runs_verifying,
    blocked: :runs_blocked,
    merged: :runs_merged,
    failed: :runs_failed,
    escalated: :runs_escalated
  }

  @impl true
  def mount(_params, _session, socket) do
    _ = Phoenix.PubSub.subscribe(Kiln.PubSub, "runs:board")

    runs = Runs.list_for_board()
    run_states = Map.new(runs, &{&1.id, &1.state})

    socket =
      socket
      |> assign(:page_title, "Runs")
      |> assign(:run_states, run_states)
      |> assign(:runs_empty?, runs == [])

    socket =
      Enum.reduce(Run.states(), socket, fn state, acc ->
        rows = Enum.filter(runs, &(&1.state == state))
        stream(acc, stream_for(state), rows, reset: true)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_info({:run_state, %Run{} = run}, socket) do
    old = Map.get(socket.assigns.run_states, run.id)

    socket =
      socket
      |> delete_from_old_stream(old, run)
      |> stream_insert(stream_for(run.state), run)
      |> assign(:run_states, Map.put(socket.assigns.run_states, run.id, run.state))
      |> assign(:runs_empty?, false)

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("noop", _params, socket) do
    unless allow?(socket), do: raise("forbidden")
    {:noreply, socket}
  end

  defp allow?(_socket), do: true

  defp stream_for(state), do: Map.fetch!(@stream_keys, state)

  defp delete_from_old_stream(socket, nil, _run), do: socket

  defp delete_from_old_stream(socket, old_state, run) when old_state != run.state do
    stream_delete(socket, stream_for(old_state), %Run{id: run.id, state: old_state})
  end

  defp delete_from_old_stream(socket, _same, _run), do: socket

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} factory_summary={@factory_summary}>
      <div id="run-board" class="space-y-6">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold text-bone">Runs</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            Active and terminal runs for this factory.
          </p>
        </div>

        <%= if @runs_empty? do %>
          <section class="rounded border border-ash bg-char/80 p-8">
            <h2 class="text-lg font-semibold text-bone">No runs in flight</h2>
            <p class="mt-2 max-w-xl text-sm leading-relaxed text-[var(--color-smoke)]">
              Start a run from the workflow registry when you are ready. New activity appears here in real time.
            </p>
          </section>
        <% else %>
          <div class="grid gap-4 overflow-x-auto pb-4 lg:grid-cols-9">
            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="queued"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Queued
              </h2>
              <div id="runs_queued" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_queued}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="planning"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Planning
              </h2>
              <div id="runs_planning" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_planning}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="coding"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Coding
              </h2>
              <div id="runs_coding" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_coding}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="testing"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Testing
              </h2>
              <div id="runs_testing" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_testing}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="verifying"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Verifying
              </h2>
              <div id="runs_verifying" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_verifying}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="blocked"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Blocked
              </h2>
              <div id="runs_blocked" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_blocked}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="merged"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Merged
              </h2>
              <div id="runs_merged" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_merged}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="failed"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Failed
              </h2>
              <div id="runs_failed" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_failed}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>

            <section
              class="flex min-w-[10.5rem] flex-col gap-2 rounded border border-ash bg-char/80 p-2"
              data-state="escalated"
            >
              <h2 class="border-b border-ash pb-1 font-sans text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Escalated
              </h2>
              <div id="runs_escalated" phx-update="stream" class="flex flex-col gap-2">
                <div
                  :for={{dom_id, run} <- @streams.runs_escalated}
                  id={dom_id}
                  class="rounded border border-ash bg-iron/60 p-2 font-mono text-xs text-bone"
                >
                  <div class="truncate font-semibold text-ember" title={run.id}>
                    {short_id(run.id)}
                  </div>
                  <div class="mt-1 truncate text-[var(--color-smoke)]">{run.workflow_id}</div>
                </div>
              </div>
            </section>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp short_id(id) do
    id |> to_string() |> String.slice(0, 8)
  end
end
