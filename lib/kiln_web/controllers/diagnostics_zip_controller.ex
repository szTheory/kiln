defmodule KilnWeb.DiagnosticsZipController do
  @moduledoc """
  OPS-05 — serves a short-lived diagnostic zip built by `Kiln.Diagnostics.Snapshot`.
  """

  use KilnWeb, :controller

  alias Kiln.Diagnostics.Snapshot
  alias Kiln.Runs

  def bundle(conn, %{"run_id" => run_id}) do
    case Runs.get(run_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("not found")

      run ->
        case Snapshot.build_zip(run_id: run.id) do
          {:ok, path} ->
            data = File.read!(path)
            File.rm(path)

            filename = "kiln-diagnostics-#{String.slice(to_string(run.id), 0, 8)}.zip"

            conn
            |> put_resp_content_type("application/zip")
            |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
            |> send_resp(200, data)

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> text("bundle error: #{inspect(reason)}")
        end
    end
  end
end
