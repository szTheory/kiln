defmodule KilnWeb.InboxLive do
  @moduledoc """
  INTAKE-01/02 — spec draft inbox at `/inbox` (streams, promote/archive/edit, imports).
  """

  use KilnWeb, :live_view

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.SpecDraft

  @max_md_bytes 262_144

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Inbox")
      |> assign(:github_busy?, false)
      |> assign(:editing, nil)
      |> assign(:edit_form, nil)
      |> assign(:freeform_form, to_form(%{"title" => "", "body" => ""}, as: :draft))
      |> assign(:github_form, to_form(%{"ref" => ""}, as: :github))
      |> allow_upload(:markdown,
        accept: ~w(.md .markdown),
        max_entries: 1,
        max_file_size: @max_md_bytes,
        auto_upload: true
      )

    {:ok, reload_drafts(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    editing =
      case params["edit"] do
        nil ->
          {nil, nil}

        id ->
          case open_draft_for_edit(id) do
            nil -> {nil, nil}
            %SpecDraft{} = d -> {id, d}
          end
      end

    {_eid, edraft} = editing

    edit_form =
      if edraft do
        to_form(
          %{"id" => edraft.id, "title" => edraft.title, "body" => edraft.body},
          as: :spec_draft
        )
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:editing, if(edraft, do: {edraft.id, edraft}, else: nil))
     |> assign(:edit_form, edit_form)}
  end

  defp open_draft_for_edit(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get(SpecDraft, uuid) do
          %SpecDraft{inbox_state: :open} = d -> d
          _ -> nil
        end

      :error ->
        nil
    end
  end

  @impl true
  def handle_event("promote", %{"id" => id}, socket) do
    case Specs.promote_draft(id) do
      {:ok, %{spec: spec}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft promoted to spec")
         |> stream_delete(:drafts, %SpecDraft{id: id})
         |> assign(:drafts_empty?, Specs.list_open_drafts() == [])
         |> push_navigate(to: ~p"/specs/#{spec.id}/edit")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not promote draft")}
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    case Specs.archive_draft(id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft archived")
         |> stream_delete(:drafts, %SpecDraft{id: id})
         |> assign(:drafts_empty?, Specs.list_open_drafts() == [])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not archive draft")}
    end
  end

  def handle_event("import_github", %{"github" => %{"ref" => ref}}, socket) do
    ref = String.trim(ref)
    socket = assign(socket, :github_busy?, true)

    import_opts = Application.get_env(:kiln, :inbox_github_import_opts, [])

    result =
      cond do
        ref == "" ->
          {:error, :empty}

        String.contains?(ref, "github.com") ->
          Specs.import_github_issue_from_url(ref, import_opts)

        true ->
          Specs.import_github_issue_from_slug(ref, import_opts)
      end

    socket =
      socket
      |> assign(:github_busy?, false)
      |> assign(:github_form, to_form(%{"ref" => ref}, as: :github))

    case result do
      {:ok, draft} ->
        {:noreply,
         socket
         |> put_flash(:info, "Imported GitHub issue")
         |> assign(:drafts_empty?, false)
         |> stream_insert(:drafts, draft)}

      {:error, :empty} ->
        {:noreply, put_flash(socket, :error, "Enter an issue URL or owner/repo#N")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "GitHub import failed — check reference and token")}
    end
  end

  def handle_event("create_freeform", %{"draft" => %{"title" => title, "body" => body}}, socket) do
    title = String.trim(title)
    body = String.trim(body)

    if title == "" or body == "" do
      {:noreply, put_flash(socket, :error, "Title and body are required")}
    else
      case Specs.create_draft(%{
             title: title,
             body: body,
             source: :freeform
           }) do
        {:ok, draft} ->
          {:noreply,
           socket
           |> put_flash(:info, "Draft created")
           |> assign(:drafts_empty?, false)
           |> assign(:freeform_form, to_form(%{"title" => "", "body" => ""}, as: :draft))
           |> stream_insert(:drafts, draft)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not create draft")}
      end
    end
  end

  def handle_event("import_markdown", _params, socket) do
    results =
      consume_uploaded_entries(socket, :markdown, fn %{path: path}, entry ->
        with {:ok, body} <- File.read(path),
             true <- String.valid?(body) do
          title = entry.client_name |> Path.rootname()
          {:ok, {title, body}}
        else
          _ -> :error
        end
      end)

    case results do
      [{:ok, {title, body}}] ->
        case Specs.create_draft(%{
               title: title,
               body: body,
               source: :markdown_import
             }) do
          {:ok, draft} ->
            {:noreply,
             socket
             |> put_flash(:info, "Markdown imported")
             |> assign(:drafts_empty?, false)
             |> stream_insert(:drafts, draft)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not save imported markdown")}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "Choose a markdown file")}

      _ ->
        {:noreply, put_flash(socket, :error, "Upload failed")}
    end
  end

  def handle_event("save_edit", %{"spec_draft" => params}, socket) do
    id = params["id"]
    title = params["title"] |> to_string() |> String.trim()
    body = params["body"] |> to_string()

    case Specs.update_open_draft(id, %{title: title, body: body}) do
      {:ok, draft} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft saved")
         |> assign(:editing, nil)
         |> assign(:edit_form, nil)
         |> stream_insert(:drafts, draft)
         |> push_patch(to: ~p"/inbox")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save draft")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, nil)
     |> assign(:edit_form, nil)
     |> push_patch(to: ~p"/inbox")}
  end

  defp reload_drafts(socket) do
    drafts = Specs.list_open_drafts()

    socket
    |> assign(:drafts_empty?, drafts == [])
    |> stream(:drafts, drafts, reset: true, dom_id: &"draft-#{&1.id}")
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
      <div id="inbox" class="space-y-8">
        <div class="flex flex-col gap-3 border-b border-base-300 pb-4 sm:flex-row sm:items-end sm:justify-between">
          <div class="min-w-0">
            <p class="kiln-eyebrow">Spec intake</p>
            <h1 class="kiln-h1 mt-1">Inbox</h1>
            <p class="kiln-meta mt-1">
              Triage spec drafts before they become runnable specs.
            </p>
          </div>
          <.link
            navigate={~p"/templates"}
            id="inbox-browse-templates"
            class="btn btn-sm btn-ghost border border-base-300 hover:border-primary"
          >
            Browse templates
          </.link>
        </div>

        <%= if @drafts_empty? do %>
          <section class="card card-bordered bg-base-200 border-base-300">
            <div class="card-body p-8">
              <h2 class="kiln-h2">No drafts in the inbox</h2>
              <p class="kiln-body text-base-content/70 mt-2">
                Create a spec from text, import markdown, or pull a GitHub issue. Promote a draft when it is ready to run.
              </p>
            </div>
          </section>
        <% end %>

        <div id="inbox-drafts" phx-update="stream" class="space-y-3">
          <div
            :for={{dom_id, draft} <- @streams.drafts}
            id={dom_id}
            class="card card-bordered bg-base-200 border-base-300"
          >
            <div class="card-body p-5">
              <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div class="min-w-0">
                  <h3 class="kiln-h2">{draft.title}</h3>
                  <p class="kiln-body text-base-content/70 mt-1 line-clamp-3">{draft.body}</p>
                </div>
                <div class="flex flex-wrap gap-2">
                  <button
                    type="button"
                    class="btn btn-sm btn-primary"
                    phx-click="promote"
                    phx-value-id={draft.id}
                  >
                    Promote
                  </button>
                  <button
                    type="button"
                    class="btn btn-sm btn-ghost border border-base-300"
                    phx-click="archive"
                    phx-value-id={draft.id}
                  >
                    Archive
                  </button>
                  <.link
                    patch={~p"/inbox?edit=#{draft.id}"}
                    class="btn btn-sm btn-ghost border border-base-300"
                  >
                    Edit
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%= if @edit_form do %>
          <section class="card card-bordered bg-base-200 border-primary/40">
            <div class="card-body p-5">
              <h2 class="kiln-h2">Edit draft</h2>
              <.form
                for={@edit_form}
                id="inbox-edit-form"
                phx-submit="save_edit"
                class="mt-4 space-y-3"
              >
                <.input field={@edit_form[:id]} type="hidden" />
                <.input field={@edit_form[:title]} type="text" label="Title" />
                <.input field={@edit_form[:body]} type="textarea" label="Body" rows="12" />
                <div class="flex flex-wrap gap-2">
                  <button type="submit" class="btn btn-primary btn-sm">Save</button>
                  <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_edit">
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </section>
        <% end %>

        <section class="card card-bordered bg-base-200 border-base-300">
          <div class="card-body p-5 grid gap-6 md:grid-cols-2">
            <div>
              <h2 class="kiln-eyebrow">New draft</h2>
              <.form
                for={@freeform_form}
                id="inbox-freeform-form"
                phx-submit="create_freeform"
                class="mt-3 space-y-2"
              >
                <.input field={@freeform_form[:title]} type="text" label="Title" />
                <.input field={@freeform_form[:body]} type="textarea" label="Body" rows="6" />
                <button type="submit" class="btn btn-primary btn-sm">Create draft</button>
              </.form>
            </div>

            <div class="space-y-6">
              <div>
                <h2 class="kiln-eyebrow">Import from GitHub</h2>
                <.form
                  for={@github_form}
                  id="inbox-github-form"
                  phx-submit="import_github"
                  class="mt-3 space-y-2"
                >
                  <.input field={@github_form[:ref]} type="text" label="URL or owner/repo#N" />
                  <button type="submit" class="btn btn-primary btn-sm" disabled={@github_busy?}>
                    {if @github_busy?, do: "Syncing issue…", else: "Import from GitHub"}
                  </button>
                </.form>
              </div>

              <div>
                <h2 class="kiln-eyebrow">Import markdown</h2>
                <.form
                  for={%{}}
                  id="inbox-md-form"
                  phx-submit="import_markdown"
                  class="mt-3 space-y-2"
                >
                  <label for="inbox-markdown-upload" class="label mb-1 block">
                    Markdown file
                  </label>
                  <.live_file_input
                    upload={@uploads.markdown}
                    id="inbox-markdown-upload"
                    aria-label="Markdown file"
                    class="file-input file-input-bordered file-input-sm w-full"
                  />
                  <button type="submit" class="btn btn-primary btn-sm">Import markdown</button>
                </.form>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
