defmodule KilnWeb.DiagnosticsZipControllerTest do
  use KilnWeb.ConnCase, async: true

  alias Kiln.Factory.Run, as: RunFactory

  test "GET bundle returns zip bytes", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_diag_zip")

    conn = get(conn, ~p"/runs/#{run.id}/diagnostics/bundle.zip")

    assert conn.status == 200
    assert hd(get_resp_header(conn, "content-type")) =~ "application/zip"
    assert byte_size(conn.resp_body) > 32
  end
end
