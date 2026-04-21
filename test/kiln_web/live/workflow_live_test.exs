defmodule KilnWeb.WorkflowLiveTest do
  use KilnWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kiln.Workflows
  alias Kiln.Workflows.Loader

  test "index shows Snapshots label and empty copy when no rows", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/workflows")
    assert render(view) =~ "Snapshots"
    assert render(view) =~ "No workflows loaded"
  end

  test "index lists persisted snapshots (read-only, no yaml submit)", %{conn: conn} do
    path = Application.app_dir(:kiln, "priv/workflows/elixir_phoenix_feature.yaml")
    {:ok, cg} = Loader.load(path)
    yaml = File.read!(path)

    assert {:ok, _} =
             Workflows.record_snapshot(%{
               workflow_id: cg.id,
               version: cg.version,
               compiled_checksum: cg.checksum,
               yaml: yaml
             })

    {:ok, view, _html} = live(conn, ~p"/workflows")
    html = render(view)
    assert html =~ "Snapshots"
    assert html =~ cg.id
    refute html =~ ~s(phx-submit=")
  end
end
