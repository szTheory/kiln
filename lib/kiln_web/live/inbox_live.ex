defmodule KilnWeb.InboxLive do
  @moduledoc """
  INTAKE-01/02 — spec draft inbox at `/inbox` (streams, promote/archive/edit, imports).
  """

  use KilnWeb, :live_view

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Dogfood.Template
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
    _ = allow?(socket)

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
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
  end

  def handle_event("archive", %{"id" => id}, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
  end

  def handle_event("import_github", %{"github" => %{"ref" => ref}}, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
          {:noreply,
           put_flash(socket, :error, "GitHub import failed — check reference and token")}
      end
    end
  end

  def handle_event("create_freeform", %{"draft" => %{"title" => title, "body" => body}}, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
  end

  def handle_event("import_markdown", _params, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
  end

  def handle_event("save_edit", %{"spec_draft" => params}, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
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
  end

  def handle_event("cancel_edit", _params, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
      {:noreply,
       socket
       |> assign(:editing, nil)
       |> assign(:edit_form, nil)
       |> push_patch(to: ~p"/inbox")}
    end
  end

  def handle_event("load_dogfood_template", _params, socket) do
    unless allow?(socket) do
      {:noreply, put_flash(socket, :error, "Not allowed")}
    else
      case socket.assigns.editing do
        {_id, %SpecDraft{} = d} ->
          case Template.read() do
            {:ok, body} ->
              edit_form =
                to_form(
                  %{"id" => d.id, "title" => d.title, "body" => body},
                  as: :spec_draft
                )

              {:noreply,
               socket
               |> assign(:edit_form, edit_form)
               |> put_flash(:info, "Loaded dogfood template")}

            {:error, reason} ->
              {:noreply,
               put_flash(socket, :error, "Could not load dogfood/spec.md (#{inspect(reason)})")}
          end

        _ ->
          {:noreply, put_flash(socket, :error, "Open a draft in the editor first")}
      end
    end
  end

  defp reload_drafts(socket) do
    drafts = Specs.list_open_drafts()

    socket
    |> assign(:drafts_empty?, drafts == [])
    |> stream(:drafts, drafts, reset: true, dom_id: &"draft-#{&1.id}")
  end

  defp allow?(_socket), do: true

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} factory_summary={@factory_summary}>
      <div id="inbox" class="space-y-8 text-bone">
        <div class="border-b border-ash pb-4">
          <h1 class="text-xl font-semibold">Inbox</h1>
          <p class="mt-1 text-sm text-[var(--color-smoke)]">
            Triage spec drafts before they become runnable specs.
          </p>
        </div>

        <%= if @drafts_empty? do %>
          <section class="rounded border border-ash bg-char/80 p-8">
            <h2 class="text-lg font-semibold">No drafts in the inbox</h2>
            <p class="mt-2 text-sm text-[var(--color-smoke)]">
              Create a spec from text, import markdown, or pull a GitHub issue. Promote a draft when it is ready to run.
            </p>
          </section>
        <% end %>

        <div id="inbox-drafts" phx-update="stream" class="space-y-3">
          <div
            :for={{dom_id, draft} <- @streams.drafts}
            id={dom_id}
            class="rounded border border-ash bg-char/80 p-4"
          >
            <div class="flex flex-wrap items-start justify-between gap-2">
              <div>
                <h3 class="font-semibold">{draft.title}</h3>
                <p class="mt-1 line-clamp-3 text-xs text-[var(--color-smoke)]">{draft.body}</p>
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  class="btn btn-sm border border-ash bg-iron/40"
                  phx-click="promote"
                  phx-value-id={draft.id}
                >
                  Promote
                </button>
                <button
                  type="button"
                  class="btn btn-sm border border-ash bg-iron/40"
                  phx-click="archive"
                  phx-value-id={draft.id}
                >
                  Archive
                </button>
                <.link
                  patch={~p"/inbox?edit=#{draft.id}"}
                  class="btn btn-sm border border-ash bg-iron/40"
                >
                  Edit
                </.link>
              </div>
            </div>
          </div>
        </div>

        <%= if @edit_form do %>
          <section class="rounded border border-ember/40 bg-char/80 p-4">
            <h2 class="text-lg font-semibold">Edit draft</h2>
            <.form for={@edit_form} id="inbox-edit-form" phx-submit="save_edit" class="mt-4 space-y-3">
              <.input field={@edit_form[:id]} type="hidden" />
              <.input field={@edit_form[:title]} type="text" label="Title" />
              <.input field={@edit_form[:body]} type="textarea" label="Body" rows="12" />
              <div class="flex flex-wrap gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Save</button>
                <button
                  type="button"
                  id="inbox-load-dogfood-template"
                  class="btn btn-ghost btn-sm"
                  phx-click="load_dogfood_template"
                >
                  Load dogfood template
                </button>
                <button type="button" class="btn btn-ghost btn-sm" phx-click="cancel_edit">
                  Cancel
                </button>
              </div>
            </.form>
          </section>
        <% end %>

        <section class="grid gap-6 rounded border border-ash bg-char/60 p-4 md:grid-cols-2">
          <div>
            <h2 class="text-sm font-semibold uppercase text-[var(--color-smoke)]">New draft</h2>
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

          <div class="space-y-4">
            <div>
              <h2 class="text-sm font-semibold uppercase text-[var(--color-smoke)]">
                Import from GitHub
              </h2>
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
              <h2 class="text-sm font-semibold uppercase text-[var(--color-smoke)]">
                Import markdown
              </h2>
              <.form for={%{}} id="inbox-md-form" phx-submit="import_markdown" class="mt-3 space-y-2">
                <.live_file_input upload={@uploads.markdown} />
                <button type="submit" class="btn btn-primary btn-sm">Import markdown</button>
              </.form>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
