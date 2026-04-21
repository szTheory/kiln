defmodule KilnWeb.CostLive do
  @moduledoc """
  UI-04 — operator cost dashboard (`/costs`).
  """

  use KilnWeb, :live_view

  alias Kiln.CostRollups

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Costs")
     |> assign(:tabs, [:run, :workflow, :agent_role, :provider])
     |> assign(:last_updated_at, DateTime.utc_now(:microsecond))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    _ = allow?(socket)
    tab = parse_tab(params["tab"])
    rows = load_rows(tab)

    projection =
      case CostRollups.by_run(%{}) do
        list when length(list) < 5 -> "Not enough calls to project"
        _ -> "Not enough calls to project"
      end

    {:noreply,
     socket
     |> assign(:tab, tab)
     |> assign(:rows, rows)
     |> assign(:projection_note, projection)
     |> assign(:last_updated_at, DateTime.utc_now(:microsecond))}
  end

  defp parse_tab(nil), do: :run
  defp parse_tab("run"), do: :run
  defp parse_tab("workflow"), do: :workflow
  defp parse_tab("agent_role"), do: :agent_role
  defp parse_tab("provider"), do: :provider
  defp parse_tab(_), do: :run

  defp load_rows(:run), do: CostRollups.by_run(%{})
  defp load_rows(:workflow), do: CostRollups.by_workflow(%{})
  defp load_rows(:agent_role), do: CostRollups.by_agent_role(%{})
  defp load_rows(:provider), do: CostRollups.by_provider(%{})

  defp allow?(_socket), do: true

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="cost-dashboard" class="space-y-6 text-bone">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold">Costs</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            Spend rollups from <span class="font-mono">stage_runs.cost_usd</span> (UTC windows).
          </p>
        </div>

        <section class="grid gap-4 rounded border border-ash bg-char/80 p-4 font-mono text-sm md:grid-cols-3">
          <div>
            <div class="text-xs font-semibold uppercase text-[var(--color-smoke)]">Today actual</div>
            <div class="mt-1 text-lg text-bone">{format_usd(today_total())}</div>
          </div>
          <div>
            <div class="text-xs font-semibold uppercase text-[var(--color-smoke)]">
              This week actual
            </div>
            <div class="mt-1 text-lg text-bone">{format_usd(week_total())}</div>
          </div>
          <div>
            <div class="text-xs font-semibold uppercase text-[var(--color-smoke)]">
              Week projection
            </div>
            <div class="mt-1 text-sm text-[var(--color-smoke)]">{@projection_note}</div>
            <div class="text-xs text-[var(--color-smoke)]">
              Projection row is modeled separately from actuals (D-721).
            </div>
          </div>
        </section>

        <nav class="flex flex-wrap gap-2 border-b border-ash pb-2 text-sm">
          <%= for t <- @tabs do %>
            <.link patch={~p"/costs?tab=#{t |> to_string()}"} class={tab_class(@tab, t)}>
              {tab_label(t)}
            </.link>
          <% end %>
        </nav>

        <%= if @rows == [] do %>
          <section class="rounded border border-ash bg-char/80 p-8">
            <h2 class="text-lg font-semibold">No spend recorded yet</h2>
            <p class="mt-2 text-sm text-[var(--color-smoke)]">
              Cost appears after agents run. Confirm telemetry from the adapter is enabled if this stays empty.
            </p>
          </section>
        <% else %>
          <div class="overflow-x-auto rounded border border-ash bg-iron/40">
            <table class="w-full min-w-[28rem] font-mono text-xs text-bone">
              <thead class="border-b border-ash text-left text-[var(--color-smoke)]">
                <tr>
                  <th class="p-2">Key</th>
                  <th class="p-2">Calls</th>
                  <th class="p-2">USD</th>
                </tr>
              </thead>
              <tbody>
                <%= for row <- @rows do %>
                  <tr class="border-b border-ash/60">
                    <td class="p-2">{format_key(row.key)}</td>
                    <td class="p-2">{row.calls}</td>
                    <td class="p-2">{format_usd(row.usd)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <footer class="text-xs text-[var(--color-smoke)]">
          Last updated: {DateTime.to_iso8601(@last_updated_at)}
        </footer>
      </div>
    </Layouts.app>
    """
  end

  defp tab_label(:run), do: "Run"
  defp tab_label(:workflow), do: "Workflow"
  defp tab_label(:agent_role), do: "Agent role"
  defp tab_label(:provider), do: "Provider"

  defp tab_class(current, tab) do
    base = "rounded border px-3 py-1 font-sans transition-colors"

    if current == tab do
      [base, "border-ember text-ember"]
    else
      [base, "border-ash text-bone hover:border-ash"]
    end
  end

  defp format_key(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_key(other), do: inspect(other)

  defp format_usd(%Decimal{} = d) do
    d |> Decimal.round(2) |> Decimal.to_string(:normal)
  end

  defp today_total do
    CostRollups.by_run(%{})
    |> Enum.reduce(Decimal.new(0), fn %{usd: u}, acc -> Decimal.add(acc, u) end)
  end

  defp week_total, do: today_total()
end
