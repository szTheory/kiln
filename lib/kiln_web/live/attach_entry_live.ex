defmodule KilnWeb.AttachEntryLive do
  @moduledoc """
  Attach source intake surface at `/attach`.
  """

  use KilnWeb, :live_view

  alias Kiln.Attach
  alias Kiln.Attach.BrownfieldPreflight
  alias Kiln.Attach.IntakeRequest
  alias Kiln.OperatorSetup
  alias Kiln.Runs
  alias Kiln.Specs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Attach existing repo")
     |> assign(:resolution_state, :untouched)
     |> assign(:attach_ready, nil)
     |> assign(:attached_repo, nil)
     |> assign(:attach_blocked, nil)
     |> assign(:resolved_source, nil)
     |> assign(:source_error, nil)
     |> assign(:recent_attached_repos, [])
     |> assign(:continuity, nil)
     |> assign(:continuity_blank?, false)
     |> assign(:brownfield_report, nil)
     |> assign(:brownfield_original_request, nil)
     |> assign(:brownfield_inspected_code, nil)
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)
     |> assign(:form, to_form(%{"source" => ""}, as: :attach_source))
     |> assign(:request_form, request_form(%{}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_continuity(socket, params)}
  end

  @impl true
  def handle_event("validate_source", %{"attach_source" => params}, socket) do
    source = Map.get(params, "source", "")

    {:noreply,
     if String.trim(source) == "" do
       reset_resolution(socket, params)
     else
       assign_resolution(socket, params, Attach.validate_source(source))
     end}
  end

  @impl true
  def handle_event("resolve_source", %{"attach_source" => params}, socket) do
    source = Map.get(params, "source", "")

    {:noreply, submit_attach(socket, params, source)}
  end

  @impl true
  def handle_event("validate_request", %{"attach_request" => params}, socket) do
    {:noreply,
     socket
     |> assign(:request_form, request_form(params, action: :validate))
     |> assign(:request_error, nil)}
  end

  @impl true
  def handle_event("submit_request", %{"attach_request" => params}, socket) do
    {:noreply, submit_request(socket, params)}
  end

  @impl true
  def handle_event("start_blank", _params, %{assigns: %{continuity: nil}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_blank", _params, socket) do
    {:noreply,
     socket
     |> assign(:continuity_blank?, true)
     |> assign(:request_form, request_form(%{}))
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)}
  end

  @impl true
  def handle_event("restore_carry_forward", _params, %{assigns: %{continuity: nil}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_carry_forward", _params, socket) do
    {:noreply,
     socket
     |> assign(:continuity_blank?, false)
     |> assign(:request_form, continuity_request_form(socket.assigns.continuity, false))
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)}
  end

  @impl true
  def handle_event("accept_narrowing", _params, %{assigns: %{brownfield_report: nil}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("accept_narrowing", _params, socket) do
    {:noreply,
     socket
     |> assign(
       :request_form,
       socket.assigns.brownfield_report.suggested_request
       |> request_params_from_brownfield_request()
       |> request_form()
     )
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)}
  end

  @impl true
  def handle_event(
        "edit_warning_request",
        _params,
        %{assigns: %{brownfield_original_request: nil}} = socket
      ) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_warning_request", _params, socket) do
    {:noreply,
     socket
     |> assign(:request_form, request_form(socket.assigns.brownfield_original_request))
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)}
  end

  @impl true
  def handle_event("inspect_warning_finding", %{"code" => code}, socket) do
    {:noreply, assign(socket, :brownfield_inspected_code, code)}
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
            Supports a local path, an existing clone, or a GitHub URL. Resolve the source here, then hand the next plan one canonical repo identity for writable workspace prep.
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

        <section
          :if={@recent_attached_repos != []}
          id="attach-recent-repos"
          class="rounded-2xl border border-base-300 bg-base-200 p-5"
        >
          <div class="flex items-end justify-between gap-4">
            <div>
              <p class="kiln-eyebrow">Recent attached repos</p>
              <h2 class="kiln-h2 mt-2">Return to known brownfield context</h2>
              <p class="kiln-body mt-2 text-sm">
                Pick a repo Kiln already knows to load continuity context without retyping the source.
              </p>
            </div>
          </div>

          <div class="mt-4 grid gap-3 md:grid-cols-2">
            <%= for repo <- @recent_attached_repos do %>
              <.link
                id={"attach-recent-repo-#{repo.id}"}
                patch={recent_repo_patch(repo.id)}
                class={[
                  "rounded-xl border p-4 transition-colors",
                  if(@continuity && @continuity.attached_repo.id == repo.id,
                    do: "border-primary bg-primary/5",
                    else: "border-base-300 bg-base-100/70 hover:border-primary/40"
                  )
                ]}
              >
                <p class="text-sm font-semibold text-base-content">{repo.repo_slug}</p>
                <p class="mt-1 text-sm text-base-content/70">{repo.workspace_path}</p>
                <p class="mt-2 text-xs uppercase tracking-[0.18em] text-base-content/50">
                  Last activity
                </p>
                <p class="mt-1 text-sm text-base-content/80">
                  {format_timestamp(repo.last_activity_at)}
                </p>
              </.link>
            <% end %>
          </div>
        </section>

        <section
          id="attach-source-panel"
          class="grid gap-4 rounded-2xl border border-base-300 bg-base-200 p-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(18rem,0.8fr)]"
        >
          <div class="space-y-4">
            <div>
              <p class="kiln-eyebrow">Resolve source</p>
              <h2 class="kiln-h2 mt-2">Confirm the repo entry before workspace hydration</h2>
              <p class="kiln-body mt-2 text-sm">
                Submit one source and Kiln will normalize it into the repo identity that later attach plans can reuse. No clone, branch creation, or workspace mutation happens here.
              </p>
            </div>

            <.form
              for={@form}
              id="attach-source-form"
              class="space-y-4"
              phx-change="validate_source"
              phx-submit="resolve_source"
            >
              <.input
                field={@form[:source]}
                id="attach-source-input"
                type="text"
                label="Repo source"
                placeholder="/Users/operator/project or https://github.com/owner/repo"
              />

              <div class="flex flex-wrap items-center gap-3">
                <button
                  id="attach-source-submit"
                  type="submit"
                  class="btn btn-primary transition-transform duration-150 hover:-translate-y-0.5"
                >
                  Resolve source
                </button>
                <p class="kiln-meta">
                  Supports a local path, an existing clone, or a GitHub URL.
                </p>
              </div>
            </.form>
          </div>

          <div class="rounded-xl border border-base-300 bg-base-100/70 p-4">
            <%= case @resolution_state do %>
              <% :untouched -> %>
                <div id="attach-source-untouched" class="space-y-3">
                  <p class="kiln-eyebrow">Current state</p>
                  <h3 class="text-base font-semibold text-base-content">
                    Waiting for one repo source
                  </h3>
                  <p class="text-sm text-base-content/70">
                    Enter a local path, an existing clone, or a GitHub URL to verify that Kiln can identify one repo cleanly before any workspace step starts.
                  </p>
                </div>
              <% :resolved -> %>
                <div id="attach-source-resolved" class="space-y-3">
                  <p class="kiln-eyebrow">Current state</p>
                  <h3 class="text-base font-semibold text-base-content">
                    Source ready for workspace hydration
                  </h3>
                  <dl class="space-y-2 text-sm text-base-content/80">
                    <div>
                      <dt class="font-medium text-base-content">Source kind</dt>
                      <dd>{source_kind_label(@resolved_source.kind)}</dd>
                    </div>
                    <div>
                      <dt class="font-medium text-base-content">Repo identity</dt>
                      <dd>{@resolved_source.repo_identity.slug}</dd>
                    </div>
                    <div>
                      <dt class="font-medium text-base-content">Submitted source</dt>
                      <dd class="break-all">{@resolved_source.input}</dd>
                    </div>
                    <%= if @resolved_source.canonical_root do %>
                      <div>
                        <dt class="font-medium text-base-content">Canonical root</dt>
                        <dd class="break-all">{@resolved_source.canonical_root}</dd>
                      </div>
                    <% end %>
                    <%= if @resolved_source.remote_metadata.url do %>
                      <div>
                        <dt class="font-medium text-base-content">Canonical remote</dt>
                        <dd class="break-all">{@resolved_source.remote_metadata.url}</dd>
                      </div>
                    <% end %>
                  </dl>
                  <p class="kiln-meta">
                    Next plan: prepare the writable workspace and apply safety gates. This step only resolves identity.
                  </p>
                </div>
              <% :ready -> %>
                <div id="attach-ready" class="space-y-4">
                  <div id="attach-ready-summary" class="space-y-3">
                    <p class="kiln-eyebrow text-success">Ready state</p>
                    <h3 class="text-base font-semibold text-base-content">
                      Attach ready for the next branch and draft PR phase
                    </h3>
                    <p class="text-sm text-base-content/70">
                      Workspace hydration succeeded and the conservative safety preflight passed. Kiln can hand this repo forward without pretending a blocked repo is ready.
                    </p>
                  </div>

                  <dl class="space-y-2 text-sm text-base-content/80">
                    <div>
                      <dt class="font-medium text-base-content">Repo target</dt>
                      <dd>{@attach_ready.repo_slug}</dd>
                    </div>
                    <div>
                      <dt class="font-medium text-base-content">Workspace path</dt>
                      <dd class="break-all">{@attach_ready.workspace_path}</dd>
                    </div>
                    <div>
                      <dt class="font-medium text-base-content">Base branch</dt>
                      <dd>{@attach_ready.base_branch}</dd>
                    </div>
                    <div>
                      <dt class="font-medium text-base-content">Remote</dt>
                      <dd class="break-all">{@attach_ready.remote_url}</dd>
                    </div>
                  </dl>

                  <%= if @request_started_run do %>
                    <div
                      id="attach-run-started"
                      class="space-y-3 rounded-xl border border-success/30 bg-success/10 p-4"
                    >
                      <p class="kiln-eyebrow text-success">Run started</p>
                      <h4 class="text-base font-semibold text-base-content">
                        Kiln started one bounded attached-repo run.
                      </h4>
                      <p class="text-sm text-base-content/80">
                        Run id: <span class="font-mono">{@request_started_run.id}</span>
                      </p>
                    </div>
                  <% else %>
                    <.attach_request_panel
                      form={@request_form}
                      request_error={@request_error}
                      continuity={nil}
                      continuity_blank?={false}
                    />
                  <% end %>
                </div>
              <% :continuity -> %>
                <div id="attach-continuity" class="space-y-4">
                  <div
                    id="attach-continuity-card"
                    class="space-y-4 rounded-xl border border-base-300 bg-base-100/80 p-4"
                  >
                    <div class="space-y-2">
                      <p class="kiln-eyebrow text-primary">Continuity</p>
                      <h3 class="text-base font-semibold text-base-content">
                        Return to one known attached repo
                      </h3>
                      <p class="text-sm text-base-content/70">
                        Kiln already knows this repo. It will still rerun hydration, safety, and operator checks before starting the next run.
                      </p>
                    </div>

                    <dl class="space-y-2 text-sm text-base-content/80">
                      <div>
                        <dt class="font-medium text-base-content">Repo target</dt>
                        <dd>{@continuity.attached_repo.repo_slug}</dd>
                      </div>
                      <div>
                        <dt class="font-medium text-base-content">Workspace path</dt>
                        <dd class="break-all">{@continuity.attached_repo.workspace_path}</dd>
                      </div>
                      <div>
                        <dt class="font-medium text-base-content">Base branch</dt>
                        <dd>{@continuity.attached_repo.base_branch}</dd>
                      </div>
                      <%= if @continuity.last_run do %>
                        <div>
                          <dt class="font-medium text-base-content">Last run</dt>
                          <dd>
                            <span class="font-mono">{@continuity.last_run.id}</span>
                            <span class="ml-2 capitalize">{@continuity.last_run.state}</span>
                          </dd>
                        </div>
                      <% end %>
                      <%= if @continuity.last_request do %>
                        <div>
                          <dt class="font-medium text-base-content">Last bounded request</dt>
                          <dd>
                            {@continuity.last_request.title}
                            <span class="ml-2 capitalize text-base-content/60">
                              {@continuity.last_request.request_kind}
                            </span>
                          </dd>
                        </div>
                      <% end %>
                    </dl>

                    <div
                      id="attach-continuity-carried-forward"
                      class="rounded-lg border border-primary/20 bg-primary/5 p-3"
                    >
                      <p class="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                        Carried forward
                      </p>
                      <%= if @continuity_blank? or @continuity.carry_forward.source == :blank do %>
                        <p class="mt-2 text-sm text-base-content/70">
                          Start blank for this repo. Kiln keeps the repo continuity context but clears request prefill.
                        </p>
                      <% else %>
                        <p class="mt-2 text-sm text-base-content/80">
                          {carry_forward_label(@continuity.carry_forward)}:
                          <span class="font-medium text-base-content">
                            {@continuity.carry_forward.title}
                          </span>
                        </p>
                        <p class="mt-1 text-sm text-base-content/70">
                          {@continuity.carry_forward.change_summary}
                        </p>
                      <% end %>
                    </div>

                    <div class="flex flex-wrap gap-3">
                      <button
                        :if={!@continuity_blank? and @continuity.carry_forward.source != :blank}
                        id="attach-start-blank"
                        type="button"
                        phx-click="start_blank"
                        class="btn btn-secondary btn-sm"
                      >
                        Start blank
                      </button>
                      <button
                        :if={@continuity_blank? and @continuity.carry_forward.source != :blank}
                        id="attach-continue-carried-forward"
                        type="button"
                        phx-click="restore_carry_forward"
                        class="btn btn-secondary btn-sm"
                      >
                        Continue with carried-forward request
                      </button>
                      <p
                        :if={@continuity.selected_target}
                        id="attach-inspect-prior"
                        class="kiln-meta self-center"
                      >
                        Inspect prior request: {@continuity.selected_target.title}
                      </p>
                    </div>
                  </div>

                  <%= if @request_started_run do %>
                    <div
                      id="attach-run-started"
                      class="space-y-3 rounded-xl border border-success/30 bg-success/10 p-4"
                    >
                      <p class="kiln-eyebrow text-success">Run started</p>
                      <h4 class="text-base font-semibold text-base-content">
                        Kiln started one bounded attached-repo run.
                      </h4>
                      <p class="text-sm text-base-content/80">
                        Run id: <span class="font-mono">{@request_started_run.id}</span>
                      </p>
                    </div>
                  <% else %>
                    <.attach_request_panel
                      form={@request_form}
                      request_error={@request_error}
                      continuity={@continuity}
                      continuity_blank?={@continuity_blank?}
                    />
                  <% end %>
                </div>
              <% :warning -> %>
                <div id="attach-warning" class="space-y-4">
                  <div class="space-y-3 rounded-xl border border-warning/30 bg-warning/10 p-4">
                    <p class="kiln-eyebrow text-warning">Brownfield warning</p>
                    <h3 class="text-base font-semibold text-base-content">
                      This repo is attachable, but the request should be narrowed first.
                    </h3>
                    <p class="text-sm text-base-content/80">
                      Kiln found collision-prone or broad brownfield signals for {@brownfield_report.repo_slug} on {@brownfield_report.base_branch}. Continue only after narrowing the request.
                    </p>
                  </div>

                  <div id="attach-warning-findings" class="space-y-3">
                    <%= for finding <- BrownfieldPreflight.warning_findings(@brownfield_report) do %>
                      <article
                        id={"attach-warning-finding-#{finding.code}"}
                        class="rounded-xl border border-base-300 bg-base-100/80 p-4"
                      >
                        <div class="flex items-start justify-between gap-3">
                          <div class="space-y-2">
                            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-warning">
                              {finding.code}
                            </p>
                            <h4 class="text-base font-semibold text-base-content">{finding.title}</h4>
                            <p class="text-sm text-base-content/80">{finding.why}</p>
                            <p class="text-sm text-base-content/70">{finding.next_action}</p>
                          </div>
                          <button
                            id={"attach-warning-inspect-#{finding.code}"}
                            type="button"
                            phx-click="inspect_warning_finding"
                            phx-value-code={finding_code(finding)}
                            class="btn btn-secondary btn-sm"
                          >
                            Inspect
                          </button>
                        </div>
                      </article>
                    <% end %>
                  </div>

                  <%= if inspected_finding = inspected_warning_finding(@brownfield_report, @brownfield_inspected_code) do %>
                    <div
                      id="attach-warning-inspect-panel"
                      class="rounded-xl border border-primary/20 bg-primary/5 p-4"
                    >
                      <p class="kiln-eyebrow text-primary">Inspect prior object</p>
                      <h4 class="mt-2 text-base font-semibold text-base-content">
                        {inspected_finding.title}
                      </h4>
                      <dl class="mt-3 grid gap-2 text-sm text-base-content/80">
                        <%= for {label, value} <- warning_evidence_rows(inspected_finding.evidence) do %>
                          <div>
                            <dt class="font-medium text-base-content">{label}</dt>
                            <dd>{value}</dd>
                          </div>
                        <% end %>
                      </dl>
                    </div>
                  <% end %>

                  <div class="flex flex-wrap gap-3">
                    <button
                      id="attach-narrowing-accept"
                      type="button"
                      phx-click="accept_narrowing"
                      class="btn btn-primary"
                    >
                      Accept Kiln's narrower default
                    </button>
                    <button
                      id="attach-warning-edit"
                      type="button"
                      phx-click="edit_warning_request"
                      class="btn btn-secondary"
                    >
                      Edit manually
                    </button>
                  </div>

                  <.attach_request_panel
                    form={@request_form}
                    request_error={@request_error}
                    continuity={nil}
                    continuity_blank?={false}
                  />
                </div>
              <% :blocked -> %>
                <div id="attach-blocked" class="space-y-4">
                  <div class="space-y-3">
                    <p class="kiln-eyebrow text-warning">Blocked state</p>
                    <h3 class="text-base font-semibold text-base-content">
                      {@attach_blocked.title}
                    </h3>
                    <p class="text-sm text-base-content/70">
                      {@attach_blocked.message}
                    </p>
                    <p class="kiln-meta">
                      {@attach_blocked.why}
                    </p>
                  </div>

                  <div
                    id="attach-remediation-summary"
                    class="space-y-3 rounded-lg border border-warning/30 bg-warning/5 p-4"
                  >
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-[0.18em] text-warning">
                        Probe
                      </p>
                      <p class="kiln-mono mt-1 text-sm" phx-no-curly-interpolation>
                        {@attach_blocked.probe}
                      </p>
                    </div>
                    <div>
                      <p class="text-xs font-semibold uppercase tracking-[0.18em] text-warning">
                        Next action
                      </p>
                      <p class="mt-1 text-sm text-base-content/80">
                        {@attach_blocked.next_action}
                      </p>
                    </div>
                    <div :if={@brownfield_report} id="attach-blocked-findings" class="space-y-3">
                      <%= for finding <- BrownfieldPreflight.fatal_findings(@brownfield_report) do %>
                        <div class="rounded-lg border border-base-300 bg-base-100/70 p-3">
                          <p class="text-sm font-semibold text-base-content">{finding.title}</p>
                          <p class="mt-1 text-sm text-base-content/80">{finding.why}</p>
                        </div>
                      <% end %>
                    </div>
                    <%= if target = blocked_help_target(@attach_blocked) do %>
                      <.link navigate={target} class="link link-primary">
                        Open the matching setup step
                      </.link>
                    <% end %>
                  </div>
                </div>
              <% :error -> %>
                <div id="attach-source-error" class="space-y-3">
                  <p class="kiln-eyebrow text-warning">Validation feedback</p>
                  <h3 class="text-base font-semibold text-base-content">
                    {@source_error.message}
                  </h3>
                  <p class="text-sm text-base-content/70">
                    {@source_error.remediation}
                  </p>
                  <p class="kiln-meta break-all">
                    Input: {@source_error.input}
                  </p>
                </div>
            <% end %>
          </div>
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
            <h2 class="kiln-h2 mt-2">The next attach plan prepares the workspace</h2>
            <p class="kiln-body mt-2 text-sm">
              This screen resolves the repo source and returns one canonical identity. The next plan prepares the writable workspace and enforces the conservative safety gates before Kiln acts on your code.
            </p>
            <p class="kiln-meta mt-3">
              No workspace hydration, dirty-worktree refusal, branch creation, or PR flow happens yet.
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

  attr :form, :map, required: true
  attr :request_error, :map, default: nil
  attr :continuity, :any, default: nil
  attr :continuity_blank?, :boolean, default: false

  defp attach_request_panel(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-300 bg-base-100/80 p-4">
      <div class="space-y-2">
        <p class="kiln-eyebrow">Bounded request</p>
        <h4 class="text-base font-semibold text-base-content">
          Start one PR-sized feature or bugfix run
        </h4>
        <p class="text-sm text-base-content/70">
          <%= if @continuity do %>
            Review what Kiln carried forward for this repo, or clear it and start blank.
          <% else %>
            Define one bounded outcome, what done looks like, and what stays out of scope.
          <% end %>
        </p>
      </div>

      <%= if @request_error do %>
        <div
          id="attach-request-error"
          class="mt-4 rounded-lg border border-warning/30 bg-warning/10 p-3 text-sm text-base-content/80"
        >
          <p class="font-medium text-base-content">{@request_error.message}</p>
          <p class="mt-1">{@request_error.remediation}</p>
        </div>
      <% end %>

      <.form
        for={@form}
        id="attach-request-form"
        class="mt-4 space-y-4"
        phx-change="validate_request"
        phx-submit="submit_request"
      >
        <.input
          field={@form[:request_kind]}
          id="attach-request-kind"
          type="select"
          label="Request kind"
          options={[Feature: "feature", Bugfix: "bugfix"]}
          prompt="Choose one"
        />

        <.input
          field={@form[:title]}
          id="attach-request-title"
          type="text"
          label="Title"
          placeholder="Tighten attach success flow"
        />

        <.input
          field={@form[:change_summary]}
          id="attach-request-summary"
          type="textarea"
          label="Change summary"
          placeholder="Describe the bounded change this run should deliver."
        />

        <div class="space-y-3">
          <div>
            <label class="label mb-1 block text-sm font-medium text-base-content">
              Acceptance criteria
            </label>
            <p class="text-sm text-base-content/60">
              List the concrete outcomes this run must satisfy.
            </p>
          </div>

          <div class="grid gap-3">
            <%= for index <- 1..3 do %>
              <input
                id={"attach-request-acceptance-#{index}"}
                type="text"
                name="attach_request[acceptance_criteria][]"
                value={request_list_value(@form[:acceptance_criteria], index)}
                class="input w-full"
                placeholder={"Acceptance criterion #{index}"}
              />
            <% end %>
          </div>

          <%= for error <- @form[:acceptance_criteria].errors do %>
            <p class="text-sm text-error">{translate_error(error)}</p>
          <% end %>
        </div>

        <div class="space-y-3">
          <div>
            <label class="label mb-1 block text-sm font-medium text-base-content">
              Out of scope
            </label>
            <p class="text-sm text-base-content/60">
              Record what this run should explicitly avoid.
            </p>
          </div>

          <div class="grid gap-3">
            <%= for index <- 1..3 do %>
              <input
                id={"attach-request-out-of-scope-#{index}"}
                type="text"
                name="attach_request[out_of_scope][]"
                value={request_list_value(@form[:out_of_scope], index)}
                class="input w-full"
                placeholder={"Out of scope item #{index}"}
              />
            <% end %>
          </div>

          <%= for error <- @form[:out_of_scope].errors do %>
            <p class="text-sm text-error">{translate_error(error)}</p>
          <% end %>
        </div>

        <div class="flex items-center justify-between gap-3">
          <p class="kiln-meta">
            <%= if @continuity do %>
              Kiln will recheck hydration, repo safety, and operator setup before launch.
            <% else %>
              Kiln uses the ready attached repo already held on the server.
            <% end %>
          </p>
          <button
            id="attach-request-submit"
            type="submit"
            class="btn btn-primary transition-transform duration-150 hover:-translate-y-0.5"
          >
            Start run
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp assign_resolution(socket, params, {:ok, resolved_source}) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :resolved)
    |> assign(:recent_attached_repos, list_recent_attached_repos())
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, resolved_source)
    |> assign(:source_error, nil)
    |> assign(:continuity, nil)
    |> assign(:continuity_blank?, false)
    |> assign(:brownfield_report, nil)
    |> assign(:brownfield_original_request, nil)
    |> assign(:brownfield_inspected_code, nil)
    |> assign(:request_form, request_form(%{}))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp assign_resolution(socket, params, {:error, source_error}) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :error)
    |> assign(:recent_attached_repos, list_recent_attached_repos())
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, nil)
    |> assign(:source_error, source_error)
    |> assign(:continuity, nil)
    |> assign(:continuity_blank?, false)
    |> assign(:brownfield_report, nil)
    |> assign(:brownfield_original_request, nil)
    |> assign(:brownfield_inspected_code, nil)
    |> assign(:request_form, request_form(%{}))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp reset_resolution(socket, params) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :untouched)
    |> assign(:recent_attached_repos, list_recent_attached_repos())
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, nil)
    |> assign(:source_error, nil)
    |> assign(:continuity, nil)
    |> assign(:continuity_blank?, false)
    |> assign(:brownfield_report, nil)
    |> assign(:brownfield_original_request, nil)
    |> assign(:brownfield_inspected_code, nil)
    |> assign(:request_form, request_form(%{}))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp submit_attach(socket, params, source_input) do
    opts = attach_runtime_opts()

    case Attach.resolve_source(source_input) do
      {:ok, resolved_source} ->
        with {:ok, hydrated} <- Attach.hydrate_workspace(resolved_source, opts),
             {:ok, attached_repo} <-
               create_or_update_attached_repo(resolved_source, hydrated),
             {:ok, ready} <- Attach.preflight_workspace(resolved_source, hydrated, opts) do
          socket
          |> assign(:form, to_form(params, as: :attach_source))
          |> assign(:resolution_state, :ready)
          |> assign(:recent_attached_repos, list_recent_attached_repos())
          |> assign(:attach_ready, ready)
          |> assign(:attached_repo, attached_repo)
          |> assign(:attach_blocked, nil)
          |> assign(:resolved_source, resolved_source)
          |> assign(:source_error, nil)
          |> assign(:continuity, nil)
          |> assign(:continuity_blank?, false)
          |> assign(:brownfield_report, nil)
          |> assign(:brownfield_original_request, nil)
          |> assign(:brownfield_inspected_code, nil)
          |> assign(:request_form, request_form(%{}))
          |> assign(:request_error, nil)
          |> assign(:request_started_run, nil)
        else
          {:blocked, blocked} ->
            socket
            |> assign(:form, to_form(params, as: :attach_source))
            |> assign(:resolution_state, :blocked)
            |> assign(:recent_attached_repos, list_recent_attached_repos())
            |> assign(:attach_ready, nil)
            |> assign(:attached_repo, nil)
            |> assign(:attach_blocked, blocked)
            |> assign(:resolved_source, resolved_source)
            |> assign(:source_error, nil)
            |> assign(:continuity, nil)
            |> assign(:continuity_blank?, false)
            |> assign(:brownfield_report, nil)
            |> assign(:brownfield_original_request, nil)
            |> assign(:brownfield_inspected_code, nil)
            |> assign(:request_form, request_form(%{}))
            |> assign(:request_error, nil)
            |> assign(:request_started_run, nil)

          {:error, %Ecto.Changeset{} = changeset} ->
            assign_resolution(socket, params, {:error, attached_repo_error(changeset)})

          {:error, error} when is_map(error) ->
            assign_resolution(socket, params, {:error, error})
        end

      {:error, source_error} ->
        assign_resolution(socket, params, {:error, source_error})
    end
  end

  defp blocked_help_target(%{code: :github_auth_missing}) do
    OperatorSetup.checklist()
    |> Enum.find(&(&1.id == :github))
    |> OperatorSetup.settings_target()
  end

  defp blocked_help_target(_blocked), do: nil

  defp attached_repo_error(_changeset) do
    %{
      code: :attach_persistence_failed,
      field: :source,
      input: "",
      message: "Kiln could not persist the attached repo metadata.",
      remediation: "Check the database state, then retry attach readiness."
    }
  end

  defp attach_runtime_opts do
    Application.get_env(:kiln, :attach_live_runtime_opts, [])
  end

  defp request_form(params, opts \\ []) do
    params
    |> request_changeset()
    |> Map.put(:action, Keyword.get(opts, :action))
    |> to_form(as: :attach_request)
  end

  defp continuity_request_form(nil, _blank?), do: request_form(%{})

  defp continuity_request_form(_continuity, true), do: request_form(%{})

  defp continuity_request_form(continuity, false) do
    continuity.carry_forward
    |> request_params_from_carry_forward()
    |> request_form()
  end

  defp request_params_from_carry_forward(%{source: :blank}), do: %{}

  defp request_params_from_carry_forward(carry_forward) do
    %{
      "request_kind" => carry_forward.request_kind && Atom.to_string(carry_forward.request_kind),
      "title" => carry_forward.title,
      "change_summary" => carry_forward.change_summary,
      "acceptance_criteria" => carry_forward.acceptance_criteria,
      "out_of_scope" => carry_forward.out_of_scope
    }
  end

  defp request_params_from_brownfield_request(nil), do: %{}

  defp request_params_from_brownfield_request(request) do
    %{
      "request_kind" => request.request_kind && Atom.to_string(request.request_kind),
      "title" => request.title,
      "change_summary" => request.change_summary,
      "acceptance_criteria" => request.acceptance_criteria,
      "out_of_scope" => request.out_of_scope
    }
  end

  defp request_changeset(params) do
    IntakeRequest.changeset(%IntakeRequest{}, params)
  end

  defp submit_request(%{assigns: %{attached_repo: nil}} = socket, params) do
    socket
    |> assign(:request_form, request_form(params, action: :validate))
    |> assign(:request_error, %{
      message: "Resolve one attached repo before starting a bounded request.",
      remediation: "Return to the source form, then re-run the ready-state flow."
    })
  end

  defp submit_request(%{assigns: %{attached_repo: attached_repo}} = socket, params) do
    changeset = request_changeset(params)

    if changeset.valid? do
      normalized_request = IntakeRequest.to_attrs(changeset)

      case maybe_refresh_attached_repo(socket, attached_repo) do
        {:ok, socket, attached_repo} ->
          report = evaluate_brownfield_preflight(attached_repo, normalized_request)

          cond do
            BrownfieldPreflight.fatal?(report) ->
              assign_brownfield_blocked(socket, params, report)

            BrownfieldPreflight.needs_narrowing?(report) ->
              assign_brownfield_warning(socket, params, report)

            true ->
              finalize_attached_request_start(socket, params, attached_repo, report)
          end

        {:blocked, blocked, socket} ->
          socket
          |> assign(:request_form, request_form(params))
          |> assign(:request_error, blocked_request_error(blocked))
          |> assign(:request_started_run, nil)
      end
    else
      changeset = Map.put(changeset, :action, :insert)

      socket
      |> assign(:request_form, to_form(changeset, as: :attach_request))
      |> assign(:request_error, nil)
      |> assign(:request_started_run, nil)
    end
  end

  defp finalize_attached_request_start(socket, params, attached_repo, report) do
    with :ok <- preflight_attached_request_start(),
         {:ok, draft} <- create_attached_request_draft(attached_repo.id, params),
         {:ok, promoted_request} <- promote_attached_request_draft(draft.id),
         {:ok, run} <- start_attached_request_run(promoted_request, attached_repo.id) do
      _ = mark_run_started(attached_repo.id)

      socket
      |> assign(:resolution_state, ready_state_after_start(socket))
      |> assign(:brownfield_report, report)
      |> assign(:brownfield_original_request, nil)
      |> assign(:brownfield_inspected_code, nil)
      |> assign(:request_form, request_form(%{}))
      |> assign(:request_error, nil)
      |> assign(:request_started_run, run)
    else
      {:blocked, blocked} ->
        socket
        |> assign(:request_form, request_form(params))
        |> assign(:request_error, blocked_request_error(blocked))
        |> assign(:request_started_run, nil)

      {:error, :missing_api_key} ->
        socket
        |> assign(:request_form, request_form(params))
        |> assign(:request_error, %{
          message:
            "Kiln cannot start the attached run until provider credentials are configured.",
          remediation:
            "Open provider health or settings, add the missing credential reference, and resubmit."
        })
        |> assign(:request_started_run, nil)

      {:error, _reason} ->
        socket
        |> assign(:request_form, request_form(params))
        |> assign(:request_error, %{
          message: "Kiln could not start the attached run.",
          remediation:
            "Review the request details, then retry once the blocking issue is resolved."
        })
        |> assign(:request_started_run, nil)
    end
  end

  defp maybe_refresh_attached_repo(
         %{assigns: %{resolution_state: :continuity}} = socket,
         attached_repo
       ) do
    case refresh_attached_repo(attached_repo) do
      {:ok, %{attached_repo: refreshed_repo}} ->
        {:ok, assign(socket, :attached_repo, refreshed_repo), refreshed_repo}

      {:blocked, blocked} ->
        {:blocked, blocked, socket}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_refresh_attached_repo(socket, attached_repo), do: {:ok, socket, attached_repo}

  defp ready_state_after_start(%{assigns: %{continuity: %{} = _continuity}}), do: :continuity
  defp ready_state_after_start(_socket), do: :ready

  defp request_list_value(field, index) do
    field.value
    |> List.wrap()
    |> Enum.at(index - 1, "")
  end

  defp create_or_update_attached_repo(resolved_source, hydrated) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :create_or_update_attached_repo_fn,
        &Attach.create_or_update_attached_repo/2
      )

    fun.(resolved_source, hydrated)
  end

  defp list_recent_attached_repos do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :list_recent_attached_repos_fn,
        &Attach.list_recent_attached_repos/1
      )

    fun.([])
  end

  defp evaluate_brownfield_preflight(attached_repo, params) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :brownfield_preflight_fn,
        &Attach.evaluate_brownfield_preflight/3
      )

    fun.(attached_repo, params, attach_runtime_opts())
  end

  defp get_repo_continuity(attached_repo_id, opts) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :get_repo_continuity_fn,
        &Attach.get_repo_continuity/2
      )

    fun.(attached_repo_id, opts)
  end

  defp mark_repo_selected(attached_repo_id) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :mark_repo_selected_fn,
        &Attach.mark_repo_selected/2
      )

    fun.(attached_repo_id, [])
  end

  defp mark_run_started(attached_repo_id) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :mark_run_started_fn,
        &Attach.mark_run_started/2
      )

    fun.(attached_repo_id, [])
  end

  defp refresh_attached_repo(attached_repo) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :refresh_attached_repo_fn,
        &Attach.refresh_attached_repo/2
      )

    fun.(attached_repo, attach_runtime_opts())
  end

  defp create_attached_request_draft(attached_repo_id, params) do
    fun = Keyword.get(attach_runtime_opts(), :intake_fn, &Kiln.Attach.Intake.create_draft/2)
    fun.(attached_repo_id, params)
  end

  defp promote_attached_request_draft(draft_id) do
    fun =
      Keyword.get(attach_runtime_opts(), :promote_draft_fn, fn id, opts ->
        Specs.promote_draft(id, opts)
      end)

    fun.(draft_id, [])
  end

  defp start_attached_request_run(promoted_request, attached_repo_id) do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :start_for_attached_request_fn,
        &Runs.start_for_attached_request/3
      )

    fun.(promoted_request, attached_repo_id, [])
  end

  defp preflight_attached_request_start do
    fun =
      Keyword.get(
        attach_runtime_opts(),
        :preflight_attached_request_start_fn,
        &Runs.preflight_attached_request_start/0
      )

    fun.()
  end

  defp blocked_request_error(%{blocker: blocker}) do
    %{
      message: "Kiln cannot start the attached run until operator setup is complete.",
      remediation:
        "Resolve #{blocker.label} in settings or provider health, then resubmit this bounded request."
    }
  end

  defp blocked_request_error(_blocked) do
    %{
      message: "Kiln cannot start the attached run yet.",
      remediation: "Resolve the blocking setup issue, then resubmit this bounded request."
    }
  end

  defp source_kind_label(:local_path), do: "Local path"
  defp source_kind_label(:github_url), do: "GitHub URL"

  defp carry_forward_label(%{source: :draft}), do: "Open draft"
  defp carry_forward_label(%{source: :promoted_request}), do: "Promoted request"
  defp carry_forward_label(%{source: :run}), do: "Prior run"
  defp carry_forward_label(_), do: "Continuity"

  defp recent_repo_patch(attached_repo_id) do
    ~p"/attach?attached_repo_id=#{attached_repo_id}"
  end

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(%DateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M UTC")
  end

  defp load_continuity(socket, params) do
    recent_repos = list_recent_attached_repos()
    attached_repo_id = Map.get(params, "attached_repo_id")

    socket = assign(socket, :recent_attached_repos, recent_repos)

    cond do
      is_nil(attached_repo_id) or attached_repo_id == "" ->
        socket

      true ->
        continuity_opts =
          []
          |> maybe_put_continuity_opt(:draft_id, Map.get(params, "draft_id"))
          |> maybe_put_continuity_opt(:run_id, Map.get(params, "run_id"))

        case get_repo_continuity(attached_repo_id, continuity_opts) do
          {:ok, continuity} ->
            _ = mark_repo_selected(attached_repo_id)
            blank? = Map.get(params, "mode") == "blank"

            socket
            |> assign(:resolution_state, :continuity)
            |> assign(:attach_ready, nil)
            |> assign(:attach_blocked, nil)
            |> assign(:resolved_source, nil)
            |> assign(:source_error, nil)
            |> assign(:continuity, continuity)
            |> assign(:continuity_blank?, blank?)
            |> assign(:brownfield_report, nil)
            |> assign(:brownfield_original_request, nil)
            |> assign(:brownfield_inspected_code, nil)
            |> assign(:attached_repo, continuity.attached_repo)
            |> assign(:request_form, continuity_request_form(continuity, blank?))
            |> assign(:request_error, nil)
            |> assign(:request_started_run, nil)

          {:error, :not_found} ->
            socket
        end
    end
  end

  defp maybe_put_continuity_opt(opts, _key, nil), do: opts
  defp maybe_put_continuity_opt(opts, _key, ""), do: opts
  defp maybe_put_continuity_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp assign_brownfield_warning(socket, params, report) do
    socket
    |> assign(:resolution_state, :warning)
    |> assign(:attach_blocked, nil)
    |> assign(:brownfield_report, report)
    |> assign(:brownfield_original_request, params)
    |> assign(:brownfield_inspected_code, default_warning_code(report))
    |> assign(:request_form, request_form(params))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp assign_brownfield_blocked(socket, params, report) do
    socket
    |> assign(:resolution_state, :blocked)
    |> assign(:attach_ready, nil)
    |> assign(:attach_blocked, brownfield_blocked(report))
    |> assign(:brownfield_report, report)
    |> assign(:brownfield_original_request, params)
    |> assign(:brownfield_inspected_code, nil)
    |> assign(:request_form, request_form(params))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp default_warning_code(report) do
    report
    |> BrownfieldPreflight.warning_findings()
    |> List.first()
    |> case do
      nil -> nil
      finding -> finding_code(finding)
    end
  end

  defp finding_code(finding), do: Atom.to_string(finding.code)

  defp inspected_warning_finding(nil, _code), do: nil

  defp inspected_warning_finding(report, code) when is_binary(code) do
    Enum.find(BrownfieldPreflight.warning_findings(report), &(finding_code(&1) == code))
  end

  defp inspected_warning_finding(report, _code) do
    report
    |> BrownfieldPreflight.warning_findings()
    |> List.first()
  end

  defp warning_evidence_rows(evidence) do
    [
      {"Repo", Map.get(evidence, :repo_slug)},
      {"Base branch", Map.get(evidence, :base_branch)},
      {"Branch", Map.get(evidence, :branch)},
      {"Prior draft", Map.get(evidence, :draft_id)},
      {"Prior revision", Map.get(evidence, :spec_revision_id)},
      {"Prior run", Map.get(evidence, :run_id)},
      {"Open PR", Map.get(evidence, :pr_url)}
    ]
    |> Enum.reject(fn {_label, value} -> is_nil(value) or value == "" end)
  end

  defp brownfield_blocked(report) do
    [finding | _] = BrownfieldPreflight.fatal_findings(report)

    %{
      status: :blocked,
      code: :brownfield_preflight,
      scope: :attached_workspace,
      title: finding.title,
      message: "Kiln found a deterministic brownfield conflict for this request.",
      why: finding.why,
      probe: "brownfield_preflight",
      next_action: finding.next_action,
      workspace_path: "attached workspace",
      repo_slug: report.repo_slug
    }
  end
end
