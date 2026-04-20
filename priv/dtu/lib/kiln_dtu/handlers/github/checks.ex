defmodule KilnDtu.Handlers.GitHub.Checks do
  use Plug.Router

  alias KilnDtu.{Chaos, Router}

  plug :match
  plug :dispatch

  get "/" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        Router.json(conn, 200, %{
          total_count: 1,
          check_runs: [
            %{
              id: 1,
              name: "ci",
              status: "completed",
              conclusion: "success"
            }
          ]
        })
    end
  end

  get "/:number" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        Router.json(conn, 200, %{
          id: String.to_integer(conn.params["number"]),
          name: "ci",
          status: "completed",
          conclusion: "success"
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
