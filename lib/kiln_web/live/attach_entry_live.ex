defmodule KilnWeb.AttachEntryLive do
  @moduledoc """
  Attach source intake surface at `/attach`.
  """

  use KilnWeb, :live_view

  alias Kiln.Attach
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
     |> assign(:request_error, nil)
     |> assign(:request_started_run, nil)
     |> assign(:form, to_form(%{"source" => ""}, as: :attach_source))
     |> assign(:request_form, request_form(%{}))}
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
                    <div class="rounded-xl border border-base-300 bg-base-100/80 p-4">
                      <div class="space-y-2">
                        <p class="kiln-eyebrow">Bounded request</p>
                        <h4 class="text-base font-semibold text-base-content">
                          Start one PR-sized feature or bugfix run
                        </h4>
                        <p class="text-sm text-base-content/70">
                          Define one bounded outcome, what done looks like, and what stays out of scope.
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
                        for={@request_form}
                        id="attach-request-form"
                        class="mt-4 space-y-4"
                        phx-change="validate_request"
                        phx-submit="submit_request"
                      >
                        <.input
                          field={@request_form[:request_kind]}
                          id="attach-request-kind"
                          type="select"
                          label="Request kind"
                          options={[Feature: "feature", Bugfix: "bugfix"]}
                          prompt="Choose one"
                        />

                        <.input
                          field={@request_form[:title]}
                          id="attach-request-title"
                          type="text"
                          label="Title"
                          placeholder="Tighten attach success flow"
                        />

                        <.input
                          field={@request_form[:change_summary]}
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
                                value={request_list_value(@request_form[:acceptance_criteria], index)}
                                class="input w-full"
                                placeholder={"Acceptance criterion #{index}"}
                              />
                            <% end %>
                          </div>

                          <%= for error <- @request_form[:acceptance_criteria].errors do %>
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
                                value={request_list_value(@request_form[:out_of_scope], index)}
                                class="input w-full"
                                placeholder={"Out of scope item #{index}"}
                              />
                            <% end %>
                          </div>

                          <%= for error <- @request_form[:out_of_scope].errors do %>
                            <p class="text-sm text-error">{translate_error(error)}</p>
                          <% end %>
                        </div>

                        <div class="flex items-center justify-between gap-3">
                          <p class="kiln-meta">
                            Kiln uses the ready attached repo already held on the server.
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
                  <% end %>
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

  defp assign_resolution(socket, params, {:ok, resolved_source}) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :resolved)
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, resolved_source)
    |> assign(:source_error, nil)
    |> assign(:request_form, request_form(%{}))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp assign_resolution(socket, params, {:error, source_error}) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :error)
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, nil)
    |> assign(:source_error, source_error)
    |> assign(:request_form, request_form(%{}))
    |> assign(:request_error, nil)
    |> assign(:request_started_run, nil)
  end

  defp reset_resolution(socket, params) do
    socket
    |> assign(:form, to_form(params, as: :attach_source))
    |> assign(:resolution_state, :untouched)
    |> assign(:attach_ready, nil)
    |> assign(:attached_repo, nil)
    |> assign(:attach_blocked, nil)
    |> assign(:resolved_source, nil)
    |> assign(:source_error, nil)
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
          |> assign(:attach_ready, ready)
          |> assign(:attached_repo, attached_repo)
          |> assign(:attach_blocked, nil)
          |> assign(:resolved_source, resolved_source)
          |> assign(:source_error, nil)
          |> assign(:request_form, request_form(%{}))
          |> assign(:request_error, nil)
          |> assign(:request_started_run, nil)
        else
          {:blocked, blocked} ->
            socket
            |> assign(:form, to_form(params, as: :attach_source))
            |> assign(:resolution_state, :blocked)
            |> assign(:attach_ready, nil)
            |> assign(:attached_repo, nil)
            |> assign(:attach_blocked, blocked)
            |> assign(:resolved_source, resolved_source)
            |> assign(:source_error, nil)
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
    with {:ok, draft} <- create_attached_request_draft(attached_repo.id, params),
         {:ok, promoted_request} <- promote_attached_request_draft(draft.id),
         {:ok, run} <- start_attached_request_run(promoted_request, attached_repo.id) do
      socket
      |> assign(:request_form, request_form(%{}))
      |> assign(:request_error, nil)
      |> assign(:request_started_run, run)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        changeset = Map.put(changeset, :action, :insert)

        socket
        |> assign(:request_form, to_form(changeset, as: :attach_request))
        |> assign(:request_error, nil)
        |> assign(:request_started_run, nil)

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
end
