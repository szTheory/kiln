defmodule Kiln.Sandboxes.DTU.CallbackRouter do
  @moduledoc """
  Best-effort host-loopback callback receiver for DTU request metadata.

  The DTU sidecar treats this as opportunistic telemetry. Its local JSONL
  log remains authoritative, so callback failures never block stage
  execution.
  """

  use Plug.Router

  alias Kiln.Audit

  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :match
  plug :dispatch

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    port = Keyword.get(opts, :port, callback_port())

    Supervisor.child_spec(
      {Bandit,
       plug: __MODULE__,
       scheme: :http,
       ip: {127, 0, 0, 1},
       port: port},
      id: __MODULE__
    )
  end

  post "/internal/dtu/event" do
    _ =
      Audit.append(%{
        event_kind: :external_op_completed,
        correlation_id: Ecto.UUID.generate(),
        payload: conn.body_params
      })

    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, "")
  end

  defp callback_port do
    default_port =
      case Application.get_env(:kiln, :env, :prod) do
        :test -> 0
        _ -> 4011
      end

    Application.get_env(:kiln, __MODULE__, [])
    |> Keyword.get(:port, default_port)
  end
end
