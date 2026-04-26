defmodule KilnWeb.DiagnosticsZipControllerTest do
  use KilnWeb.ConnCase, async: false

  alias Kiln.Factory.Run, as: RunFactory
  alias Kiln.OperatorReadiness

  setup do
    assert {:ok, _} = OperatorReadiness.mark_step(:anthropic, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:github, true)
    assert {:ok, _} = OperatorReadiness.mark_step(:docker, true)

    :ok
  end

  test "GET bundle returns zip bytes", %{conn: conn} do
    run = RunFactory.insert(:run, workflow_id: "wf_diag_zip")

    conn = get(conn, ~p"/runs/#{run.id}/diagnostics/bundle.zip")

    assert conn.status == 200
    assert hd(get_resp_header(conn, "content-type")) =~ "application/zip"
    assert byte_size(conn.resp_body) > 32
  end
end
