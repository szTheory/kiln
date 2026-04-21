defmodule KilnWeb.Plugs.OnboardingGate do
  @moduledoc """
  BLOCK-04 — redirects browser traffic to `/onboarding` until
  `Kiln.OperatorReadiness.ready?/0` is true (D-807).
  """

  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if Kiln.OperatorReadiness.ready?() or allowed_path?(conn.request_path) do
      conn
    else
      conn
      |> put_flash(:error, "Complete setup before starting a run")
      |> redirect(to: "/onboarding")
      |> halt()
    end
  end

  defp allowed_path?(<<"/ops", _::binary>>), do: true
  defp allowed_path?("/onboarding"), do: true
  defp allowed_path?("/health"), do: true

  defp allowed_path?(path) do
    String.starts_with?(path, "/assets") or
      String.starts_with?(path, "/fonts") or
      String.starts_with?(path, "/images") or
      path in ["/favicon.ico", "/robots.txt"] or
      String.starts_with?(path, "/live")
  end
end
