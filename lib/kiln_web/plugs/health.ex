defmodule Kiln.HealthPlug do
  @moduledoc """
  Health endpoint Plug. Mounted BEFORE `Plug.Logger` in
  `KilnWeb.Endpoint` (D-31) so health probes do NOT pollute the request
  log. Plug-at-endpoint (not a Router route) lets the probe short-circuit
  before the Phoenix router runs, keeping the Phase 7 factory-header
  liveness contract independent of router state.

  JSON shape (LOCKED per D-31 — Phase 7 UI-07 factory header reads this
  exact shape, do not change the keys without updating UI-07 plan):

      { "status":   "ok" | "degraded" | "down",
        "postgres": "up" | "down",
        "oban":     "up" | "down",
        "contexts": 12,
        "version":  "0.1.0" }

  Status semantics:
    * `"ok"`        — postgres up and oban up
    * `"degraded"`  — oban down but postgres up (factory can still read
      state, just can't enqueue work); returns HTTP 200 so load balancers
      don't flap
    * `"down"`      — postgres down; returns HTTP 503 (nothing useful
      can happen without the audit ledger)

  The 12-element contexts count is the single SSOT from
  `Kiln.BootChecks.context_count/0` (D-42) — we import rather than
  duplicate so a future context addition updates both endpoints.
  """

  @behaviour Plug
  import Plug.Conn

  alias Ecto.Adapters.SQL

  @version Mix.Project.config()[:version] || "0.0.0-unknown"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{request_path: "/health"} = conn, _opts) do
    payload = status()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(http_status_for(payload["status"]), Jason.encode!(payload))
    |> halt()
  end

  def call(conn, _opts), do: conn

  @typedoc "D-31 JSON-shape map. LOCKED for Phase 7 UI-07 factory header."
  @type health_payload :: %{
          required(String.t()) => String.t() | non_neg_integer()
        }

  @doc """
  Public so operators can evaluate the same JSON shape from IEx + so
  Phase 7's factory header can call it directly (avoids a loopback HTTP
  round-trip for a LiveView that lives in the same BEAM).
  """
  @spec status() :: health_payload()
  def status do
    pg = postgres_status()
    oban = oban_status()
    ctxs = Kiln.BootChecks.context_count()

    overall =
      cond do
        pg == "up" and oban == "up" -> "ok"
        pg == "down" -> "down"
        true -> "degraded"
      end

    %{
      "status" => overall,
      "postgres" => pg,
      "oban" => oban,
      "contexts" => ctxs,
      "version" => @version
    }
  end

  # 500ms timeout is deliberate — the /health endpoint should not block on
  # a wedged DB. If the pool is saturated or the connection is hung, we
  # want a fast "down" signal rather than a slow timeout that cascades
  # into request-queue backpressure.
  defp postgres_status do
    case SQL.query(Kiln.Repo, "SELECT 1", [], timeout: 500) do
      {:ok, _} -> "up"
      _ -> "down"
    end
  rescue
    _ -> "down"
  end

  # `Process.whereis(Oban)` returns the pid of Oban's root supervisor when
  # started. If it's not registered or not alive, Oban isn't serving — we
  # call that "down" even if the Oban application itself is loaded.
  defp oban_status do
    case Process.whereis(Oban) do
      pid when is_pid(pid) -> if Process.alive?(pid), do: "up", else: "down"
      _ -> "down"
    end
  end

  # `"degraded"` returns 200 so an upstream load-balancer sees the factory
  # as still "up" (HTTP-wise) — the status field encodes the nuance. Only
  # "down" (postgres missing) returns 503, because without the audit
  # ledger no invariant of the durability floor holds.
  defp http_status_for("ok"), do: 200
  defp http_status_for("degraded"), do: 200
  defp http_status_for("down"), do: 503
end
