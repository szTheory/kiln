defmodule KilnWeb.SpecEditorLiveTest do
  use KilnWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Kiln.Repo
  alias Kiln.Specs
  alias Kiln.Specs.SpecRevision

  @fixture Path.join(["test", "fixtures", "specs", "minimal_spec.md"])

  test "mount renders spec editor form", %{conn: conn} do
    body = File.read!(@fixture)
    {:ok, spec} = Specs.create_spec(%{title: "Editor smoke"})
    {:ok, _} = Specs.create_revision(spec, %{body: body})

    {:ok, view, _html} = live(conn, ~p"/specs/#{spec.id}/edit")
    assert has_element?(view, "#spec-editor-form")
    assert has_element?(view, "#spec-body")
  end

  test "save submits valid body and creates a new revision row", %{conn: conn} do
    body = File.read!(@fixture)
    {:ok, spec} = Specs.create_spec(%{title: "Revision append"})
    {:ok, _} = Specs.create_revision(spec, %{body: body})

    {:ok, view, _html} = live(conn, ~p"/specs/#{spec.id}/edit")

    before = Repo.aggregate(from(r in SpecRevision, where: r.spec_id == ^spec.id), :count)

    view
    |> form("#spec-editor-form", spec: %{body: body})
    |> render_submit()

    after_count = Repo.aggregate(from(r in SpecRevision, where: r.spec_id == ^spec.id), :count)
    assert after_count == before + 1
  end
end
