defmodule KilnWeb.AttachEntryLiveTest do
  use KilnWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "mounts the attach intake surface with stable ids and untouched guidance", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/attach")

    assert has_element?(view, "#attach-entry-root")
    assert has_element?(view, "#attach-entry-hero")
    assert has_element?(view, "#attach-supported-sources")
    assert has_element?(view, "#attach-source-form")
    assert has_element?(view, "#attach-source-input")
    assert has_element?(view, "#attach-source-submit")
    assert has_element?(view, "#attach-source-untouched")
    assert has_element?(view, "#attach-next-step")
    assert has_element?(view, "#attach-back-to-templates")
    refute has_element?(view, "#attach-source-resolved")
    refute has_element?(view, "#attach-source-error")
    assert html =~ "Supports a local path, an existing clone, or a GitHub URL."
  end

  test "submitting a valid local repo renders the resolved source state", %{conn: conn} do
    repo_root = make_git_repo!("kiln_attach_live_valid")
    {:ok, view, _html} = live(conn, ~p"/attach")

    html =
      view
      |> form("#attach-source-form", attach_source: %{source: repo_root})
      |> render_submit()

    assert html =~ "Source ready for workspace hydration"
    assert html =~ "Local path"
    assert html =~ repo_root
    assert has_element?(view, "#attach-source-resolved")
    refute has_element?(view, "#attach-source-error")
  end

  test "submitting an unsupported source renders typed remediation feedback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/attach")

    html =
      view
      |> form("#attach-source-form", attach_source: %{source: "https://gitlab.com/example/kiln"})
      |> render_submit()

    assert html =~ "Only local paths and GitHub URLs are supported right now."
    assert html =~ "Use a local repo path, an existing clone, or a GitHub URL."
    assert has_element?(view, "#attach-source-error")
    refute has_element?(view, "#attach-source-resolved")
    refute html =~ "template_id"
    refute html =~ "return_to"
    refute html =~ "Start run"
    refute html =~ "Create draft PR"
  end

  defp make_git_repo!(name) do
    repo_root = Path.join(System.tmp_dir!(), "#{name}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(repo_root)

    {_, 0} = System.cmd("git", ["init", "--quiet", repo_root])
    repo_root
  end
end
