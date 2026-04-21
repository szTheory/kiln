defmodule Kiln.Repo.Migrations.HoldoutPrivileges do
  @moduledoc """
  SPEC-04: `kiln_app` must not read `holdout_scenarios`; `kiln_verifier` gets
  narrow `SELECT` only for the verifier worker path.

  Runtime env (documented in `config/runtime.exs`): `DATABASE_VERIFIER_URL`
  optional prod URL; dev/test configure `Kiln.Repo.VerifierReadRepo` in env files.
  """

  use Ecto.Migration

  def change do
    execute(
      """
      DO $$
      DECLARE
        connecting_role TEXT := current_user;
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kiln_verifier') THEN
          CREATE ROLE kiln_verifier WITH LOGIN PASSWORD 'kiln_dev_verifier' NOCREATEDB;
        END IF;

        IF connecting_role <> 'kiln_verifier' THEN
          EXECUTE format('GRANT kiln_verifier TO %I', connecting_role);
        END IF;
      END
      $$ LANGUAGE plpgsql;
      """,
      """
      DO $$
      BEGIN
        DROP ROLE IF EXISTS kiln_verifier;
      END
      $$ LANGUAGE plpgsql;
      """
    )

    execute("REVOKE ALL ON TABLE holdout_scenarios FROM PUBLIC", "")

    execute(
      "REVOKE ALL ON TABLE holdout_scenarios FROM kiln_app",
      "GRANT SELECT ON TABLE holdout_scenarios TO kiln_app"
    )

    execute(
      "GRANT SELECT ON TABLE holdout_scenarios TO kiln_verifier",
      "REVOKE SELECT ON TABLE holdout_scenarios FROM kiln_verifier"
    )
  end
end
