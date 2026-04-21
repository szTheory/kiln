defmodule KilnWeb.RunDetailLive do
  @moduledoc """
  UI-02 — run inspection at `/runs/:run_id` with `?stage=<workflow_stage_id>&pane=`.

  * **Stage param** matches YAML `stages[].id` (`StageRun.workflow_stage_id`).
  * **Graph order:** `Kiln.Workflows.graph_for_run/1` when on-disk workflow checksum
    matches the run; otherwise a linear v1 fallback from persisted `stage_runs`.
  * **Diff pane:** first artifact on the latest stage attempt whose `name` ends with
    `.diff` or `.patch`, loaded via `Artifacts.read!/1`, capped at 512 KiB (D-713).

  * **File as follow-up** (INTAKE-03): shown only when `run.state == :merged` — creates
    an inbox draft idempotently keyed per LiveView mount (`correlation_id`).
  """

  use KilnWeb, :live_view

  alias Kiln.Artifacts
  alias Kiln.Audit
  alias Kiln.Blockers.Reason
  alias Kiln.Runs
  alias Kiln.Runs.Run
  alias Kiln.Runs.Transitions
  alias Kiln.Specs
  alias Kiln.Stages
  alias Kiln.Stages.StageRun
  alias Kiln.Workflows

  @max_diff_bytes 524_288
  @panes ~w(diff logs events chatter)

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
            stages = Stages.list_for_run(run.id)
            graph_ids = Workflows.graph_for_run(run)
            latest = Workflows.latest_stage_runs_for(run.id)

            follow_cor =
              if run.state == :merged, do: Ecto.UUID.generate(), else: nil

            block_reason = infer_block_reason(run)

            {:ok,
             socket
             |> assign(:page_title, "Run #{short(uuid)}")
             |> assign(:run, run)
             |> assign(:block_reason, block_reason)
             |> assign(:follow_up_correlation_id, follow_cor)
             |> assign(:graph_ids, graph_ids)
             |> assign(:latest_by_stage, latest)
             |> assign(:stages, stages)
             |> stream(:logs, [], reset: true)
             |> stream(:events, [], reset: true)
             |> stream(:chatter, [], reset: true)}
        end
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    pane = parse_pane(params["pane"])
    stage_param = params["stage"]
    run = socket.assigns.run
    latest = Workflows.latest_stage_runs_for(run.id)

    {selected, stage_missing?} = resolve_selection(stage_param, latest)

    diff_text = diff_for_selected(selected, run.id)

    events =
      case selected do
        %StageRun{id: sid} ->
          Audit.replay(run_id: run.id)
          |> Enum.filter(&(&1.stage_id == sid))

        _ ->
          []
      end

    logs = log_rows(selected)

    socket =
      socket
      |> assign(:pane, pane)
      |> assign(:selected_stage_run, selected)
      |> assign(:stage_missing?, stage_missing?)
      |> assign(:diff_text, diff_text)
      |> stream(:logs, logs, reset: true)
      |> stream(:events, events, reset: true)
      |> stream(:chatter, placeholder_chatter(), reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("pick_stage", %{"wid" => wid}, socket) do
    if allow?(socket) do
      {:noreply,
       push_patch(socket,
         to:
           ~p"/runs/#{socket.assigns.run.id}?#{%{stage: wid, pane: socket.assigns.pane} |> URI.encode_query()}"
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("unblock_retry", %{"to" => to}, socket) do
    if allow?(socket) do
      allowed = %{
        "planning" => :planning,
        "coding" => :coding,
        "testing" => :testing,
        "verifying" => :verifying
      }

      run = socket.assigns.run

      case Map.get(allowed, to) do
        nil ->
          {:noreply, put_flash(socket, :error, "Invalid resume target")}

        target ->
          case Transitions.transition(run.id, target, %{reason: :operator_unblock}) do
            {:ok, updated} ->
              {:noreply,
               socket
               |> assign(:run, updated)
               |> assign(:block_reason, infer_block_reason(updated))
               |> put_flash(:info, "Resumed run at #{target}")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Resume failed: #{inspect(reason)}")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("bundle_diagnostics", _params, socket) do
    if allow?(socket) do
      run = socket.assigns.run

      {:noreply,
       socket
       |> put_flash(:info, "Diagnostic bundle ready")
       |> push_navigate(to: ~p"/runs/#{run.id}/diagnostics/bundle.zip")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("follow_up", _params, socket) do
    if allow?(socket) do
      run = socket.assigns.run
      cid = socket.assigns.follow_up_correlation_id

      cond do
        run.state != :merged or is_nil(cid) ->
          {:noreply, put_flash(socket, :error, "Follow-up is not available for this run.")}

        true ->
          case Specs.file_follow_up_from_run(run, correlation_id: cid) do
            {:ok, _draft} ->
              {:noreply,
               socket
               |> put_flash(:info, "Draft created — open the Inbox to edit.")}

            {:error, reason} ->
              {:noreply,
               put_flash(socket, :error, "Could not create draft: #{inspect(reason)}")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event(_other, _params, socket), do: {:noreply, socket}

  defp allow?(_socket), do: true

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} factory_summary={@factory_summary}>
      <div id="run-detail" class="space-y-6 text-bone">
        <div class="flex flex-wrap items-end justify-between gap-4 border-b border-ash pb-4">
          <div class="flex flex-wrap items-end gap-4">
            <div>
              <p class="font-mono text-xs text-[var(--color-smoke)]">{@run.id}</p>
              <h1 class="text-xl font-semibold">Run {@run.workflow_id}</h1>
            </div>
            <%!-- RunProgress (UI-08) --%>
            <.run_progress
              run={@run}
              stages_done={run_stage_slot(@run.state)}
              stages_total={length(Run.states())}
              last_activity_at={@run.updated_at}
            />
          </div>
          <div class="flex flex-wrap items-center gap-3">
            <%= if @run.state == :merged && @follow_up_correlation_id do %>
              <button
                type="button"
                id="follow-up-btn"
                phx-click="follow_up"
                class="rounded border border-clay px-3 py-1.5 text-sm font-semibold text-bone transition-colors hover:bg-clay/20"
              >
                File as follow-up
              </button>
              <.link class="text-sm text-ember underline" navigate={~p"/inbox"}>Inbox</.link>
            <% end %>
            <button
              type="button"
              id="bundle-diagnostics-btn"
              phx-click="bundle_diagnostics"
              class="rounded border border-ash px-3 py-1.5 text-sm text-bone transition-colors hover:border-ember hover:text-ember"
            >
              Bundle last 60 minutes
            </button>
            <.link class="text-sm text-ember underline" navigate={~p"/"}>← Runs</.link>
          </div>
        </div>

        <%= if @run.state == :blocked && @block_reason do %>
          <.unblock_panel run={@run} block_reason={@block_reason} />
        <% end %>

        <section class="rounded border border-ash bg-char/80 p-4">
          <h2 class="text-sm font-semibold text-[var(--color-smoke)]">Stages</h2>
          <ol class="mt-3 flex flex-wrap gap-2">
            <%= for wid <- @graph_ids do %>
              <li>
                <button
                  type="button"
                  phx-click="pick_stage"
                  phx-value-wid={wid}
                  class={[
                    "rounded border px-2 py-1 font-mono text-xs",
                    selected_wid?(@selected_stage_run, wid) && "border-ember text-ember",
                    !selected_wid?(@selected_stage_run, wid) && "border-ash text-bone"
                  ]}
                >
                  {wid}
                </button>
              </li>
            <% end %>
          </ol>
        </section>

        <%= cond do %>
          <% @stage_missing? -> %>
            <p class="text-sm text-[var(--color-clay)]">Stage not found</p>
          <% is_nil(@selected_stage_run) -> %>
            <section class="rounded border border-ash bg-char/80 p-6">
              <h2 class="text-lg font-semibold">Select a stage</h2>
              <p class="mt-2 text-sm text-[var(--color-smoke)]">
                Choose a stage in the graph to inspect diff, logs, events, and agent output.
              </p>
            </section>
          <% true -> %>
            <.pane_toolbar run={@run} selected={@selected_stage_run} pane={@pane} />

            <%= case @pane do %>
              <% "diff" -> %>
                <section class="rounded border border-ash bg-iron/40 p-4">
                  <pre class="max-h-[32rem] overflow-auto whitespace-pre-wrap font-mono text-xs text-bone phx-no-curly-interpolation">{@diff_text}</pre>
                </section>
              <% "logs" -> %>
                <section class="rounded border border-ash bg-iron/40 p-2">
                  <div id="run-detail-logs" phx-update="stream" class="space-y-1 font-mono text-xs">
                    <div :for={{id, row} <- @streams.logs} id={id} class="text-bone">{row.line}</div>
                  </div>
                </section>
              <% "events" -> %>
                <section class="rounded border border-ash bg-iron/40 p-2">
                  <div id="run-detail-events" phx-update="stream" class="space-y-2">
                    <details
                      :for={{id, ev} <- @streams.events}
                      id={id}
                      class="rounded border border-ash bg-char/80 p-2 text-xs text-bone"
                    >
                      <summary class="cursor-pointer font-semibold">{inspect(ev.event_kind)}</summary>
                      <pre class="mt-2 overflow-x-auto text-[var(--color-smoke)] phx-no-curly-interpolation">{Jason.encode!(ev.payload, pretty: true)}</pre>
                    </details>
                  </div>
                </section>
              <% "chatter" -> %>
                <section class="rounded border border-ash bg-iron/40 p-4 text-sm text-[var(--color-smoke)]">
                  <div id="run-detail-chatter" phx-update="stream">
                    <div :for={{id, row} <- @streams.chatter} id={id}>{row.line}</div>
                  </div>
                </section>
            <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :run, :any, required: true
  attr :selected, :any, required: true
  attr :pane, :string, required: true

  def pane_toolbar(assigns) do
    wid =
      case assigns.selected do
        %StageRun{workflow_stage_id: w} -> w
        _ -> ""
      end

    assigns = assign(assigns, :stage_q, wid)

    ~H"""
    <nav class="flex flex-wrap gap-2 border-b border-ash pb-3 text-sm" aria-label="Panes">
      <.link patch={~p"/runs/#{@run.id}?#{qs(@stage_q, "diff")}"} class={tab_class(@pane, "diff")}>
        Diff
      </.link>
      <.link patch={~p"/runs/#{@run.id}?#{qs(@stage_q, "logs")}"} class={tab_class(@pane, "logs")}>
        Logs
      </.link>
      <.link patch={~p"/runs/#{@run.id}?#{qs(@stage_q, "events")}"} class={tab_class(@pane, "events")}>
        Events
      </.link>
      <.link
        patch={~p"/runs/#{@run.id}?#{qs(@stage_q, "chatter")}"}
        class={tab_class(@pane, "chatter")}
      >
        Chatter
      </.link>
    </nav>
    """
  end

  defp qs("", pane), do: URI.encode_query(%{pane: pane})
  defp qs(stage, pane), do: URI.encode_query(%{stage: stage, pane: pane})

  defp tab_class(current, pane) do
    base = "rounded border px-3 py-1 font-sans transition-colors"

    if current == pane do
      [base, "border-ember text-ember"]
    else
      [base, "border-ash text-bone hover:border-ash"]
    end
  end

  defp selected_wid?(%StageRun{workflow_stage_id: a}, b) when a == b, do: true
  defp selected_wid?(_, _), do: false

  defp parse_pane(nil), do: "diff"

  defp parse_pane(p) when p in @panes, do: p
  defp parse_pane(_), do: "diff"

  defp resolve_selection(wid, _latest) when wid in [nil, ""], do: {nil, false}

  defp resolve_selection(wid, latest) do
    case Map.get(latest, wid) do
      %StageRun{} = sr -> {sr, false}
      _ -> {nil, true}
    end
  end

  defp log_rows(nil), do: [%{id: "logs-empty", line: "No log lines for this stage yet"}]

  defp log_rows(%StageRun{error_summary: s}) when is_binary(s) and s != "",
    do: [%{id: "logs-summary", line: s}]

  defp log_rows(%StageRun{}),
    do: [%{id: "logs-empty", line: "No log lines for this stage yet"}]

  defp placeholder_chatter do
    [%{id: "chatter-empty", line: "No agent messages for this stage yet"}]
  end

  defp diff_for_selected(nil, _), do: ""

  defp diff_for_selected(%StageRun{id: sid, state: :succeeded}, _run_id) do
    sid
    |> Artifacts.list_for_stage_run()
    |> Enum.find(fn %{name: n} ->
      String.ends_with?(n, ".diff") or String.ends_with?(n, ".patch")
    end)
    |> case do
      nil ->
        ""

      %{name: name} ->
        {:ok, art} = Artifacts.get(sid, name)
        body = Artifacts.read!(art)

        if byte_size(body) > @max_diff_bytes do
          binary_part(body, 0, @max_diff_bytes) <> "\n\n[truncated at 512 KiB]"
        else
          body
        end
    end
  end

  defp diff_for_selected(%StageRun{}, _), do: ""

  defp infer_block_reason(%Run{state: :blocked, id: rid}) do
    Audit.replay(run_id: rid, limit: 200)
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{event_kind: :run_state_transitioned, payload: %{"to" => "blocked", "reason" => r}}
      when is_binary(r) ->
        blocked_reason_from_audit_string(r)

      _ ->
        nil
    end) || :missing_api_key
  end

  defp infer_block_reason(_), do: nil

  defp blocked_reason_from_audit_string(s) do
    Reason.all()
    |> Enum.find(fn a -> Atom.to_string(a) == s end)
    |> case do
      nil -> :missing_api_key
      a -> a
    end
  end

  defp short(uuid), do: uuid |> to_string() |> String.slice(0, 8)

  defp run_stage_slot(state) do
    case Enum.find_index(Run.states(), &(&1 == state)) do
      nil -> 0
      i -> i + 1
    end
  end
end
