defmodule KilnWeb.WorkflowLive do
  @moduledoc """
  UI-03 — read-only workflow registry (`/workflows`).

  Editing stays out of the browser; YAML is loaded from disk snapshots only.
  """

  use KilnWeb, :live_view

  alias Kiln.Workflows

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workflows")
     |> assign(:snapshots, [])
     |> assign(:selected_snapshot, nil)
     |> assign(:yaml_text, nil)
     |> assign(:workflow_id, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :index ->
          snaps = Workflows.list_recent_snapshots(limit: 50)
          selected = List.first(snaps)

          socket
          |> assign(:snapshots, snaps)
          |> assign(:selected_snapshot, selected)
          |> assign(:yaml_text, selected && selected.yaml_body)

        :show ->
          wid = params["workflow_id"]
          snaps = Workflows.list_snapshots_for(wid, limit: 20)
          selected = List.first(snaps)

          socket
          |> assign(:workflow_id, wid)
          |> assign(:snapshots, snaps)
          |> assign(:selected_snapshot, selected)
          |> assign(:yaml_text, selected && selected.yaml_body)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(_evt, _params, socket), do: {:noreply, socket}

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
      <div id="workflow-registry" class="space-y-6 text-bone">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold">Workflows</h1>
          <p class="mt-1 max-w-3xl text-sm text-[var(--color-smoke)]">
            Snapshots capture each successful load from disk. Editing stays out of the browser — change YAML in the repo, then reload.
          </p>
        </div>

        <%= if @snapshots == [] do %>
          <section class="rounded border border-ash bg-char/80 p-8">
            <h2 class="text-lg font-semibold">No workflows loaded</h2>
            <p class="mt-2 text-sm text-[var(--color-smoke)]">
              Load a workflow from disk to inspect YAML and version history here. Editing stays out of the browser.
            </p>
          </section>
        <% else %>
          <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
            <aside class="rounded border border-ash bg-char/80 p-4">
              <h2 class="text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Snapshots
              </h2>
              <ul class="mt-3 space-y-2 font-mono text-xs">
                <%= for s <- @snapshots do %>
                  <li>
                    <.link
                      navigate={~p"/workflows/#{s.workflow_id}"}
                      class="block truncate text-ember underline"
                    >
                      {s.workflow_id} v{s.version}
                    </.link>
                    <div class="text-[var(--color-smoke)]">
                      {DateTime.to_iso8601(s.inserted_at)}
                    </div>
                  </li>
                <% end %>
              </ul>
            </aside>

            <section class="rounded border border-ash bg-iron/40 p-4">
              <h2 class="text-xs font-semibold uppercase tracking-wide text-[var(--color-smoke)]">
                Loaded definitions
              </h2>
              <%= if @yaml_text && @yaml_text != "" do %>
                <pre class="mt-3 max-h-[40rem] overflow-auto text-xs text-bone phx-no-curly-interpolation">{@yaml_text}</pre>
              <% else %>
                <p class="mt-3 text-sm text-[var(--color-smoke)]">
                  <%= if @selected_snapshot && @selected_snapshot.truncated do %>
                    YAML omitted (snapshot truncated at load time). Checksum: {@selected_snapshot.compiled_checksum}
                  <% else %>
                    No YAML body stored for this snapshot.
                  <% end %>
                </p>
              <% end %>
            </section>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
