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
     |> assign(:review_mode, false)}
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
    {:noreply, put_flash(socket, :info, if(v, do: "Verified", else: "Anthropic key ref missing"))}
  end

  def handle_event("verify_github", _, socket) do
    v = OperatorReadiness.probe_github_cli?()
    {:ok, _} = OperatorReadiness.mark_step(:github, v)

    {:noreply,
     put_flash(socket, :info, if(v, do: "Verified", else: "GitHub CLI not authenticated"))}
  end

  def handle_event("verify_docker", _, socket) do
    v = OperatorReadiness.probe_docker?()
    {:ok, _} = OperatorReadiness.mark_step(:docker, v)
    {:noreply, put_flash(socket, :info, if(v, do: "Verified", else: "Docker not reachable"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} factory_summary={@factory_summary}>
      <div id="onboarding-wizard" class="mx-auto max-w-xl space-y-6 text-bone">
        <h1 class="text-2xl font-semibold">Set up Kiln</h1>
        <%= if @review_mode do %>
          <p class="text-sm text-[var(--color-smoke)]">
            Review mode — probes only; navigation stays open when ready.
          </p>
        <% end %>

        <section class="space-y-3 rounded border border-ash bg-char/80 p-4">
          <h2 class="text-sm font-semibold text-[var(--color-smoke)]">Anthropic</h2>
          <p class="text-sm text-[var(--color-smoke)]">
            Ensure <span class="font-mono">:anthropic_api_key_ref</span>
            is configured (secret ref only).
          </p>
          <button
            type="button"
            id="verify-anthropic-btn"
            phx-click="verify_anthropic"
            class="rounded border border-ash px-3 py-1 text-sm text-bone hover:border-ember"
          >
            Verify
          </button>
        </section>

        <section class="space-y-3 rounded border border-ash bg-char/80 p-4">
          <h2 class="text-sm font-semibold text-[var(--color-smoke)]">GitHub CLI</h2>
          <p class="text-sm text-[var(--color-smoke)]">
            Uses <span class="font-mono">gh auth status</span> read-only.
          </p>
          <button
            type="button"
            id="verify-github-btn"
            phx-click="verify_github"
            class="rounded border border-ash px-3 py-1 text-sm text-bone hover:border-ember"
          >
            Verify
          </button>
        </section>

        <section class="space-y-3 rounded border border-ash bg-char/80 p-4">
          <h2 class="text-sm font-semibold text-[var(--color-smoke)]">Docker</h2>
          <p class="text-sm text-[var(--color-smoke)]">
            Uses <span class="font-mono">docker info</span> read-only.
          </p>
          <button
            type="button"
            id="verify-docker-btn"
            phx-click="verify_docker"
            class="rounded border border-ash px-3 py-1 text-sm text-bone hover:border-ember"
          >
            Verify
          </button>
        </section>

        <.link navigate={~p"/"} class="text-sm text-ember underline">Continue to runs</.link>
      </div>
    </Layouts.app>
    """
  end
end
