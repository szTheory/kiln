defmodule KilnDtu.Handlers.GitHub.Branches do
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
            name: "main",
            protected: false,
            commit: %{sha: "stub-branch-sha"}
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
          protected: false,
          commit: %{sha: "stub-branch-sha"}
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
