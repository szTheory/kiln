defmodule KilnDtu.Router do
  @moduledoc """
  DTU router serving a small GitHub REST subset for sandboxed stage runs.

  Unknown endpoints fail loudly with a structured `501` response so the
  sandbox never mistakes an unimplemented mock for a real success path.
  """

  use Plug.Router

  alias KilnDtu.Validation

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  get "/healthz" do
    json(conn, 200, %{
      status: "ok",
      contract_version: Validation.contract_version()
    })
  end

  forward "/repos/:owner/:repo/issues", to: KilnDtu.Handlers.GitHub.Issues
  forward "/repos/:owner/:repo/pulls", to: KilnDtu.Handlers.GitHub.Pulls
  forward "/repos/:owner/:repo/check-runs", to: KilnDtu.Handlers.GitHub.Checks
  forward "/repos/:owner/:repo/contents", to: KilnDtu.Handlers.GitHub.Contents
  forward "/repos/:owner/:repo/branches", to: KilnDtu.Handlers.GitHub.Branches
  forward "/repos/:owner/:repo/tags", to: KilnDtu.Handlers.GitHub.Tags

  match _ do
    json(conn, 501, %{
      error: "endpoint_not_implemented",
      endpoint: conn.request_path,
      method: conn.method,
      pinned_snapshot: Validation.contract_version()
    })
  end

  def json(conn, status, body) do
    payload = Jason.encode!(body)
    :ok = Validation.validate(conn.method, conn.request_path, status, body)

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, payload)
  end
end
