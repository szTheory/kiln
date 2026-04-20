defmodule KilnDtu.Handlers.GitHub.Contents do
  use Plug.Router

  alias KilnDtu.{Chaos, Router}

  plug :match
  plug :dispatch

  get "/*path" do
    case Chaos.maybe_inject(conn) do
      {:short_circuit, conn} ->
        conn

      :pass ->
        full_path = Enum.join(conn.params["path"] || [], "/")

        Router.json(conn, 200, %{
          type: "file",
          name: Path.basename(full_path),
          path: full_path,
          size: 18,
          sha: "stubbed-sha",
          encoding: "base64",
          content: Base.encode64("stub content\n")
        })
    end
  end

  match _ do
    Router.json(conn, 501, %{error: "endpoint_not_implemented", endpoint: conn.request_path})
  end
end
