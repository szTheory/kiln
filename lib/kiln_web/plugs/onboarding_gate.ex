defmodule KilnWeb.Plugs.OnboardingGate do
  @moduledoc """
  Legacy onboarding gate.

  Kiln now favors demo-first exploration plus per-page disconnected states over
  hard navigation redirects, so this plug intentionally allows browser traffic
  through unchanged.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts), do: conn
end
