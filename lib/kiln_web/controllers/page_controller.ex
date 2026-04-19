defmodule KilnWeb.PageController do
  use KilnWeb, :controller

  def redirect_to_ops(conn, _params) do
    redirect(conn, to: "/ops/dashboard")
  end
end
