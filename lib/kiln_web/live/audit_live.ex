defmodule KilnWeb.AuditLive do
  @moduledoc """
  UI-05 — read-only audit ledger (`/audit`).
  """

  use KilnWeb, :live_view

  alias Kiln.Audit
  alias Kiln.Audit.EventKind

  @impl true
  def mount(_params, _session, socket) do
    form =
      to_form(
        %{
          "run_id" => "",
          "stage_id" => "",
          "actor_role" => "",
          "kind" => "",
          "from" => "",
          "to" => ""
        },
        as: :audit
      )

    {:ok,
     socket
     |> assign(:page_title, "Audit")
     |> assign(:form, form)
     |> assign(:events_empty?, true)
     |> stream(:events, [], reset: true)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = build_filters(params)
    events = Audit.replay(filters)
    form = params_to_form(params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:events_empty?, events == [])
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def handle_event("validate", %{"audit" => fields}, socket) do
    if allow?(socket) do
      {:noreply, assign(socket, :form, to_form(fields, as: :audit))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search", %{"audit" => fields}, socket) do
    if allow?(socket) do
      q =
        fields
        |> Enum.reject(fn {_, v} -> v in [nil, ""] end)
        |> Map.new()
        |> URI.encode_query()

      {:noreply, push_patch(socket, to: ~p"/audit?#{q}")}
    else
      {:noreply, socket}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp allow?(_socket), do: true

  defp build_filters(params) do
    []
    |> maybe_put(:run_id, uuid_or_nil(params["run_id"]))
    |> maybe_put(:stage_id, uuid_or_nil(params["stage_id"]))
    |> maybe_put(:actor_role, nonempty(params["actor_role"]))
    |> maybe_put(:event_kind, atom_kind(params["kind"]))
    |> maybe_put(:occurred_after, dt_or_nil(params["from"]))
    |> maybe_put(:occurred_before, dt_or_nil(params["to"]))
  end

  defp maybe_put(list, _k, nil), do: list
  defp maybe_put(list, k, v), do: [{k, v} | list]

  defp uuid_or_nil(""), do: nil

  defp uuid_or_nil(s) do
    case Ecto.UUID.cast(s) do
      {:ok, u} -> u
      :error -> nil
    end
  end

  defp nonempty(nil), do: nil
  defp nonempty(""), do: nil
  defp nonempty(s), do: s

  defp atom_kind(nil), do: nil
  defp atom_kind(""), do: nil

  defp atom_kind(s) do
    allowed = EventKind.values() |> Enum.map(&Atom.to_string/1)

    if s in allowed do
      String.to_existing_atom(s)
    else
      nil
    end
  end

  defp dt_or_nil(nil), do: nil
  defp dt_or_nil(""), do: nil

  defp dt_or_nil(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp params_to_form(params) do
    to_form(
      %{
        "run_id" => params["run_id"] || "",
        "stage_id" => params["stage_id"] || "",
        "actor_role" => params["actor_role"] || "",
        "kind" => params["kind"] || "",
        "from" => params["from"] || "",
        "to" => params["to"] || ""
      },
      as: :audit
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} factory_summary={@factory_summary}>
      <div id="audit-ledger" class="space-y-6 text-bone">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold">Audit</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            Read-only ledger (limit 500). Narrow filters when exporting mentally.
          </p>
        </div>

        <.form
          for={@form}
          id="audit-filter-form"
          phx-change="validate"
          phx-submit="search"
          class="space-y-3"
        >
          <div class="grid gap-3 md:grid-cols-2">
            <.input field={@form[:run_id]} type="text" label="Run id" />
            <.input field={@form[:stage_id]} type="text" label="Stage id" />
            <.input field={@form[:actor_role]} type="text" label="Actor role" />
            <.input field={@form[:kind]} type="text" label="Event kind" />
            <.input field={@form[:from]} type="text" label="From (ISO-8601)" />
            <.input field={@form[:to]} type="text" label="To (ISO-8601)" />
          </div>
          <button type="submit" class="btn btn-primary btn-sm">Search</button>
        </.form>

        <%= if @events_empty? do %>
          <p class="text-sm text-[var(--color-smoke)]">No events match these filters</p>
          <p class="text-xs text-[var(--color-smoke)]">
            Widen the time range or clear filters. Audit data is read-only.
          </p>
        <% else %>
          <div id="audit-events" phx-update="stream" class="space-y-2">
            <details
              :for={{id, ev} <- @streams.events}
              id={id}
              class="rounded border border-ash bg-char/80 p-3 text-xs text-bone"
            >
              <summary class="cursor-pointer font-semibold">{inspect(ev.event_kind)}</summary>
              <pre class="mt-2 overflow-x-auto text-[var(--color-smoke)] phx-no-curly-interpolation">{Jason.encode!(ev.payload, pretty: true)}</pre>
            </details>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
