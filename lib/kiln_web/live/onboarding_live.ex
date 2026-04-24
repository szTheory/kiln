defmodule KilnWeb.OnboardingLive do
  @moduledoc """
  Demo-first `/onboarding` flow for the solo operator.
  """

  use KilnWeb, :live_view

  alias Kiln.DemoScenarios
  alias Kiln.OperatorReadiness
  alias Kiln.OperatorSetup

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Set up Kiln")
     |> assign(:setup_summary, OperatorSetup.summary())
     |> assign(:last_verified, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scenario = resolve_scenario(params["scenario"], socket.assigns.operator_demo_scenario)

    {:noreply, assign(socket, :operator_demo_scenario, scenario)}
  end

  @impl true
  def handle_event("select_scenario", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/onboarding?scenario=#{id}")}
  end

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
      chrome_mode={:minimal}
    >
      <div id="onboarding-wizard" class="mx-auto flex w-full max-w-5xl flex-col gap-8 py-2">
        <header class="flex flex-col gap-2">
          <p class="kiln-eyebrow">Set up Kiln</p>
          <h1 class="kiln-h1">Start in demo mode, then graduate to live</h1>
          <p class="kiln-body max-w-3xl">
            The first-use story is intentionally low-risk: explore a believable scenario, learn the flow, then switch to live mode once you are ready to wire real credentials and local tooling.
          </p>
        </header>

        <section
          id="onboarding-next-path"
          class="grid gap-3 rounded-xl border border-base-300 bg-base-200 p-5 sm:grid-cols-3"
        >
          <article class="space-y-1">
            <p class="kiln-eyebrow">1. Pick a scenario</p>
            <p class="kiln-body text-sm">
              Start with the persona and job-to-be-done that best matches what you are trying to learn today.
            </p>
          </article>
          <article class="space-y-1">
            <p class="kiln-eyebrow">2. Open the recommended template</p>
            <p class="kiln-body text-sm">
              Each demo scenario points to the smallest believable template for that story.
            </p>
          </article>
          <article class="space-y-1">
            <p class="kiln-eyebrow">3. Switch to live when ready</p>
            <p class="kiln-body text-sm">
              When you want a real run, live mode surfaces exactly what still needs configuration.
            </p>
          </article>
        </section>

        <%= if @operator_runtime_mode == :live and not @setup_summary.ready? do %>
          <section
            id="onboarding-live-hero"
            class="rounded-xl border border-warning/60 bg-warning/10 p-5"
          >
            <p class="kiln-eyebrow">Live mode is active</p>
            <h2 class="kiln-h2 mt-2">A few local dependencies still need attention</h2>
            <p class="kiln-body mt-2 text-sm">
              Kiln stays explorable, but pages that depend on live execution will show disconnected states until you resolve the missing setup items.
            </p>
            <div class="mt-4 flex flex-wrap gap-3 text-sm">
              <.link navigate={~p"/settings"} class="btn btn-primary btn-sm">
                Open settings checklist
              </.link>
              <.link navigate={~p"/providers"} class="link link-primary">
                Open provider health
              </.link>
            </div>
          </section>
        <% else %>
          <section
            id="onboarding-demo-hero"
            class="rounded-xl border border-base-300 bg-base-200 p-5"
          >
            <p class="kiln-eyebrow">Demo mode default</p>
            <h2 class="kiln-h2 mt-2">Explore without paying for providers first</h2>
            <p class="kiln-body mt-2 text-sm">
              Demo mode uses seeded stories, fixtures, and mock outcomes so you can learn the app’s shape before you commit real keys or run your first external project.
            </p>
          </section>
        <% end %>

        <section id="onboarding-scenarios" class="space-y-4">
          <div class="flex items-center justify-between gap-3">
            <div>
              <p class="kiln-eyebrow">Demo scenarios</p>
              <h2 class="kiln-h2 mt-1">Choose the first-use story you want</h2>
            </div>
            <.link navigate={~p"/settings"} class="link link-primary text-sm">
              See full live checklist
            </.link>
          </div>

          <div class="grid gap-4 lg:grid-cols-3">
            <%= for scenario <- @operator_demo_scenarios do %>
              <button
                id={"scenario-card-#{scenario.id}"}
                type="button"
                phx-click="select_scenario"
                phx-value-id={scenario.id}
                class={[
                  "rounded-xl border p-5 text-left transition",
                  @operator_demo_scenario.id == scenario.id &&
                    "border-primary bg-base-200 shadow-[0_0_0_1px_var(--color-primary)]",
                  @operator_demo_scenario.id != scenario.id &&
                    "border-base-300 bg-base-200 hover:border-primary/50"
                ]}
              >
                <p class="kiln-eyebrow">{scenario.title}</p>
                <p class="mt-2 text-sm font-semibold">{scenario.persona}</p>
                <p class="mt-2 text-sm text-base-content/70">{scenario.jtbd}</p>
                <%= if @operator_demo_scenario.id == scenario.id do %>
                  <span class="kiln-chip kiln-chip--demo mt-4">Selected</span>
                <% end %>
              </button>
            <% end %>
          </div>
        </section>

        <section id="onboarding-scenario-detail" class="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
          <article class="rounded-xl border border-base-300 bg-base-200 p-5">
            <p class="kiln-eyebrow">Selected scenario</p>
            <h2 class="kiln-h2 mt-2">{@operator_demo_scenario.title}</h2>
            <p class="kiln-body mt-3 text-sm">{@operator_demo_scenario.narrative}</p>

            <dl class="mt-4 grid gap-4 text-sm sm:grid-cols-2">
              <div>
                <dt class="kiln-eyebrow text-[11px]">Seeded context</dt>
                <dd class="mt-1 text-base-content/70">{@operator_demo_scenario.seeded_context}</dd>
              </div>
              <div>
                <dt class="kiln-eyebrow text-[11px]">Expected outcome</dt>
                <dd class="mt-1 text-base-content/70">{@operator_demo_scenario.expected_outcome}</dd>
              </div>
            </dl>
          </article>

          <article class="rounded-xl border border-base-300 bg-base-200 p-5">
            <p class="kiln-eyebrow">Recommended next step</p>
            <h2 class="kiln-h2 mt-2">Open the matching template</h2>
            <p class="kiln-body mt-2 text-sm">
              This scenario points to a vetted starting surface instead of asking you to invent a blank first run.
            </p>
            <div class="mt-4 flex flex-col gap-3">
              <.link
                id="onboarding-start-from-template"
                navigate={~p"/templates?from=onboarding&scenario=#{@operator_demo_scenario.id}"}
                class="btn btn-primary"
              >
                Open recommended template
              </.link>
              <.link id="onboarding-continue-runs" navigate={~p"/"} class="link link-primary">
                Open run board
              </.link>
              <.link navigate={~p"/providers"} class="link link-primary">
                Check provider health
              </.link>
            </div>
          </article>
        </section>

        <section id="onboarding-live-checks" class="space-y-3">
          <div>
            <p class="kiln-eyebrow">Live readiness quick checks</p>
            <h2 class="kiln-h2 mt-1">When you switch to live mode, these are the essentials</h2>
          </div>

          <%= for item <- @setup_summary.checklist do %>
            <article
              id={"step-" <> Atom.to_string(item.id)}
              class="rounded-xl border border-base-300 bg-base-200 p-5"
            >
              <div class="grid gap-3 lg:grid-cols-[1fr_auto] lg:items-start">
                <div>
                  <div class="flex flex-wrap items-center gap-2">
                    <h3 class="kiln-h2">{item.title}</h3>
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
                  <p class="kiln-body mt-2 text-sm">{item.why}</p>
                  <p class="kiln-meta mt-2">
                    Probe: <span class="kiln-mono" phx-no-curly-interpolation>{item.probe}</span>
                  </p>
                  <p class="kiln-meta mt-1">
                    Next action: {item.next_action}
                  </p>
                </div>
                <div class="flex flex-wrap gap-3 lg:justify-end">
                  <button
                    type="button"
                    id={"verify-" <> Atom.to_string(item.id) <> "-btn"}
                    phx-click={verify_event(item.id)}
                    class={[
                      "btn btn-sm",
                      item.status == :ready && "btn-ghost border-base-300",
                      item.status == :action_needed && "btn-primary"
                    ]}
                  >
                    {if(item.status == :ready, do: "Re-verify", else: "Verify")}
                  </button>
                  <.link
                    navigate={~p"/settings"}
                    class="btn btn-sm border border-base-300 bg-base-100"
                  >
                    Open settings
                  </.link>
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

  defp resolve_scenario(nil, fallback), do: fallback || DemoScenarios.default()
  defp resolve_scenario("", fallback), do: fallback || DemoScenarios.default()

  defp resolve_scenario(id, fallback) do
    case DemoScenarios.fetch(id) do
      {:ok, scenario} -> scenario
      {:error, :unknown_scenario} -> fallback || DemoScenarios.default()
    end
  end
end
