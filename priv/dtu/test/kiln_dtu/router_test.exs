defmodule KilnDtu.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  alias KilnDtu.Router

  @opts Router.init([])

  test "GET /healthz returns 200 with status" do
    conn = conn(:get, "/healthz") |> Router.call(@opts)

    assert conn.status == 200
    assert Jason.decode!(conn.resp_body)["status"] == "ok"
  end

  test "unknown endpoint returns 501 with structured error body" do
    conn = conn(:get, "/totally/unknown") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 501
    assert body["error"] == "endpoint_not_implemented"
    assert body["endpoint"] == "/totally/unknown"
  end

  test "chaos rate_limit_429 returns 429 with Retry-After" do
    conn =
      conn(:get, "/repos/o/r/issues")
      |> put_req_header("x-dtu-chaos", "rate_limit_429")
      |> Router.call(@opts)

    assert conn.status == 429
    assert {"retry-after", "60"} in conn.resp_headers
  end

  test "chaos outage_503 returns 503" do
    conn =
      conn(:get, "/repos/o/r/issues")
      |> put_req_header("x-dtu-chaos", "outage_503")
      |> Router.call(@opts)

    assert conn.status == 503
  end

  test "chaos unsupported value returns 400 with enum list" do
    conn =
      conn(:get, "/repos/o/r/issues")
      |> put_req_header("x-dtu-chaos", "weird")
      |> Router.call(@opts)

    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert body["error"] == "unsupported_chaos_mode"
    assert "rate_limit_429" in body["supported"]
    assert "outage_503" in body["supported"]
  end
end
