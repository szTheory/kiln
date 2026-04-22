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
    _ = Phoenix.PubSub.subscribe(Kiln.PubSub, "agent_ticker")

    runs = Runs.list_for_board()
    run_states = Map.new(runs, &{&1.id, &1.state})

    socket =
      socket
      |> assign(:page_title, "Runs")
      |> assign(:run_states, run_states)
      |> assign(:runs_empty?, runs == [])
      |> assign(:compare_baseline_id, nil)
      |> assign(:compare_candidate_id, nil)
      |> assign(:ticker_ids, [])
      |> stream(:ticker_lines, [], reset: true)

    socket =
      Enum.reduce(Run.states(), socket, fn state, acc ->
        rows = Enum.filter(runs, &(&1.state == state))
        stream(acc, stream_for(state), rows, reset: true)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_info({:agent_ticker_line, %{line: line}}, socket) do
    id = "ticker-" <> Integer.to_string(:erlang.unique_integer([:positive]))
    row = %{id: id, line: line}

    ids = [id | socket.assigns.ticker_ids]

    {socket, ids} =
      if length(ids) > 75 do
        {dropped, rest} = List.pop_at(ids, -1)
        {stream_delete(socket, :ticker_lines, %{id: dropped, line: ""}), rest}
      else
        {socket, ids}
      end

    {:noreply,
     socket
     |> assign(:ticker_ids, ids)
     |> stream_insert(:ticker_lines, row, at: 0)}
  end

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
    {:noreply, socket}
  end

  def handle_event("pick_compare_slot", %{"id" => id, "slot" => slot}, socket) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         true <- slot in ["baseline", "candidate"] do
      socket =
        case slot do
          "baseline" -> assign(socket, :compare_baseline_id, uuid)
          "candidate" -> assign(socket, :compare_candidate_id, uuid)
        end

      b = socket.assigns.compare_baseline_id
      c = socket.assigns.compare_candidate_id

      if b && c do
        q =
          URI.encode_query(%{
            "baseline" => uuid_to_string(b),
            "candidate" => uuid_to_string(c)
          })

        {:noreply,
         socket
         |> assign(:compare_baseline_id, nil)
         |> assign(:compare_candidate_id, nil)
         |> push_navigate(to: "/runs/compare?" <> q)}
      else
        {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

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
          <div
            id="compare-strip"
            class="mt-4 rounded border border-ash bg-iron/40 p-3 text-sm text-bone"
          >
            <p class="text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
              Compare
            </p>
            <div class="mt-2 flex flex-wrap gap-6">
              <div>
                <p class="text-[var(--color-smoke)]">Choose baseline run</p>
                <p class="mt-1 font-mono text-xs tabular-nums text-bone">
                  <%= if @compare_baseline_id do %>
                    {short_compare(@compare_baseline_id)}
                  <% else %>
                    <span class="text-[var(--color-smoke)]">None selected</span>
                  <% end %>
                </p>
              </div>
              <div>
                <p class="text-[var(--color-smoke)]">Choose candidate run</p>
                <p class="mt-1 font-mono text-xs tabular-nums text-bone">
                  <%= if @compare_candidate_id do %>
                    {short_compare(@compare_candidate_id)}
                  <% else %>
                    <span class="text-[var(--color-smoke)]">None selected</span>
                  <% end %>
                </p>
              </div>
            </div>
          </div>
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
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
                  <.board_run_card run={run} />
                </div>
              </div>
            </section>
          </div>
        <% end %>

        <.agent_ticker>
          <div
            id="agent-ticker"
            phx-update="stream"
            class="max-h-64 space-y-1 overflow-y-auto font-mono text-[11px] text-bone"
          >
            <div :for={{tid, row} <- @streams.ticker_lines} id={tid}>
              {row.line}
            </div>
          </div>
        </.agent_ticker>
      </div>
    </Layouts.app>
    """
  end

  attr :run, Run, required: true

  def board_run_card(assigns) do
    stages_done = run_stage_slot(assigns.run.state)
    stages_total = length(Run.states())

    assigns =
      assigns
      |> assign(:stages_done, stages_done)
      |> assign(:stages_total, stages_total)

    ~H"""
    <div class="truncate font-semibold text-ember" title={@run.id}>
      {short_id(@run.id)}
    </div>
    <div class="mt-1 truncate text-[var(--color-smoke)]">{@run.workflow_id}</div>
    <div class="mt-2">
      <%!-- RunProgress (UI-08) --%>
      <.run_progress
        run={@run}
        stages_done={@stages_done}
        stages_total={@stages_total}
        last_activity_at={@run.updated_at}
      />
    </div>
    <div class="mt-2 flex gap-1">
      <button
        type="button"
        phx-click="pick_compare_slot"
        phx-value-id={uuid_to_string(@run.id)}
        phx-value-slot="baseline"
        class="rounded border border-ash px-1.5 py-0.5 text-[10px] text-bone transition-colors hover:border-ember"
      >
        Baseline
      </button>
      <button
        type="button"
        phx-click="pick_compare_slot"
        phx-value-id={uuid_to_string(@run.id)}
        phx-value-slot="candidate"
        class="rounded border border-ash px-1.5 py-0.5 text-[10px] text-bone transition-colors hover:border-ember"
      >
        Candidate
      </button>
    </div>
    """
  end

  defp run_stage_slot(state) do
    case Enum.find_index(Run.states(), &(&1 == state)) do
      nil -> 0
      i -> i + 1
    end
  end

  defp short_id(id) do
    id |> to_string() |> String.slice(0, 8)
  end

  defp short_compare(<<_::128>> = id) do
    uuid_to_string(id) |> String.slice(0, 8)
  end

  defp uuid_to_string(<<_::128>> = raw) do
    h = Base.encode16(raw, case: :lower)

    String.slice(h, 0, 8) <>
      "-" <>
      String.slice(h, 8, 4) <>
      "-" <>
      String.slice(h, 12, 4) <>
      "-" <>
      String.slice(h, 16, 4) <>
      "-" <>
      String.slice(h, 20, 12)
  end

  defp uuid_to_string(s) when is_binary(s) do
    case Ecto.UUID.cast(s) do
      {:ok, bin} when byte_size(bin) == 16 -> uuid_to_string(bin)
      {:ok, _} -> ""
      :error -> ""
    end
  end
end
