defmodule KilnWeb.TemplatesLive do
  @moduledoc """
  WFE-01 / ONB-01 — built-in template catalog at `/templates` and preview at
  `/templates/:template_id`.
  """

  use KilnWeb, :live_view

  alias Kiln.Runs
  alias Kiln.Specs
  alias Kiln.Templates
  alias Kiln.Templates.Manifest.Entry

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Templates")
     |> assign(:templates, Templates.list())
     |> assign(:selected, nil)
     |> assign(:last_promoted, nil)
     |> assign(:use_busy?, false)
     |> assign(:start_busy?, false)
     |> assign(:edit_first_busy?, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :index ->
          assign(socket, :selected, nil)

        :show ->
          resolve_show(socket, params["template_id"])
      end

    page_title =
      case socket.assigns.selected do
        %Entry{title: t} -> t
        _ -> "Templates"
      end

    {:noreply, assign(socket, :page_title, page_title)}
  end

  defp resolve_show(socket, id) when is_binary(id) and id != "" do
    case Templates.fetch(id) do
      {:ok, %Entry{} = entry} ->
        assign(socket, :selected, entry)

      {:error, :unknown_template} ->
        socket
        |> put_flash(:error, "This template is not available.")
        |> push_navigate(to: ~p"/templates")
    end
  end

  defp resolve_show(socket, _), do: assign(socket, :selected, nil)

  @impl true
  def handle_event("use_template", %{"template_id" => id}, socket) do
    socket = assign(socket, :use_busy?, true)

    case Specs.instantiate_template_promoted(id) do
      {:ok, %{spec: spec, revision: rev}} ->
        {:noreply,
         socket
         |> assign(:use_busy?, false)
         |> assign(:last_promoted, %{spec: spec, revision: rev, template_id: id})
         |> put_flash(:info, "Template applied — spec is ready.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:use_busy?, false)
         |> put_flash(:error, "Could not apply template")}
    end
  end

  def handle_event("edit_inbox_first", %{"template_id" => id}, socket) do
    socket = assign(socket, :edit_first_busy?, true)

    with {:ok, %Entry{} = entry} <- Templates.fetch(id),
         {:ok, body} <- Templates.read_spec(id) do
      case Specs.create_draft(%{
             title: entry.title,
             body: body,
             source: :markdown_import
           }) do
        {:ok, _draft} ->
          {:noreply,
           socket
           |> assign(:edit_first_busy?, false)
           |> put_flash(:info, "Draft created in inbox")
           |> push_navigate(to: ~p"/inbox")}

        {:error, _} ->
          {:noreply,
           socket
           |> assign(:edit_first_busy?, false)
           |> put_flash(:error, "Could not create draft")}
      end
    else
      _ ->
        {:noreply,
         socket
         |> assign(:edit_first_busy?, false)
         |> put_flash(:error, "Template is not available")}
    end
  end

  def handle_event("start_run", %{"template_id" => id}, socket) do
    socket = assign(socket, :start_busy?, true)

    case socket.assigns.last_promoted do
      %{spec: spec, template_id: ^id} ->
        case Runs.create_for_promoted_template(spec, id) do
          {:ok, run} ->
            {:noreply,
             socket
             |> assign(:start_busy?, false)
             |> push_navigate(to: ~p"/runs/#{run.id}")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply,
             socket
             |> assign(:start_busy?, false)
             |> put_flash(:error, "Run could not start — check workflow fields")}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:start_busy?, false)
             |> put_flash(:error, "Run could not start")}
        end

      _ ->
        {:noreply,
         socket
         |> assign(:start_busy?, false)
         |> put_flash(:error, "Apply the template first")}
    end
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
      <div id="templates-root" class="mx-auto max-w-5xl space-y-8 text-base-content">
        <header class="border-b border-base-300 pb-4">
          <p class="kiln-eyebrow">Start here</p>
          <h1 class="kiln-h1 mt-1">{@page_title}</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Built-in specs and workflows ship with Kiln — pick a template, then start a run when ready.
          </p>
        </header>

        <%= if @live_action == :index do %>
          <section aria-label="Template catalog" class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            <%= for t <- @templates do %>
              <article
                id={"template-card-#{t.id}"}
                class="flex flex-col rounded border border-base-300 bg-base-200 p-4 shadow-none"
              >
                <h2 class="text-lg font-semibold">{t.title}</h2>
                <p class="mt-2 line-clamp-4 text-sm text-base-content/60">{t.purpose}</p>
                <p class="mt-3 text-xs text-base-content/60">
                  <span class="font-medium text-base-content">
                    Typical duration (not a guarantee):
                  </span>
                  {t.time_hint}
                </p>
                <p class="mt-1 text-xs text-base-content/60">
                  <span class="font-medium text-base-content">Indicative cost (USD):</span>
                  {t.cost_hint}
                  <span class="block pt-1">
                    Actual usage varies with model, retries, and spec changes.
                  </span>
                </p>
                <div class="mt-4 flex flex-wrap gap-2">
                  <.link
                    navigate={~p"/templates/#{t.id}"}
                    class="btn btn-sm border border-base-300 bg-base-300/60 text-base-content hover:border-primary"
                  >
                    View
                  </.link>
                </div>
              </article>
            <% end %>
          </section>
        <% end %>

        <%= if @live_action == :show && @selected do %>
          <% t = @selected %>
          <section class="space-y-6 rounded border border-base-300 bg-base-200 p-6">
            <div>
              <p class="text-xs font-mono text-base-content/60">{t.id}</p>
              <h2 class="mt-1 text-xl font-semibold">{t.title}</h2>
              <p class="mt-3 text-sm text-base-content/60">{t.purpose}</p>
            </div>

            <div class="rounded border border-base-300/60 bg-base-300/30 p-3 text-sm text-base-content/60">
              <p class="font-medium text-base-content">Assumptions</p>
              <ul class="mt-2 list-disc space-y-1 pl-5">
                <%= for a <- t.assumptions do %>
                  <li>{a}</li>
                <% end %>
              </ul>
            </div>

            <div class="flex flex-wrap gap-3">
              <form id={"template-use-form-#{t.id}"} phx-submit="use_template">
                <input type="hidden" name="template_id" value={t.id} />
                <button
                  type="submit"
                  class="btn btn-sm btn-primary"
                  disabled={@use_busy?}
                >
                  {if(@use_busy?, do: "Applying…", else: "Use template")}
                </button>
              </form>

              <form id={"template-edit-first-form-#{t.id}"} phx-submit="edit_inbox_first">
                <input type="hidden" name="template_id" value={t.id} />
                <button
                  type="submit"
                  class="btn btn-sm border border-base-300 bg-base-300/60"
                  disabled={@edit_first_busy?}
                >
                  Edit in inbox first
                </button>
              </form>
            </div>

            <%= if @last_promoted && @last_promoted.template_id == t.id do %>
              <div
                id="templates-success-panel"
                class="rounded border border-primary/40 bg-base-200 p-4 text-sm text-base-content"
              >
                <p class="font-semibold">Spec promoted</p>
                <p class="mt-1 text-base-content/60">
                  {@last_promoted.spec.title} is ready. Start a queued run on the saved workflow.
                </p>
                <form id="templates-start-run-form" phx-submit="start_run" class="mt-3">
                  <input type="hidden" name="template_id" value={t.id} />
                  <button
                    type="submit"
                    id="templates-start-run"
                    class="btn btn-sm btn-primary"
                    disabled={@start_busy?}
                  >
                    {if(@start_busy?, do: "Starting…", else: "Start run")}
                  </button>
                </form>
                <p class="mt-3 text-xs text-base-content/60">
                  <%!-- TODO(D-1711): wire external_operations idempotency key template_instantiate:{template_id} when KilnWeb adopts the intent table for spec flows. Double-submit guard: buttons disabled while pending. --%>
                </p>
              </div>
            <% end %>

            <.link navigate={~p"/templates"} class="text-sm text-primary underline">
              Back to catalog
            </.link>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
