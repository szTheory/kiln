defmodule KilnWeb.SigraStubControllers do
  @moduledoc """
  Phase 36-01 wiring stubs.

  The Sigra-backed operator-auth phase (commit 89c8f26) shipped HTML
  templates and `redirect(to: ~p"/users/...")` calls for routes that
  were never wired into the router. Dev mode tolerates the dangling
  references as warnings; CI's `--warnings-as-errors` does not.

  These stubs exist solely to give the router compile-targets so
  `mix compile --warnings-as-errors` passes. Every action halts with
  HTTP 501 and a TODO message — no real behaviour. Replacement is
  tracked as a 36-01 followup.
  """
end

defmodule KilnWeb.RegistrationController do
  use KilnWeb, :controller

  @stub_msg "TODO 36-01 followup: RegistrationController not wired"

  def new(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def create(conn, _params), do: send_resp(conn, 501, @stub_msg)
end

defmodule KilnWeb.MFASettingsController do
  use KilnWeb, :controller

  @stub_msg "TODO 36-01 followup: MFASettingsController not wired"

  def show(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def disable(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def enroll(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def confirm(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def complete(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def regenerate(conn, _params), do: send_resp(conn, 501, @stub_msg)
  def revoke_trust(conn, _params), do: send_resp(conn, 501, @stub_msg)
end

defmodule KilnWeb.SettingsController do
  use KilnWeb, :controller

  @stub_msg "TODO 36-01 followup: SettingsController not wired"

  def show(conn, _params), do: send_resp(conn, 501, @stub_msg)
end

defmodule KilnWeb.ReactivationController do
  use KilnWeb, :controller

  @stub_msg "TODO 36-01 followup: ReactivationController not wired"

  def new(conn, _params), do: send_resp(conn, 501, @stub_msg)
end
