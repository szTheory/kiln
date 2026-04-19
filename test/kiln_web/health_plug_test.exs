defmodule Kiln.HealthPlugTest do
  @moduledoc """
  Behaviors 26, 27, 28 from 01-VALIDATION.md.

  26 — `/health` returns the D-31 JSON shape with all four dependency
       fields on a healthy boot.
  27 — Content-Type is `application/json`.
  28 — `Kiln.HealthPlug` is declared BEFORE `Plug.Logger` in
       `KilnWeb.Endpoint` so probes don't pollute the request log.
  """
  use KilnWeb.ConnCase

  describe "GET /health (behaviors 26, 27)" do
    test "returns 200 with the D-31 JSON shape — status/postgres/oban/contexts/version", %{
      conn: conn
    } do
      conn = get(conn, "/health")

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["status"] in ["ok", "degraded"],
             "status must be ok or degraded on a healthy test boot, got #{inspect(body["status"])}"

      assert body["postgres"] in ["up", "down"]
      assert body["oban"] in ["up", "down"]
      assert is_integer(body["contexts"])

      assert body["contexts"] == 12,
             "D-42 locks the 12-context count (ARCHITECTURE.md §4); got #{body["contexts"]}"

      assert is_binary(body["version"])

      # D-31 says the shape is LOCKED for Phase 7 UI-07 — guard against
      # accidental key additions that would drift the contract.
      expected_keys = MapSet.new(["status", "postgres", "oban", "contexts", "version"])
      actual_keys = body |> Map.keys() |> MapSet.new()

      assert MapSet.equal?(expected_keys, actual_keys),
             "D-31 JSON shape drifted: expected #{inspect(expected_keys)}, got #{inspect(actual_keys)}"
    end

    test "Content-Type is application/json (behavior 27)", %{conn: conn} do
      conn = get(conn, "/health")
      [content_type | _] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/json"
    end

    test "postgres==up AND oban==up implies status==ok on a healthy test boot", %{conn: conn} do
      conn = get(conn, "/health")
      body = Jason.decode!(conn.resp_body)

      if body["postgres"] == "up" and body["oban"] == "up" do
        assert body["status"] == "ok"
      end
    end
  end

  describe "Kiln.HealthPlug.status/0 direct call" do
    test "returns the same shape as the HTTP endpoint (Phase 7 UI-07 factory-header consumer)" do
      payload = Kiln.HealthPlug.status()
      assert is_map(payload)
      assert payload["contexts"] == 12
      assert payload["status"] in ["ok", "degraded", "down"]
    end
  end

  describe "HealthPlug is mounted before Plug.Logger/Plug.Telemetry (behavior 28)" do
    # Reads the compiled Endpoint source to prove the ordering — this is
    # both a documentation assertion (greppable) and a regression guard
    # against a future refactor reordering plugs.
    test "Kiln.HealthPlug appears before Plug.Telemetry in lib/kiln_web/endpoint.ex" do
      source = File.read!("lib/kiln_web/endpoint.ex")

      {health_pos, _} = :binary.match(source, "Kiln.HealthPlug")
      {telemetry_pos, _} = :binary.match(source, "Plug.Telemetry")

      assert health_pos < telemetry_pos,
             "Kiln.HealthPlug (byte #{health_pos}) must be declared before " <>
               "Plug.Telemetry (byte #{telemetry_pos}) per D-31 — probes must not " <>
               "pollute request telemetry."
    end
  end
end
