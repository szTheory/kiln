defmodule KilnDtu.Handlers.GitHub.Tags do
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
            name: "v0.1.0",
            commit: %{sha: "stub-tag-sha"}
          }
        ])
    end
  end

  get "/:name" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        Router.json(conn, 200, %{
          name: conn.params["name"],
          commit: %{sha: "stub-tag-sha"}
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
