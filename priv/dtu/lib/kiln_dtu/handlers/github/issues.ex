defmodule KilnDtu.Handlers.GitHub.Issues do
  use Plug.Router

  alias KilnDtu.{Chaos, Router}

  plug :match
  plug :dispatch

  get "/" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        Router.json(conn, 200, [
          %{
            id: 1,
            number: 1,
            title: "DTU issue",
            state: "open",
            body: "Stub issue payload",
            html_url: "https://github.com/#{conn.params["owner"]}/#{conn.params["repo"]}/issues/1"
          }
        ])
    end
  end

  get "/:number" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        Router.json(conn, 200, %{
          id: String.to_integer(conn.params["number"]),
          number: String.to_integer(conn.params["number"]),
          title: "DTU issue",
          state: "open",
          body: "Stub issue payload"
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
