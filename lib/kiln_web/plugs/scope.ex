defmodule KilnWeb.Plugs.Scope do
  @moduledoc "Attaches %Kiln.Scope{} to conn.assigns.current_scope (D-03)."
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    assign(conn, :current_scope, Kiln.Scope.local())
  end
end

defmodule KilnWeb.LiveScope do
  @moduledoc "on_mount callback attaching Kiln.Scope to LiveView socket."
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :current_scope, Kiln.Scope.local())}
  end
end
