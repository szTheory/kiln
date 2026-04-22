defmodule KilnWeb.InboxLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Specs

  @req_stub __MODULE__.ReqStub

  describe "inbox without github stub" do
    test "renders empty inbox copy and id=inbox", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/inbox")

      assert html =~ ~s(id="inbox")
      assert has_element?(view, "#inbox")
      assert render(view) =~ "No drafts in the inbox"
      assert render(view) =~ "Create a spec from text, import markdown, or pull a GitHub issue."
    end

    test "lists draft with Promote after seeding", %{conn: conn} do
      {:ok, _} =
        Specs.create_draft(%{
          title: "Seed draft",
          body: "Body text",
          source: :freeform
        })

      {:ok, view, _html} = live(conn, ~p"/inbox")
      html = render(view)
      assert html =~ "Seed draft"
      assert has_element?(view, "button[phx-click=promote]")
    end
  end

  describe "github import with Req.Test" do
    setup {Req.Test, :verify_on_exit!}

    setup do
      Req.Test.stub(@req_stub, fn conn ->
        body = %{
          "title" => "GH title",
          "body" => "GH body",
          "node_id" => "MDU6SXNzdWUxMjM",
          "number" => 1,
          "labels" => []
        }

        conn
        |> Plug.Conn.put_resp_header("etag", "\"etag-test\"")
        |> Req.Test.json(body)
      end)

      previous = Application.get_env(:kiln, :inbox_github_import_opts)

      Application.put_env(:kiln, :inbox_github_import_opts,
        req_options: [plug: {Req.Test, @req_stub}]
      )

      on_exit(fn ->
        if previous == nil do
          Application.delete_env(:kiln, :inbox_github_import_opts)
        else
          Application.put_env(:kiln, :inbox_github_import_opts, previous)
        end
      end)

      :ok
    end

    test "import from slug adds row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/inbox")

      view
      |> form("#inbox-github-form", github: %{ref: "octocat/Hello-World#1"})
      |> render_submit()

      html = render(view)
      assert html =~ "GH title"
    end
  end
end
