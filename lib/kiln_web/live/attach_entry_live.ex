defmodule KilnWeb.AttachEntryLive do
  @moduledoc """
  Phase 29 attach orientation surface at `/attach`.
  """

  use KilnWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Attach existing repo")}
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
      <div id="attach-entry-root" class="mx-auto max-w-5xl space-y-8 text-base-content">
        <header id="attach-entry-hero" class="rounded-2xl border border-primary/30 bg-base-200 p-6">
          <p class="kiln-eyebrow">Attach existing repo</p>
          <h1 class="kiln-h1 mt-2">{@page_title}</h1>
          <p class="kiln-body mt-3 max-w-3xl text-sm">
            Built-in templates are the fastest way to learn Kiln or prove the first run. Attach existing repo is the real-project path for bounded work on one codebase you already own.
          </p>
          <p class="kiln-meta mt-3 max-w-3xl">
            Supports a local path, an existing clone, or a GitHub URL. Validation and workspace safety checks happen in the next step.
          </p>
          <div class="mt-4 flex flex-wrap gap-3 text-sm">
            <.link navigate={~p"/templates"} class="btn btn-primary btn-sm">
              Back to templates
            </.link>
            <.link navigate={~p"/onboarding"} class="link link-primary">
              Return to setup
            </.link>
          </div>
        </header>

        <section
          id="attach-supported-sources"
          class="grid gap-4 rounded-xl border border-base-300 bg-base-200 p-5 md:grid-cols-3"
        >
          <article class="rounded-lg border border-base-300 bg-base-100/50 p-4">
            <p class="kiln-eyebrow">Local path</p>
            <p class="mt-2 text-sm text-base-content/70">
              Point Kiln at a repo that already exists on this host when you want to keep control of where the working copy lives.
            </p>
          </article>
          <article class="rounded-lg border border-base-300 bg-base-100/50 p-4">
            <p class="kiln-eyebrow">Existing clone</p>
            <p class="mt-2 text-sm text-base-content/70">
              Reuse an operator-managed clone when the repo is already checked out and ready for conservative brownfield handling.
            </p>
          </article>
          <article class="rounded-lg border border-base-300 bg-base-100/50 p-4">
            <p class="kiln-eyebrow">GitHub URL</p>
            <p class="mt-2 text-sm text-base-content/70">
              Start from a GitHub URL when the next step should resolve and prepare one repo before any work begins.
            </p>
          </article>
        </section>

        <section class="grid gap-4 lg:grid-cols-[1fr_1fr]">
          <article class="rounded-xl border border-base-300 bg-base-200 p-5">
            <p class="kiln-eyebrow">What attach means</p>
            <h2 class="kiln-h2 mt-2">Keep the boundary explicit</h2>
            <p class="kiln-body mt-2 text-sm">
              Attach is for one repo only. It is the real-project path for bounded branch-oriented work on operator-owned code, not a hidden variation of templates or demo scenarios.
            </p>
            <p class="kiln-meta mt-3">
              Attach does not replace the demo/template journey and does not imply that repo validation has already happened.
            </p>
          </article>

          <article id="attach-next-step" class="rounded-xl border border-base-300 bg-base-200 p-5">
            <p class="kiln-eyebrow">What happens next</p>
            <h2 class="kiln-h2 mt-2">Phase 30 adds repo validation and workspace safety</h2>
            <p class="kiln-body mt-2 text-sm">
              Validation and workspace safety checks happen in the next step. That includes resolving the source, confirming the repo is attachable, and preparing the conservative workspace flow before Kiln acts on your code.
            </p>
            <p class="kiln-meta mt-3">
              Phase 29 does not probe the repo, hydrate a workspace, check dirty worktrees, or mutate git state.
            </p>
          </article>
        </section>

        <section class="rounded-xl border border-base-300 bg-base-200 p-5">
          <p class="kiln-eyebrow">Start paths</p>
          <h2 class="kiln-h2 mt-2">Choose the entry that matches the job</h2>
          <div class="mt-4 grid gap-4 md:grid-cols-2">
            <article class="rounded-lg border border-base-300 bg-base-100/50 p-4">
              <p class="kiln-eyebrow">Built-in templates</p>
              <p class="mt-2 text-sm text-base-content/70">
                Fastest way to learn Kiln or prove the first run with the recommended `hello-kiln` path.
              </p>
            </article>
            <article class="rounded-lg border border-base-300 bg-base-100/50 p-4">
              <p class="kiln-eyebrow">Attach existing repo</p>
              <p class="mt-2 text-sm text-base-content/70">
                Use attach when you already have code and want Kiln to enter through a separate brownfield route.
              </p>
            </article>
          </div>
          <div class="mt-4 flex flex-wrap gap-3 text-sm">
            <.link
              id="attach-back-to-templates"
              navigate={~p"/templates"}
              class="link link-primary"
            >
              Back to templates
            </.link>
            <.link navigate={~p"/onboarding"} class="link link-primary">
              Return to setup
            </.link>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
