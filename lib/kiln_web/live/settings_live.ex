defmodule KilnWeb.SettingsLive do
  @moduledoc """
  Operator configuration hub for live-mode readiness.
  """

  use KilnWeb, :live_view

  alias Kiln.OperatorReadiness
  alias Kiln.OperatorSetup

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:setup_summary, OperatorSetup.summary())
     |> assign(:return_context, nil)
     |> assign(:last_verified, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, :return_context, return_context(params))}
  end

  @impl true
  def handle_event("verify_anthropic", _, socket) do
    result = OperatorReadiness.probe_anthropic_configured?()
    {:ok, _} = OperatorReadiness.mark_step(:anthropic, result)
    {:noreply, after_verify(socket, :anthropic, result, "Anthropic reference still missing")}
  end

  def handle_event("verify_github", _, socket) do
    result = OperatorReadiness.probe_github_cli?()
    {:ok, _} = OperatorReadiness.mark_step(:github, result)
    {:noreply, after_verify(socket, :github, result, "GitHub CLI is still not authenticated")}
  end

  def handle_event("verify_docker", _, socket) do
    result = OperatorReadiness.probe_docker?()
    {:ok, _} = OperatorReadiness.mark_step(:docker, result)
    {:noreply, after_verify(socket, :docker, result, "Docker is still not reachable")}
  end

  defp after_verify(socket, step, true, _error_copy) do
    socket
    |> assign(:setup_summary, OperatorSetup.summary())
    |> assign(:last_verified, step)
    |> put_flash(:info, "Verified")
  end

  defp after_verify(socket, step, false, error_copy) do
    socket
    |> assign(:setup_summary, OperatorSetup.summary())
    |> assign(:last_verified, step)
    |> put_flash(:error, error_copy)
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
      <div id="settings-root" class="space-y-6">
        <header class="border-b border-base-300 pb-4">
          <p class="kiln-eyebrow">Configuration</p>
          <h1 class="kiln-h1 mt-1">Settings</h1>
          <p class="kiln-meta mt-1">
            One place to see what live mode still needs, why it matters, and what to do next.
          </p>
        </header>

        <section id="settings-summary" class="grid gap-4 lg:grid-cols-[1.25fr_1fr]">
          <article class="rounded-xl border border-base-300 bg-base-200 p-5">
            <p class="kiln-eyebrow">Live readiness</p>
            <h2 class="kiln-h2 mt-2">
              <%= if @setup_summary.ready? do %>
                Ready for live-mode setup-sensitive paths
              <% else %>
                Live mode still has a few missing pieces
              <% end %>
            </h2>
            <p class="kiln-body mt-2 text-sm">
              <%= if @setup_summary.ready? do %>
                The current machine passes the core local checks for a believable first live project path.
              <% else %>
                Pages that depend on live execution will stay explorable, but they will show disconnected hero states until these blockers are resolved.
              <% end %>
            </p>
            <%= if @setup_summary.blockers != [] do %>
              <ul class="mt-4 list-disc space-y-1 pl-5 text-sm text-base-content/70">
                <%= for blocker <- @setup_summary.blockers do %>
                  <li>{blocker.title}</li>
                <% end %>
              </ul>
            <% end %>
            <p id="settings-current-journey" class="kiln-meta mt-4">
              Current journey: {@operator_demo_scenario.title}. {journey_copy(@operator_demo_scenario)}
            </p>
          </article>

          <article
            id="settings-provider-matrix"
            class="rounded-xl border border-base-300 bg-base-200 p-5"
          >
            <p class="kiln-eyebrow">Provider matrix</p>
            <div class="mt-4 space-y-3">
              <%= for provider <- @setup_summary.providers do %>
                <div
                  id={"settings-provider-#{provider.id}"}
                  class="flex items-start justify-between gap-4 rounded-lg border border-base-300/70 bg-base-100/40 p-3"
                >
                  <div>
                    <p class="font-semibold">{provider.name}</p>
                    <p class="kiln-meta mt-1">{provider.note}</p>
                  </div>
                  <span class={[
                    "kiln-chip",
                    provider.configured? && "kiln-chip--ok",
                    !provider.configured? && "kiln-chip--warn"
                  ]}>
                    {if(provider.configured?, do: "Configured", else: "Missing")}
                  </span>
                </div>
              <% end %>
            </div>
          </article>
        </section>

        <section
          :if={@return_context}
          id="settings-return-context"
          class="rounded-xl border border-primary/30 bg-base-200 p-5"
        >
          <p class="kiln-eyebrow">Return path</p>
          <h2 class="kiln-h2 mt-2">Come back to the same template path after this fix</h2>
          <p class="kiln-body mt-2 text-sm text-base-content/70">
            The selected template stays the same. Verify the missing setup step here, then resume the first-run path without re-orienting.
          </p>
          <div class="mt-4 flex flex-wrap gap-3">
            <.link
              id="settings-return-to-template"
              navigate={@return_context.path}
              class="btn btn-sm btn-primary"
            >
              Return to {@return_context.template_id}
            </.link>
          </div>
        </section>

        <section id="settings-checklist" class="space-y-3">
          <%= for item <- @setup_summary.checklist do %>
            <article
              id={"settings-item-#{item.id}"}
              class="rounded-xl border border-base-300 bg-base-200 p-5"
            >
              <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div class="space-y-2">
                  <div class="flex flex-wrap items-center gap-2">
                    <h2 class="kiln-h2">{item.title}</h2>
                    <span class={[
                      "kiln-chip",
                      item.status == :ready && "kiln-chip--ok",
                      item.status == :action_needed && "kiln-chip--warn"
                    ]}>
                      {if(item.status == :ready, do: "Ready", else: "Needs action")}
                    </span>
                    <%= if @last_verified == item.id do %>
                      <span class="kiln-chip kiln-chip--demo">Checked just now</span>
                    <% end %>
                  </div>
                  <p class="kiln-body text-sm">{item.why}</p>
                  <dl class="grid gap-2 text-sm text-base-content/70 sm:grid-cols-2">
                    <div>
                      <dt class="kiln-eyebrow text-[11px]">Where used</dt>
                      <dd class="mt-1">{item.where_used}</dd>
                    </div>
                    <div>
                      <dt class="kiln-eyebrow text-[11px]">Next action</dt>
                      <dd class="mt-1">{item.next_action}</dd>
                    </div>
                    <div>
                      <dt class="kiln-eyebrow text-[11px]">Probe</dt>
                      <dd class="mt-1 kiln-mono" phx-no-curly-interpolation>{item.probe}</dd>
                    </div>
                    <div>
                      <dt class="kiln-eyebrow text-[11px]">Pages that will point here</dt>
                      <dd class="mt-1">Onboarding, templates, providers, and the run board.</dd>
                    </div>
                  </dl>
                </div>

                <div class="lg:pt-1">
                  <button
                    :if={verify_event(item.id)}
                    id={"settings-verify-#{item.id}"}
                    type="button"
                    phx-click={verify_event(item.id)}
                    class={[
                      "btn w-full lg:w-auto",
                      item.status == :ready && "btn-ghost border-base-300",
                      item.status == :action_needed && "btn-primary"
                    ]}
                  >
                    {if(item.status == :ready, do: "Re-verify", else: "Verify now")}
                  </button>
                </div>
              </div>
            </article>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp verify_event(:anthropic), do: "verify_anthropic"
  defp verify_event(:github), do: "verify_github"
  defp verify_event(:docker), do: "verify_docker"
  defp verify_event(_), do: nil

  defp return_context(%{"return_to" => return_to, "template_id" => template_id})
       when is_binary(return_to) and is_binary(template_id) do
    uri = URI.parse(return_to)

    if String.starts_with?(uri.path || "", "/templates/") do
      %{path: return_to, template_id: template_id}
    else
      nil
    end
  end

  defp return_context(_), do: nil

  defp journey_copy(%{id: "operator-triage-readiness"}),
    do: "This path should explain every missing setup dependency without guesswork."

  defp journey_copy(%{id: "gameboy-first-project"}),
    do:
      "This path should make it obvious when the machine is finally ready for the first real Game Boy run."

  defp journey_copy(_),
    do:
      "This path should make the jump from calm demo exploration into a believable live attempt feel safe."
end
