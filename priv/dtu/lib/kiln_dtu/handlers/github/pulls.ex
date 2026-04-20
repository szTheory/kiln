defmodule KilnDtu.Handlers.GitHub.Pulls do
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
            state: "open",
            title: "DTU pull request",
            draft: false,
            merged: false
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
          state: "open",
          title: "DTU pull request",
          draft: false,
          merged: false
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
