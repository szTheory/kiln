defmodule KilnWeb.Gettext do
  @moduledoc """
  Internationalization backend for the web layer.
  """

  use Gettext.Backend, otp_app: :kiln
end
