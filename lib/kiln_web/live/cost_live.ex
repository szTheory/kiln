defmodule KilnWeb.CostLive do
  @moduledoc """
  UI-04 — operator cost dashboard (`/costs`).

  UI-08 / OPS-04 — **Intel** segment at `?tab=intel` with `period=` and `pivot=`
  query toggles (same LiveView, D-802).
  """

  use KilnWeb, :live_view

  alias Kiln.CostRollups

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Costs")
     |> assign(:pivot_tabs, [:run, :workflow, :agent_role, :provider])
     |> assign(:last_updated_at, DateTime.utc_now(:microsecond))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {surface, pivot, period} = parse_surface_pivot_period(params)

    rows =
      case surface do
        :summary -> load_rows_for_pivot(pivot)
        :intel -> load_rows_for_pivot(pivot, window_for_period(period))
      end

    intel_advisory =
      case surface do
        :intel -> build_intel_advisory(rows, pivot, period)
        :summary -> nil
      end

    projection =
      case CostRollups.by_run(%{}) do
        list when length(list) < 5 -> "Not enough calls to project"
        _ -> "Not enough calls to project"
      end

    {:noreply,
     socket
     |> assign(:surface, surface)
     |> assign(:pivot, pivot)
     |> assign(:period, period)
     |> assign(:rows, rows)
     |> assign(:intel_advisory, intel_advisory)
     |> assign(:projection_note, projection)
     |> assign(:last_updated_at, DateTime.utc_now(:microsecond))}
  end

  defp parse_surface_pivot_period(params) do
    t = params["tab"]

    cond do
      t == "intel" ->
        {:intel, parse_pivot(params["pivot"], :provider), parse_period(params["period"], :week)}

      t in ["run", "workflow", "agent_role", "provider"] ->
        {:summary, String.to_existing_atom(t), :week}

      t == "summary" or is_nil(t) ->
        {:summary, parse_pivot(params["pivot"], :run), :week}

      true ->
        {:summary, :run, :week}
    end
  end

  defp parse_pivot(nil, default), do: default

  defp parse_pivot(name, _default) when name in ["run", "workflow", "agent_role", "provider"],
    do: String.to_existing_atom(name)

  defp parse_pivot(_, default), do: default

  defp parse_period(nil, default), do: default

  defp parse_period(name, _default) when name in ["day", "week", "month"],
    do: String.to_existing_atom(name)

  defp parse_period(_, default), do: default

  defp load_rows_for_pivot(pivot), do: load_rows_for_pivot(pivot, nil)

  defp load_rows_for_pivot(:run, nil), do: CostRollups.by_run(%{})
  defp load_rows_for_pivot(:workflow, nil), do: CostRollups.by_workflow(%{})
  defp load_rows_for_pivot(:agent_role, nil), do: CostRollups.by_agent_role(%{})
  defp load_rows_for_pivot(:provider, nil), do: CostRollups.by_provider(%{})

  defp load_rows_for_pivot(:run, %{from: f, to: t}), do: CostRollups.by_run(%{from: f, to: t})

  defp load_rows_for_pivot(:workflow, %{from: f, to: t}),
    do: CostRollups.by_workflow(%{from: f, to: t})

  defp load_rows_for_pivot(:agent_role, %{from: f, to: t}),
    do: CostRollups.by_agent_role(%{from: f, to: t})

  defp load_rows_for_pivot(:provider, %{from: f, to: t}),
    do: CostRollups.by_provider(%{from: f, to: t})

  defp window_for_period(period) do
    to = DateTime.utc_now(:microsecond)

    from =
      case period do
        :day -> utc_start_of_day(to)
        :week -> week_start_monday_utc(to)
        :month -> month_start_utc(to)
      end

    %{from: from, to: to}
  end

  defp utc_start_of_day(%DateTime{} = dt) do
    DateTime.new!(DateTime.to_date(dt), ~T[00:00:00.000000], "Etc/UTC")
  end

  defp week_start_monday_utc(%DateTime{} = to) do
    d = DateTime.to_date(to)
    mon = Date.beginning_of_week(d, :monday)
    DateTime.new!(mon, ~T[00:00:00.000000], "Etc/UTC")
  end

  defp month_start_utc(%DateTime{} = to) do
    d = DateTime.to_date(to)
    DateTime.new!(Date.new!(d.year, d.month, 1), ~T[00:00:00.000000], "Etc/UTC")
  end

  defp build_intel_advisory(rows, pivot, period) do
    total = Enum.reduce(rows, Decimal.new(0), fn %{usd: u}, acc -> Decimal.add(acc, u) end)
    calls = Enum.reduce(rows, 0, fn %{calls: c}, acc -> acc + c end)

    cond do
      rows == [] ->
        nil

      Decimal.compare(total, Decimal.new(0)) != :gt ->
        nil

      true ->
        [first | rest] = rows

        top =
          Enum.reduce(rest, first, fn row, best ->
            case Decimal.compare(row.usd, best.usd) do
              :gt -> row
              _ -> best
            end
          end)

        top_label = format_key(top.key)

        "You're spending $#{format_usd(total)} this #{period_copy(period)} across #{calls} calls — top #{pivot_copy(pivot)} profile: #{top_label}."
    end
  end

  defp period_copy(:day), do: "day"
  defp period_copy(:week), do: "week"
  defp period_copy(:month), do: "month"

  defp pivot_copy(:run), do: "run"
  defp pivot_copy(:workflow), do: "workflow"
  defp pivot_copy(:agent_role), do: "agent role"
  defp pivot_copy(:provider), do: "provider"

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

        <nav class="flex flex-wrap gap-2 border-b border-ash pb-2 text-sm" aria-label="Cost views">
          <.link
            patch={~p"/costs?#{[tab: "summary", pivot: to_string(@pivot)]}"}
            class={surface_class(@surface, :summary)}
          >
            Summary
          </.link>
          <.link
            patch={~p"/costs?#{[tab: "intel", pivot: to_string(@pivot), period: to_string(@period)]}"}
            class={surface_class(@surface, :intel)}
          >
            Intel
          </.link>
        </nav>

        <%= if @surface == :intel do %>
          <section class="rounded border border-ash bg-char/80 p-4 text-sm text-bone">
            <h2 class="text-xs font-semibold uppercase text-[var(--color-smoke)]">Advisory</h2>
            <%= if @intel_advisory do %>
              <p class="mt-2 leading-relaxed text-bone">{@intel_advisory}</p>
            <% else %>
              <p class="mt-2 text-[var(--color-smoke)]">Not enough history for an advisory yet</p>
            <% end %>
          </section>

          <nav
            class="flex flex-wrap gap-2 text-xs text-[var(--color-smoke)]"
            aria-label="Intel period"
          >
            <%= for p <- [:day, :week, :month] do %>
              <.link
                patch={~p"/costs?#{[tab: "intel", pivot: to_string(@pivot), period: to_string(p)]}"}
                class={period_class(@period, p)}
              >
                {String.capitalize(to_string(p))}
              </.link>
            <% end %>
          </nav>
        <% end %>

        <nav class="flex flex-wrap gap-2 border-b border-ash pb-2 text-sm" aria-label="Pivot">
          <%= for t <- @pivot_tabs do %>
            <.link
              patch={~p"/costs?#{pivot_query_attrs(@surface, @period, t)}"}
              class={tab_class(@pivot, t)}
            >
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

  defp pivot_query_attrs(:summary, _period, pivot), do: [tab: "summary", pivot: to_string(pivot)]

  defp pivot_query_attrs(:intel, period, pivot),
    do: [tab: "intel", pivot: to_string(pivot), period: to_string(period)]

  defp surface_class(current, tab) do
    base = "rounded border px-3 py-1 font-sans transition-colors"

    if current == tab do
      [base, "border-ember text-ember"]
    else
      [base, "border-ash text-bone hover:border-ash"]
    end
  end

  defp period_class(current, p) do
    base = "rounded border px-2 py-0.5 font-mono transition-colors"

    if current == p do
      [base, "border-ember text-ember"]
    else
      [base, "border-ash text-bone hover:border-ash"]
    end
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
