defmodule Kiln.Repo do
  use Ecto.Repo,
    otp_app: :kiln,
    adapter: Ecto.Adapters.Postgres
end
