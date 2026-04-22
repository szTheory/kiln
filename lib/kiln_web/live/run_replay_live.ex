defmodule KilnWeb.RunReplayLive do
  @moduledoc """
  REPL-01 — read-only audit timeline for a single run at `/runs/:run_id/replay`.

  Spine windows use `Kiln.Audit.replay_page/1` with **limit 200** (see CONTEXT D-07,
  D-11). Terminal runs (`:merged`, `:failed`, `:escalated`) do not subscribe to live
  tails (D-18); in-flight runs coalesce PubSub refreshes (D-19, D-20).
  """

  use KilnWeb, :live_view

  import Ecto.Query

  alias Kiln.Audit
  alias Kiln.Audit.Event
  alias Kiln.Repo
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.WorkUnits.PubSub, as: WUPubSub

  @page_limit 200
  @debounce_ms 120

  @terminal_states [:merged, :failed, :escalated]

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

          %Run{} = run ->
            terminal? = run.state in @terminal_states

            socket =
              socket
              |> assign(:page_title, "Run replay")
              |> assign(:run, run)
              |> assign(:terminal_run?, terminal?)
              |> assign(:selected_event_id, nil)
              |> assign(:selected_event, nil)
              |> assign(:selected_index, 0)
              |> assign(:replay_events, [])
              |> assign(:events_empty?, true)
              |> assign(:spine_truncated?, false)
              |> assign(:unknown_at?, false)
              |> assign(:live_edge?, !terminal?)
              |> assign(:pending_tail_count, 0)
              |> assign(:scrubber_max, 0)
              |> assign(:replay_flush_timer, nil)
              |> stream(:events, [], reset: true)

            socket = if(terminal?, do: socket, else: subscribe_run_topics(socket, run))

            {:ok, socket}
        end
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    run = socket.assigns.run

    {socket, selected_id} = parse_at_param(socket, params["at"])

    {load_status, %{events: events, truncated: spine_t}} = load_spine(run, selected_id)

    socket =
      case load_status do
        :unknown_at ->
          put_flash(
            socket,
            :info,
            "That event is not on the loaded window — showing the latest tail."
          )

        _ ->
          socket
      end

    {selected, selected_idx} = pick_selection(events, selected_id)

    scrubber_max = max(length(events) - 1, 0)
    idx = min(max(selected_idx, 0), scrubber_max)

    live_edge? =
      not socket.assigns.terminal_run? and match?(%Event{}, selected) and
        match?(%Event{}, List.last(events)) and selected.id == List.last(events).id

    {:noreply,
     socket
     |> assign(:selected_event_id, selected && selected.id)
     |> assign(:selected_event, selected)
     |> assign(:selected_index, idx)
     |> assign(:replay_events, events)
     |> assign(:events_empty?, events == [])
     |> assign(:spine_truncated?, spine_t)
     |> assign(:unknown_at?, load_status == :unknown_at)
     |> assign(:live_edge?, live_edge?)
     |> assign(:scrubber_max, scrubber_max)
     |> stream(
       :events,
       stream_items(events),
       reset: true
     )}
  end

  @impl true
  def handle_event("scrub_first", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/runs/#{socket.assigns.run.id}/replay")}
  end

  def handle_event("scrub_last", _params, socket) do
    case List.last(socket.assigns.replay_events) do
      %Event{id: id} ->
        {:noreply, push_patch(socket, to: replay_at(socket.assigns.run, id))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("scrub_prev", _params, socket) do
    evs = socket.assigns.replay_events
    idx = socket.assigns.selected_index

    if idx > 0 do
      target = Enum.at(evs, idx - 1)
      {:noreply, push_patch(socket, to: replay_at(socket.assigns.run, target.id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("scrub_next", _params, socket) do
    evs = socket.assigns.replay_events
    idx = socket.assigns.selected_index

    if idx < length(evs) - 1 do
      target = Enum.at(evs, idx + 1)
      {:noreply, push_patch(socket, to: replay_at(socket.assigns.run, target.id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("jump_latest", _params, socket) do
    run = socket.assigns.run

    {:noreply,
     socket
     |> assign(:pending_tail_count, 0)
     |> push_patch(to: ~p"/runs/#{run.id}/replay")}
  end

  def handle_event("scrub_range", %{"idx" => raw}, socket) do
    evs = socket.assigns.replay_events

    case Integer.parse(to_string(raw)) do
      {i, _} when i >= 0 and i < length(evs) ->
        target = Enum.at(evs, i)
        {:noreply, push_patch(socket, to: replay_at(socket.assigns.run, target.id))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(_other, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:audit_event, _}, socket), do: coalesce_pubsub(socket)
  def handle_info({:run_state, _}, socket), do: coalesce_pubsub(socket)
  def handle_info({:work_unit, _}, socket), do: coalesce_pubsub(socket)

  def handle_info(:replay_flush, socket) do
    socket = assign(socket, :replay_flush_timer, nil)
    run = socket.assigns.run

    if run.state in @terminal_states do
      {:noreply, socket}
    else
      {:ok, %{events: evs, truncated: t}} = load_spine(run, nil)
      {sel, idx} = pick_selection(evs, nil)
      scrubber_max = max(length(evs) - 1, 0)

      {:noreply,
       socket
       |> assign(:replay_events, evs)
       |> assign(:selected_event_id, sel && sel.id)
       |> assign(:selected_event, sel)
       |> assign(:selected_index, idx)
       |> assign(:events_empty?, evs == [])
       |> assign(:spine_truncated?, t)
       |> assign(:live_edge?, true)
       |> assign(:pending_tail_count, 0)
       |> assign(:scrubber_max, scrubber_max)
       |> stream(:events, stream_items(evs), reset: true)}
    end
  end

  def handle_info(_other, socket), do: {:noreply, socket}

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
              <%= if @terminal_run? do %>
                <span class="ml-2 font-mono text-xs text-[var(--color-smoke)]">Complete</span>
              <% else %>
                <span class="ml-2 font-mono text-xs text-ember">Live</span>
              <% end %>
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-3">
            <.link
              class="text-sm text-ember underline"
              navigate={~p"/audit?#{URI.encode_query(%{"run_id" => to_string(@run.id)})}"}
            >
              Open in Audit
            </.link>
            <.link class="text-sm text-ember underline" navigate={~p"/runs/#{@run.id}"}>
              Run detail
            </.link>
          </div>
        </div>

        <%= if @unknown_at? do %>
          <div class="rounded border border-clay/50 bg-char px-4 py-2 text-sm text-bone">
            Selected event is outside the loaded window — showing the latest tail.
          </div>
        <% end %>

        <%= if @spine_truncated? do %>
          <div class="rounded border border-ember/40 bg-char px-4 py-3 text-sm text-bone">
            Showing first 200 events — refine filters or export from Audit.
          </div>
        <% end %>

        <%= if @pending_tail_count > 0 && !@live_edge? do %>
          <div class="flex flex-wrap items-center justify-between gap-3 rounded border border-ember/40 bg-char px-4 py-3 text-sm text-bone">
            <span>{@pending_tail_count} new events — jump to latest</span>
            <button
              type="button"
              id="replay-jump-latest"
              phx-click="jump_latest"
              class="rounded border border-ember px-3 py-1.5 text-sm font-semibold text-ember transition-colors hover:bg-ember/10"
            >
              Jump to latest
            </button>
          </div>
        <% end %>

        <%= if @events_empty? do %>
          <p class="text-sm text-[var(--color-smoke)]">No audit events for this run yet.</p>
        <% end %>

        <div class="flex flex-wrap items-center gap-2">
          <button
            type="button"
            id="replay-first"
            phx-click="scrub_first"
            class="rounded border border-ash px-2 py-1 text-xs text-bone hover:border-ember"
          >
            First
          </button>
          <button
            type="button"
            id="replay-prev"
            phx-click="scrub_prev"
            class="rounded border border-ash px-2 py-1 text-xs text-bone hover:border-ember"
          >
            Prev
          </button>
          <button
            type="button"
            id="replay-next"
            phx-click="scrub_next"
            class="rounded border border-ash px-2 py-1 text-xs text-bone hover:border-ember"
          >
            Next
          </button>
          <button
            type="button"
            id="replay-last"
            phx-click="scrub_last"
            class="rounded border border-ash px-2 py-1 text-xs text-bone hover:border-ember"
          >
            Last
          </button>
        </div>

        <%= if @scrubber_max > 0 do %>
          <form id="replay-scrubber-form" phx-change="scrub_range" class="max-w-md">
            <label for="replay-scrubber" class="mb-1 block text-xs text-[var(--color-smoke)]">
              Scrub timeline
            </label>
            <input
              type="range"
              id="replay-scrubber"
              name="idx"
              min="0"
              max={@scrubber_max}
              value={@selected_index}
              class="w-full accent-ember"
            />
          </form>
        <% end %>

        <div class="grid gap-6 lg:grid-cols-2">
          <div>
            <h2 class="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
              Timeline
            </h2>
            <div
              id="replay-events"
              phx-update="stream"
              class="max-h-[32rem] space-y-2 overflow-y-auto"
            >
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

  defp subscribe_run_topics(socket, %Run{} = run) do
    _ = Phoenix.PubSub.subscribe(Kiln.PubSub, "audit:run:#{run.id}")
    _ = Phoenix.PubSub.subscribe(Kiln.PubSub, "run:#{run.id}")
    _ = Phoenix.PubSub.subscribe(Kiln.PubSub, WUPubSub.run_topic(run.id))
    socket
  end

  defp parse_at_param(socket, at_raw) do
    case at_raw do
      nil ->
        {assign(socket, :selected_event_id, nil), nil}

      "" ->
        {assign(socket, :selected_event_id, nil), nil}

      raw ->
        case Ecto.UUID.cast(raw) do
          :error ->
            {put_flash(socket, :error, "Invalid event id") |> assign(:selected_event_id, nil),
             nil}

          {:ok, uuid} ->
            {assign(socket, :selected_event_id, uuid), uuid}
        end
    end
  end

  defp load_spine(%Run{} = run, selected_id) do
    case selected_id do
      nil ->
        {:ok, Audit.replay_page(run_id: run.id, limit: @page_limit, anchor: :tail)}

      id ->
        case Repo.get_by(Event, id: id, run_id: run.id) do
          nil ->
            {:unknown_at, Audit.replay_page(run_id: run.id, limit: @page_limit, anchor: :tail)}

          %Event{} = ev ->
            {:ok, page_ending_at(run.id, ev, @page_limit)}
        end
    end
  end

  defp page_ending_at(run_id, %Event{} = ev, limit) do
    rows =
      from(e in Event,
        where: e.run_id == ^run_id,
        where:
          e.occurred_at < ^ev.occurred_at or
            (e.occurred_at == ^ev.occurred_at and e.id <= ^ev.id),
        order_by: [desc: e.occurred_at, desc: e.id],
        limit: ^limit
      )
      |> Repo.all()
      |> Enum.reverse()

    oldest = List.first(rows)

    truncated_before =
      oldest &&
        Repo.exists?(
          from e in Event,
            where: e.run_id == ^run_id,
            where:
              e.occurred_at < ^oldest.occurred_at or
                (e.occurred_at == ^oldest.occurred_at and e.id < ^oldest.id)
        )

    truncated_after =
      Repo.exists?(
        from e in Event,
          where: e.run_id == ^run_id,
          where:
            e.occurred_at > ^ev.occurred_at or
              (e.occurred_at == ^ev.occurred_at and e.id > ^ev.id)
      )

    %{events: rows, truncated: truncated_before || false || truncated_after}
  end

  defp pick_selection([], _), do: {nil, 0}

  defp pick_selection(events, nil) do
    sel = List.last(events)
    {sel, max(length(events) - 1, 0)}
  end

  defp pick_selection(events, id) do
    case Enum.find_index(events, &(&1.id == id)) do
      nil ->
        sel = List.last(events)
        {sel, max(length(events) - 1, 0)}

      idx ->
        {Enum.at(events, idx), idx}
    end
  end

  defp stream_items(events) do
    Enum.map(events, fn e -> {"replay-event-#{e.id}", e} end)
  end

  defp replay_at(%Run{} = run, event_id) do
    ~p"/runs/#{run.id}/replay?#{[at: event_id]}"
  end

  defp coalesce_pubsub(socket) do
    if socket.assigns.live_edge? do
      socket =
        if socket.assigns.replay_flush_timer do
          socket
        else
          t = Process.send_after(self(), :replay_flush, @debounce_ms)
          assign(socket, :replay_flush_timer, t)
        end

      {:noreply, socket}
    else
      {:noreply, assign(socket, :pending_tail_count, socket.assigns.pending_tail_count + 1)}
    end
  end
end
