defmodule Kiln.Sandboxes.DTU.CallbackRouterTest do
  use Kiln.AuditLedgerCase, async: false

  import Ecto.Query
  import Plug.Conn
  import Plug.Test

  alias Kiln.Audit.Event
  alias Kiln.Sandboxes.DTU.CallbackRouter

  @opts CallbackRouter.init([])

  test "POST /internal/dtu/event records an external_op_completed audit event" do
    payload = %{
      "op_kind" => "dtu_callback",
      "idempotency_key" => "run:test:callback",
      "result_summary" => "callback received"
    }

    conn =
      conn(:post, "/internal/dtu/event", Jason.encode!(payload))
      |> put_req_header("content-type", "application/json")
      |> CallbackRouter.call(@opts)

    assert conn.status == 204

    event =
      Repo.one!(
        from e in Event,
          where: e.event_kind == :external_op_completed,
          order_by: [desc: e.inserted_at],
          limit: 1
      )

    assert event.payload == payload
  end
end
