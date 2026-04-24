defmodule KilnWeb.TemplatesLive do
  @moduledoc """
  WFE-01 / ONB-01 — built-in template catalog at `/templates` and preview at
  `/templates/:template_id`.
  """

  use KilnWeb, :live_view

  alias Kiln.DemoScenarios
  alias Kiln.OperatorSetup
  alias Kiln.Runs
  alias Kiln.Specs
  alias Kiln.Templates
  alias Kiln.Templates.Manifest.Entry

  @impl true
  def mount(_params, _session, socket) do
    templates = Templates.list()

    {:ok,
     socket
     |> assign(:page_title, "Templates")
     |> assign(:templates, templates)
     |> assign(:first_run_template, first_run_template(templates))
      |> assign(:selected, nil)
      |> assign(:setup_summary, OperatorSetup.summary())
      |> assign(:last_promoted, nil)
      |> assign(:return_to_path, nil)
      |> assign(:use_busy?, false)
      |> assign(:start_busy?, false)
      |> assign(:edit_first_busy?, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scenario = resolve_scenario(params["scenario"], socket.assigns.operator_demo_scenario)

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

    {:noreply,
     socket
     |> assign(:page_title, page_title)
     |> assign(:operator_demo_scenario, scenario)
     |> assign(:return_to_path, return_to_path(socket.assigns.live_action, params, scenario))
     |> assign(:setup_summary, OperatorSetup.summary())}
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
        case Runs.start_for_promoted_template(spec, id, return_to: socket.assigns.return_to_path) do
          {:ok, run} ->
            {:noreply,
             socket
             |> assign(:start_busy?, false)
             |> push_navigate(to: ~p"/runs/#{run.id}")}

          {:blocked, %{settings_target: settings_target}} ->
            {:noreply,
             socket
             |> assign(:start_busy?, false)
             |> put_flash(:error, "Live start blocked — fix the first missing settings step.")
             |> push_navigate(to: settings_target)}

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
      operator_demo_scenario={@operator_demo_scenario}
      operator_demo_scenarios={@operator_demo_scenarios}
    >
      <div id="templates-root" class="mx-auto max-w-5xl space-y-8 text-base-content">
        <header class="border-b border-base-300 pb-4">
          <p class="kiln-eyebrow">First live run</p>
          <h1 class="kiln-h1 mt-1">{@page_title}</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Built-in specs and workflows ship with Kiln. Start with one small believable run, then use the rest of the catalog once the first proof is real.
          </p>
        </header>

        <%= if @operator_runtime_mode == :live and not @setup_summary.ready? do %>
          <section
            id="templates-live-hero"
            class="rounded-xl border border-warning/60 bg-warning/10 p-5"
          >
            <p class="kiln-eyebrow">Disconnected live state</p>
            <h2 class="kiln-h2 mt-2">
              Template browsing is available, live execution is not ready yet
            </h2>
            <p class="kiln-body mt-2 text-sm">
              You can still inspect templates and apply one. Start run now uses the real backend preflight and will point you to the first missing settings step until the checklist is complete.
            </p>
            <div class="mt-4 flex flex-wrap gap-3 text-sm">
              <.link navigate={~p"/settings"} class="btn btn-primary btn-sm">
                Open settings checklist
              </.link>
              <.link
                navigate={~p"/onboarding?scenario=#{@operator_demo_scenario.id}"}
                class="link link-primary"
              >
                Return to onboarding
              </.link>
            </div>
          </section>
        <% end %>

        <%= if @operator_demo_scenario do %>
          <section
            id="templates-scenario-banner"
            class="rounded-xl border border-base-300 bg-base-200 p-5"
          >
            <p class="kiln-eyebrow">After the first run</p>
            <h2 class="kiln-h2 mt-2">{@operator_demo_scenario.title}</h2>
            <p class="kiln-body mt-2 text-sm">{@operator_demo_scenario.seeded_context}</p>
            <p class="kiln-meta mt-3">
              Scenario next step:
              <span class="font-semibold">
                {template_title(@templates, @operator_demo_scenario.recommended_template_id)}
              </span>
            </p>
          </section>
        <% end %>

        <%= if @live_action == :index do %>
          <section
            :if={@first_run_template}
            id="templates-first-run-hero"
            class="overflow-hidden rounded-2xl border border-primary/40 bg-base-200"
          >
            <% t = @first_run_template %>
            <div class="grid gap-6 p-6 lg:grid-cols-[1.3fr_0.9fr]">
              <article
                id={"template-card-#{t.id}"}
                class="rounded-xl border border-primary/30 bg-base-100/70 p-5"
              >
                <p class="kiln-eyebrow">Recommended first live run</p>
                <h2 class="mt-2 text-2xl font-semibold">{t.title}</h2>
                <p class="mt-3 text-sm text-base-content/70">{t.purpose}</p>
                <div class="mt-5 grid gap-3 text-sm md:grid-cols-2">
                  <article class="rounded-lg border border-base-300 bg-base-200/60 p-3">
                    <p class="kiln-eyebrow">1. Check readiness</p>
                    <p class="mt-2 text-base-content/70">
                      Confirm local setup is healthy before you spend time on a live start.
                    </p>
                  </article>
                  <article class="rounded-lg border border-base-300 bg-base-200/60 p-3">
                    <p class="kiln-eyebrow">2. Use template</p>
                    <p class="mt-2 text-base-content/70">
                      Promote the saved spec and workflow so the run starts from a known-good path.
                    </p>
                  </article>
                  <article class="rounded-lg border border-base-300 bg-base-200/60 p-3">
                    <p class="kiln-eyebrow">3. Start run</p>
                    <p class="mt-2 text-base-content/70">
                      Launch the run once the template is promoted and the live gate is clear.
                    </p>
                  </article>
                  <article class="rounded-lg border border-base-300 bg-base-200/60 p-3">
                    <p class="kiln-eyebrow">4. Inspect proof</p>
                    <p class="mt-2 text-base-content/70">
                      Open `/runs/:id` first so you can verify one real run exists and is moving.
                    </p>
                  </article>
                </div>
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
                    navigate={template_path(t.id, @operator_demo_scenario)}
                    class="btn btn-sm border border-base-300 bg-base-300/60 text-base-content hover:border-primary"
                  >
                    Open template
                  </.link>
                </div>
              </article>

              <aside class="space-y-3 rounded-xl border border-base-300 bg-base-100/40 p-5">
                <p class="kiln-eyebrow">Other built-ins stay available</p>
                <p class="text-sm text-base-content/70">
                  These are not second-class templates. They answer different jobs once the first run is believable.
                </p>
                <div class="space-y-3">
                  <%= for t <- catalog_templates(@templates) do %>
                    <div class="rounded-lg border border-base-300 bg-base-200/50 p-3">
                      <p class="kiln-eyebrow">
                        {template_role_label(t.id)}
                      </p>
                      <p class="mt-1 font-semibold">{t.title}</p>
                      <p class="mt-2 text-sm text-base-content/70">{t.purpose}</p>
                    </div>
                  <% end %>
                </div>
              </aside>
            </div>
          </section>

          <section aria-label="Template catalog" class="grid gap-4 md:grid-cols-2">
            <%= for t <- catalog_templates(@templates) do %>
              <article
                id={"template-card-#{t.id}"}
                class="flex flex-col rounded border border-base-300 bg-base-200 p-4 shadow-none"
              >
                <span id={"template-role-#{t.id}"} class="kiln-eyebrow mb-3 w-fit">
                  {template_role_label(t.id)}
                </span>
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
                    navigate={template_path(t.id, @operator_demo_scenario)}
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

            <section
              id="template-detail-next-steps"
              class="grid gap-3 rounded border border-base-300/60 bg-base-300/20 p-4 md:grid-cols-3"
            >
              <article class="space-y-1">
                <p class="kiln-eyebrow">1. Apply</p>
                <p class="kiln-body text-sm">
                  Promote the spec and workflow into Kiln so the run can use the saved inputs.
                </p>
              </article>
              <article class="space-y-1">
                <p class="kiln-eyebrow">2. Start</p>
                <p class="kiln-body text-sm">
                  Launch a run only after the template is promoted and the setup checks look healthy.
                </p>
              </article>
              <article class="space-y-1">
                <p class="kiln-eyebrow">3. Watch</p>
                <p class="kiln-body text-sm">
                  Land on run detail first for proof, then use the run board as the wider watch surface.
                </p>
              </article>
            </section>

            <div class="rounded border border-base-300/60 bg-base-300/30 p-3 text-sm text-base-content/60">
              <p class="font-medium text-base-content">Assumptions</p>
              <ul class="mt-2 list-disc space-y-1 pl-5">
                <%= for a <- t.assumptions do %>
                  <li>{a}</li>
                <% end %>
              </ul>
            </div>

            <%= if show_scenario_next_step?(@operator_demo_scenario, t) do %>
              <section
                id="template-scenario-next-step"
                class="rounded border border-base-300 bg-base-100/50 p-4 text-sm"
              >
                <p class="font-semibold">After the first run, this scenario often graduates here</p>
                <p class="mt-2 text-base-content/70">{@operator_demo_scenario.expected_outcome}</p>
              </section>
            <% end %>

            <div class="flex flex-wrap gap-3">
              <form id={"template-use-form-#{t.id}"} phx-submit="use_template">
                <input type="hidden" name="template_id" value={t.id} />
                <button
                  type="submit"
                  class="btn btn-sm btn-primary"
                  disabled={@use_busy?}
                >
                  {use_label(@operator_runtime_mode, @setup_summary, @use_busy?)}
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

            <%= if live_disconnected?(@operator_runtime_mode, @setup_summary) do %>
              <div
                id="template-live-disconnected-state"
                class="rounded border border-warning/60 bg-warning/10 p-4 text-sm"
              >
                <p class="font-semibold">
                  Live mode still needs setup before this template can complete a real run
                </p>
                <p class="mt-2 text-base-content/70">
                  You can still apply the template and attempt Start run. If a live requirement is missing, Kiln will route you to the exact settings step that needs attention.
                </p>
                <div class="mt-3 flex flex-wrap gap-3">
                  <.link navigate={~p"/settings"} class="btn btn-primary btn-sm">
                    Open settings checklist
                  </.link>
                  <.link navigate={~p"/providers"} class="link link-primary">
                    Check providers
                  </.link>
                </div>
              </div>
            <% end %>

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
                    {start_label(@operator_runtime_mode, @setup_summary, @start_busy?)}
                  </button>
                </form>
                <p class="mt-3 text-xs text-base-content/60" id="templates-watch-hint">
                  After the run starts, you land on run detail first. Use the main board after that for the wider queue view.
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

  defp live_disconnected?(:live, %{ready?: false}), do: true
  defp live_disconnected?(_, _), do: false

  defp use_label(_, _, true), do: "Applying…"
  defp use_label(_, _, false), do: "Use template"

  defp start_label(_, _, true), do: "Starting…"
  defp start_label(_, _, false), do: "Start run"

  defp template_title(templates, id) do
    case Enum.find(templates, &(&1.id == id)) do
      %Entry{title: title} -> title
      _ -> id
    end
  end

  defp first_run_template(templates), do: Enum.find(templates, &(&1.id == "hello-kiln"))

  defp catalog_templates(templates), do: Enum.reject(templates, &(&1.id == "hello-kiln"))

  defp template_role_label("gameboy-vertical-slice"), do: "Dogfood depth"
  defp template_role_label("markdown-spec-stub"), do: "Edit first path"
  defp template_role_label(_), do: "Next step"

  defp show_scenario_next_step?(nil, _template), do: false

  defp show_scenario_next_step?(scenario, template) do
    scenario.recommended_template_id == template.id and template.id != "hello-kiln"
  end

  defp template_path(id, nil), do: ~p"/templates/#{id}"
  defp template_path(id, scenario), do: ~p"/templates/#{id}?scenario=#{scenario.id}"

  defp return_to_path(:show, %{"template_id" => id}, scenario) when is_binary(id) and id != "" do
    template_path(id, scenario)
  end

  defp return_to_path(_, _, _), do: nil

  defp resolve_scenario(nil, fallback), do: fallback || DemoScenarios.default()
  defp resolve_scenario("", fallback), do: fallback || DemoScenarios.default()

  defp resolve_scenario(id, fallback) do
    case DemoScenarios.fetch(id) do
      {:ok, scenario} -> scenario
      {:error, :unknown_scenario} -> fallback || DemoScenarios.default()
    end
  end
end
