defmodule KilnWeb.OnboardingLive do
  @moduledoc """
  BLOCK-04 — `/onboarding` wizard for operator readiness (D-806).
  """

  use KilnWeb, :live_view

  alias Kiln.OperatorReadiness

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Set up Kiln")
     |> assign(:review_mode, false)
     |> assign(:readiness, OperatorReadiness.current_state())
     |> assign(:last_verified, nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    review_mode = params["review"] == "1"
    {:noreply, assign(socket, :review_mode, review_mode)}
  end

  @impl true
  def handle_event("verify_anthropic", _, socket) do
    v = OperatorReadiness.probe_anthropic_configured?()
    {:ok, _} = OperatorReadiness.mark_step(:anthropic, v)
    {:noreply, after_verify(socket, :anthropic, v, "Anthropic key reference missing")}
  end

  def handle_event("verify_github", _, socket) do
    v = OperatorReadiness.probe_github_cli?()
    {:ok, _} = OperatorReadiness.mark_step(:github, v)
    {:noreply, after_verify(socket, :github, v, "GitHub CLI not authenticated")}
  end

  def handle_event("verify_docker", _, socket) do
    v = OperatorReadiness.probe_docker?()
    {:ok, _} = OperatorReadiness.mark_step(:docker, v)
    {:noreply, after_verify(socket, :docker, v, "Docker not reachable")}
  end

  defp after_verify(socket, step, true, _fail_copy) do
    socket
    |> assign(:readiness, OperatorReadiness.current_state())
    |> assign(:last_verified, step)
    |> put_flash(:info, "Verified")
  end

  defp after_verify(socket, step, false, fail_copy) do
    socket
    |> assign(:readiness, OperatorReadiness.current_state())
    |> assign(:last_verified, step)
    |> put_flash(:error, fail_copy)
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
      chrome_mode={:minimal}
    >
      <div id="onboarding-wizard" class="mx-auto flex w-full max-w-2xl flex-col gap-8 py-2">
        <header class="flex flex-col gap-2">
          <p class="kiln-eyebrow">Set up Kiln</p>
          <h1 class="kiln-h1">Prepare the factory</h1>
          <p class="kiln-body">
            Verify three integrations before your first run. You can revisit this page any time.
          </p>
          <div class="mt-1 flex items-center gap-2">
            <span class="kiln-chip">
              <span class="kiln-chip__dot" aria-hidden="true" />
              <span class="kiln-status-numeric">
                <span class="kiln-status-numeric__label">Steps</span>
                <span class="tabular-nums">{@readiness.verified}/{@readiness.total}</span>
                <span class="kiln-status-numeric__label ml-1">verified</span>
              </span>
            </span>
            <%= if @review_mode do %>
              <span class="kiln-chip kiln-chip--demo">Review mode</span>
            <% end %>
          </div>
        </header>

        <%= if @review_mode do %>
          <section class="card card-bordered bg-base-200 border-base-300">
            <div class="card-body p-5 sm:p-6">
              <p class="kiln-body">
                Review mode — probes only; navigation stays open when ready.
              </p>
            </div>
          </section>
        <% end %>

        <section class="flex flex-col gap-3">
          <.step_card
            number={1}
            step_id="anthropic"
            verified={@readiness.anthropic}
            last={@last_verified}
            title="Anthropic"
            description="Confirm Kiln can reach your Anthropic key reference so planner and coder stages can call Claude."
            probe_label=":anthropic_api_key_ref"
            verify_id="verify-anthropic-btn"
            verify_event="verify_anthropic"
          />

          <.step_card
            number={2}
            step_id="github"
            verified={@readiness.github}
            last={@last_verified}
            title="GitHub CLI"
            description="Kiln uses the GitHub CLI to open PRs, read issues, and verify auth. Runs read-only."
            probe_label="gh auth status"
            verify_id="verify-github-btn"
            verify_event="verify_github"
          />

          <.step_card
            number={3}
            step_id="docker"
            verified={@readiness.docker}
            last={@last_verified}
            title="Docker"
            description="Sandboxes run in ephemeral containers. Kiln must be able to talk to the local Docker engine."
            probe_label="docker info"
            verify_id="verify-docker-btn"
            verify_event="verify_docker"
          />
        </section>

        <section class="flex flex-col items-start gap-3 pt-1 sm:flex-row sm:items-center sm:justify-between">
          <.link
            id="onboarding-start-from-template"
            navigate={~p"/templates?from=onboarding"}
            class="btn btn-primary w-full sm:w-auto"
          >
            Start from a template
          </.link>
          <.link navigate={~p"/"} class="link link-primary text-sm">
            Continue to runs
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :number, :integer, required: true
  attr :step_id, :string, required: true
  attr :verified, :boolean, required: true
  attr :last, :atom, default: nil
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :probe_label, :string, required: true
  attr :verify_id, :string, required: true
  attr :verify_event, :string, required: true

  defp step_card(assigns) do
    state =
      cond do
        assigns.verified -> "done"
        to_string(assigns.last) == assigns.step_id -> "fail"
        true -> "pending"
      end

    assigns = assign(assigns, :state, state)

    ~H"""
    <article
      id={"step-" <> @step_id}
      class="card card-bordered bg-base-200 border-base-300 kiln-step-rail"
      data-state={@state}
    >
      <div class="card-body p-5 sm:p-6">
        <div class="grid grid-cols-[auto_1fr] items-start gap-x-4 gap-y-3 sm:grid-cols-[auto_1fr_auto]">
          <div class="row-span-2 sm:row-span-1">
            <span class="kiln-step" data-state={@state} aria-hidden="true">
              <%= if @state == "done" do %>
                <.icon name="hero-check" class="size-4" />
              <% else %>
                {@number}
              <% end %>
            </span>
          </div>

          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="kiln-h2">{@title}</h2>
              <%= cond do %>
                <% @state == "done" -> %>
                  <span class="kiln-chip kiln-chip--ok">Verified</span>
                <% @state == "fail" -> %>
                  <span class="kiln-chip kiln-chip--fail">Not reachable</span>
                <% true -> %>
                  <span class="kiln-chip">Not yet verified</span>
              <% end %>
            </div>
            <p class="kiln-body mt-1">{@description}</p>
            <p class="kiln-meta mt-2">
              Probe: <span class="kiln-mono" phx-no-curly-interpolation>{@probe_label}</span>
            </p>
          </div>

          <div class="col-span-2 sm:col-span-1 sm:ml-3 sm:self-center">
            <button
              type="button"
              id={@verify_id}
              phx-click={@verify_event}
              class={[
                "btn w-full sm:w-auto",
                @state == "done" && "btn-ghost border-base-300",
                @state != "done" && "btn-primary"
              ]}
            >
              <%= if @state == "done" do %>
                Re-verify
              <% else %>
                Verify
              <% end %>
            </button>
          </div>
        </div>
      </div>
    </article>
    """
  end
end
