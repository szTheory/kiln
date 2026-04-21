defmodule KilnWeb.SpecEditorLive do
  @moduledoc """
  SPEC-01 — operator markdown spec editor (`/specs/:id/edit`).

  Autosave: `phx-change` on the form with **3s `phx-debounce`** on the body
  textarea so parse validation is not fired on every keystroke.
  """

  use KilnWeb, :live_view

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.{ScenarioParser, Spec}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Ecto.UUID.cast(id) do
      :error ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid spec id")
         |> push_navigate(to: ~p"/")}

      {:ok, uuid} ->
        case Repo.get(Spec, uuid) do
          nil ->
            {:ok,
             socket
             |> put_flash(:error, "Spec not found")
             |> push_navigate(to: ~p"/")}

          spec ->
            revision = Specs.latest_revision_for_spec(spec.id)
            body = if(revision, do: revision.body, else: "")

            {:ok,
             socket
             |> assign(:spec, spec)
             |> assign(:revision, revision)
             |> assign(:body, body)
             |> assign(:save_state, :saved)
             |> assign(:last_saved_at, revision && revision.inserted_at)
             |> assign(:parse_error, nil)}
        end
    end
  end

  @impl true
  def handle_event("body_changed", %{"spec" => %{"body" => body}}, socket) do
    socket =
      socket
      |> assign(:body, body)
      |> assign(:save_state, :unsaved)
      |> assign(:parse_error, preview_parse_error(body))

    {:noreply, socket}
  end

  def handle_event("save", %{"spec" => %{"body" => body}}, socket) do
    save_body(socket, body)
  end

  def handle_event("save_shortcut", %{"body" => body}, socket) do
    save_body(socket, body)
  end

  defp save_body(socket, body) do
    spec = socket.assigns.spec

    case preview_parse_error(body) do
      nil ->
        socket = assign(socket, :save_state, :saving)

        case Specs.create_revision(spec, %{body: body}) do
          {:ok, rev} ->
            {:noreply,
             socket
             |> assign(:revision, rev)
             |> assign(:body, body)
             |> assign(:save_state, :saved)
             |> assign(:last_saved_at, rev.inserted_at)
             |> assign(:parse_error, nil)
             |> put_flash(:info, "Revision saved")}

          {:error, cs} ->
            {:noreply,
             socket
             |> assign(:save_state, :error)
             |> assign(:parse_error, format_changeset(cs))}
        end

      err ->
        {:noreply,
         socket
         |> assign(:save_state, :error)
         |> assign(:parse_error, err)}
    end
  end

  defp preview_parse_error(""), do: nil

  defp preview_parse_error(body) when is_binary(body) do
    case ScenarioParser.parse_document(body) do
      {:ok, _} -> nil
      {:error, reason} -> format_parse(reason)
    end
  end

  defp format_parse({:no_kiln_scenario_blocks, msg}), do: msg
  defp format_parse({:schema_invalid, errs}), do: "Invalid scenario IR: #{inspect(errs)}"
  defp format_parse({:no_scenarios, msg}), do: msg
  defp format_parse(other), do: inspect(other)

  defp format_changeset(cs), do: inspect(cs.errors)
end
