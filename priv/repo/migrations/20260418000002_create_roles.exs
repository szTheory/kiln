defmodule Kiln.Repo.Migrations.CreateRoles do
  @moduledoc """
  Creates the two-role Postgres access model (D-48).

    * `kiln_owner` — owns tables, runs migrations, has DDL rights. Migrations
      run under `KILN_DB_ROLE=kiln_owner mix ecto.migrate`.
    * `kiln_app` — runtime role. Connects via Ecto Repo. Has full DML on
      non-audit tables; on `audit_events` it gets only INSERT + SELECT
      (D-12 Layer 1; granted per-migration when the table is created).

  The connecting superuser also gets membership in both roles so test
  sessions can `SET LOCAL ROLE kiln_app` / `SET LOCAL ROLE kiln_owner`
  without re-authenticating (see `Kiln.AuditLedgerCase`).

  The `DO $$ … $$` block makes this idempotent: a repeat run (after a failed
  migration or a manual `mix ecto.rollback` followed by `mix ecto.migrate`)
  will not error out on duplicate role names.
  """

  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kiln_owner') THEN
        CREATE ROLE kiln_owner WITH LOGIN PASSWORD 'kiln_dev_owner' CREATEDB;
      END IF;

      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kiln_app') THEN
        CREATE ROLE kiln_app WITH LOGIN PASSWORD 'kiln_dev_app' NOCREATEDB;
      END IF;
    END
    $$ LANGUAGE plpgsql;
    """)

    # current_database() keeps the GRANT portable across kiln_dev / kiln_test
    # (and any future partitioned test DB like kiln_test1, kiln_test2 from
    # MIX_TEST_PARTITION).
    execute("""
    DO $$
    DECLARE
      db TEXT := current_database();
    BEGIN
      EXECUTE format('GRANT CONNECT ON DATABASE %I TO kiln_owner, kiln_app', db);
      -- kiln_owner needs CREATE ON DATABASE to install trusted extensions (e.g. citext)
      -- when migrations run under KILN_DB_ROLE=kiln_owner (Postgres 13+ trusted extension rule)
      EXECUTE format('GRANT CREATE ON DATABASE %I TO kiln_owner', db);
    END
    $$ LANGUAGE plpgsql;
    """)

    execute("GRANT USAGE ON SCHEMA public TO kiln_owner, kiln_app")
    # Only kiln_owner may CREATE new objects (new tables/types/functions).
    # kiln_app cannot run DDL.
    execute("GRANT CREATE ON SCHEMA public TO kiln_owner")
    # kiln_owner needs to read/write schema_migrations so KILN_DB_ROLE=kiln_owner
    # mix ecto.migrate works on subsequent boots (Ecto creates this table as the
    # connecting superuser before any migration runs).
    execute("GRANT SELECT, INSERT, UPDATE ON TABLE schema_migrations TO kiln_owner")

    # The connecting superuser (default 'postgres' in dev/test) needs
    # membership in the kiln_* roles so test sessions can SET LOCAL ROLE
    # without a separate connection. In prod this is not granted — prod
    # migrations run as kiln_owner and runtime as kiln_app, never as a
    # shared superuser that holds both.
    execute("""
    DO $$
    DECLARE
      connecting_role TEXT := current_user;
    BEGIN
      IF connecting_role <> 'kiln_owner' THEN
        EXECUTE format('GRANT kiln_owner TO %I', connecting_role);
      END IF;
      IF connecting_role <> 'kiln_app' THEN
        EXECUTE format('GRANT kiln_app TO %I', connecting_role);
      END IF;
    END
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
    execute("""
    DO $$
    DECLARE
      db TEXT := current_database();
    BEGIN
      EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM kiln_owner, kiln_app', db);
      EXECUTE format('REVOKE CREATE ON DATABASE %I FROM kiln_owner', db);
    END
    $$ LANGUAGE plpgsql;
    """)

    execute("REVOKE SELECT, INSERT, UPDATE ON TABLE schema_migrations FROM kiln_owner")

    execute("DROP ROLE IF EXISTS kiln_app")
    execute("DROP ROLE IF EXISTS kiln_owner")
  end
end
