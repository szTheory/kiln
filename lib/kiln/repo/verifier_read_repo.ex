defmodule Kiln.Repo.VerifierReadRepo do
  @moduledoc """
  Narrow-privilege Ecto repo for **verifier-only** reads (SPEC-04).

  Connects as Postgres role `kiln_verifier`, which has `SELECT` on
  `holdout_scenarios` only — never use this for general application queries.

  **Configuration:** set `DATABASE_VERIFIER_URL` in production (see
  `config/runtime.exs`). Tests configure `Kiln.Repo.VerifierReadRepo` in
  `config/test.exs` and start the repo under `start_supervised!/1` with
  `Ecto.Adapters.SQL.Sandbox.mode/2` shared with `Kiln.Repo`.
  """

  use Ecto.Repo,
    otp_app: :kiln,
    adapter: Ecto.Adapters.Postgres
end
