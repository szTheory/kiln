defmodule KilnWeb.RunReplayLive do
  @moduledoc """
  REPL-01 — read-only audit timeline for a single run at `/runs/:run_id/replay`.

  See phase 16 UI-SPEC and CONTEXT (D-01–D-06, D-16).
  """

  use KilnWeb, :live_view

  alias Kiln.Audit
  alias Kiln.Runs

  @impl true
  def mount(%{"run_id" => run_id}, _session, socket) do
    case Ecto.UUID.cast(run_id) do
      :error ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid run id")
         |> push_navigate(to: ~p"/")}

      {:ok, uuid} ->
        case Runs.get(uuid) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Run not found")
             |> push_navigate(to: ~p"/")}

          run ->
            {:ok,
             socket
             |> assign(:page_title, "Run replay")
             |> assign(:run, run)
             |> assign(:selected_event_id, nil)
             |> assign(:selected_event, nil)
             |> assign(:events_empty?, true)
             |> assign(:truncated?, false)
             |> stream(:events, [], reset: true)}
        end
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    run = socket.assigns.run

    socket =
      case params["at"] do
        nil ->
          assign(socket, :selected_event_id, nil)

        "" ->
          assign(socket, :selected_event_id, nil)

        at_raw ->
          case Ecto.UUID.cast(at_raw) do
            :error ->
              socket
              |> put_flash(:error, "Invalid event id")
              |> assign(:selected_event_id, nil)

            {:ok, at} ->
              assign(socket, :selected_event_id, at)
          end
      end

    events = Audit.replay(run_id: run.id, limit: 500)

    selected_id = socket.assigns.selected_event_id

    selected =
      case selected_id do
        nil -> List.last(events)
        id -> Enum.find(events, &(&1.id == id)) || List.last(events)
      end

    {:noreply,
     socket
     |> assign(:events_empty?, events == [])
     |> assign(:truncated?, length(events) == 500)
     |> assign(:selected_event, selected)
     |> stream(
       :events,
       Enum.map(events, fn e -> {"replay-event-#{e.id}", e} end),
       reset: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      factory_summary={@factory_summary}
      operator_runtime_mode={@operator_runtime_mode}
      operator_snapshots={@operator_snapshots}
    >
      <div id="run-replay" data-run-id={@run.id} class="space-y-6 text-bone">
        <div class="flex flex-wrap items-end justify-between gap-4 border-b border-ash pb-4">
          <div>
            <p class="font-mono text-xs text-[var(--color-smoke)]">{@run.id}</p>
            <h1 class="text-xl font-semibold">Run replay</h1>
            <p class="mt-1 text-sm text-[var(--color-smoke)]">
              Read-only audit spine for this run.
            </p>
          </div>
        </div>

        <%= if @truncated? do %>
          <div class="rounded border border-ember/40 bg-char px-4 py-3 text-sm text-bone">
            Showing first 500 events — refine filters or export from Audit.
          </div>
        <% end %>

        <%= if @events_empty? do %>
          <p class="text-sm text-[var(--color-smoke)]">No audit events for this run yet.</p>
        <% end %>

        <div class="grid gap-6 lg:grid-cols-2">
          <div>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
              Timeline
            </h2>
            <div id="replay-events" phx-update="stream" class="max-h-[32rem] space-y-2 overflow-y-auto">
              <div
                :for={{dom_id, event} <- @streams.events}
                id={dom_id}
                class={[
                  "rounded border px-3 py-2 text-sm",
                  @selected_event && @selected_event.id == event.id && "border-ember bg-iron",
                  (!@selected_event || @selected_event.id != event.id) && "border-ash bg-char"
                ]}
              >
                <div class="font-mono text-xs text-[var(--color-smoke)]">
                  {Calendar.strftime(event.occurred_at, "%Y-%m-%d %H:%M:%S.%f")} UTC
                </div>
                <div class="mt-1 font-mono text-xs break-all">{event.id}</div>
                <div class="mt-1 text-sm">{inspect(event.event_kind)}</div>
              </div>
            </div>
          </div>
          <div>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
              Event detail
            </h2>
            <%= if @selected_event do %>
              <div class="space-y-3 rounded border border-ash bg-char p-4 text-sm">
                <div>
                  <div class="text-xs uppercase text-[var(--color-smoke)]">Kind</div>
                  <div class="font-mono">{inspect(@selected_event.event_kind)}</div>
                </div>
                <div>
                  <div class="text-xs uppercase text-[var(--color-smoke)]">Occurred at</div>
                  <div class="font-mono">
                    {Calendar.strftime(@selected_event.occurred_at, "%Y-%m-%d %H:%M:%S.%f")} UTC
                  </div>
                </div>
                <div>
                  <div class="text-xs uppercase text-[var(--color-smoke)]">Payload</div>
                  <pre class="mt-1 max-h-64 overflow-auto rounded bg-iron p-2 font-mono text-xs text-bone whitespace-pre-wrap break-all"><%= Jason.encode!(@selected_event.payload) %></pre>
                </div>
              </div>
            <% else %>
              <p class="text-sm text-[var(--color-smoke)]">Select an event from the list.</p>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
