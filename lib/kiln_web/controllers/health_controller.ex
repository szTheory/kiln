defmodule KilnWeb.HealthController do
  @moduledoc """
  P1 Plan 06 ships the real implementation via Kiln.HealthPlug mounted
  BEFORE Plug.Logger in Endpoint. This controller-based stub exists so
  /health returns something during the Plan 01..05 window.
  """
  use KilnWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "pending", note: "Plan 06 ships real Kiln.HealthPlug"})
  end
end
