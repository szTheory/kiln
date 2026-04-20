defmodule KilnDtu.Chaos do
  @moduledoc """
  Closed chaos-mode injector for the DTU.

  Phase 3 only supports the two modes needed for adaptive-routing and
  outage handling tests. Unknown values are rejected with a structured
  `400` response.
  """

  import Plug.Conn

  @supported ~w(rate_limit_429 outage_503)

  @spec maybe_inject(Plug.Conn.t()) ::
          :pass | {:short_circuit, Plug.Conn.t()}
  def maybe_inject(conn) do
    case get_req_header(conn, "x-dtu-chaos") do
      [] ->
        :pass

      ["rate_limit_429"] ->
        conn =
          conn
          |> put_resp_header("retry-after", "60")
          |> put_resp_content_type("application/json")
          |> send_resp(
            429,
            Jason.encode!(%{
              message: "API rate limit exceeded",
              documentation_url:
                "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
            })
          )

        {:short_circuit, conn}

      ["outage_503"] ->
        conn =
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(503, Jason.encode!(%{message: "Service Unavailable"}))

        {:short_circuit, conn}

      [other] ->
        conn =
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            400,
            Jason.encode!(%{
              error: "unsupported_chaos_mode",
              received: other,
              supported: @supported
            })
          )

        {:short_circuit, conn}
    end
  end
end
