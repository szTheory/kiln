defmodule Kiln.Repo.Migrations.InstallPgUuidv7 do
  @moduledoc """
  Installs the `pg_uuidv7` Postgres extension (D-06, D-52), with a pure-SQL
  fallback if the extension is unavailable.

  Preferred path: `CREATE EXTENSION IF NOT EXISTS pg_uuidv7`. The
  `ghcr.io/fboulnois/pg_uuidv7:1.7.0` image (see `compose.yaml`) ships with
  the extension binaries pre-built and this is a no-op GRANT on an already-
  installed extension.

  Fallback path: when the extension is not available (e.g. operator is
  blocked from running Kiln's compose and the active Postgres doesn't have
  the binary), we create a pure-SQL `uuid_generate_v7()` function using
  the kjmph gist approach. CONTEXT.md D-06 explicitly sanctions kjmph as
  the fallback and Phase 1's canonical references list the gist. Either
  path leaves the `uuid_generate_v7()` function callable so
  `priv/repo/migrations/20260418000003_create_audit_events.exs` can use
  it as the table's PK default.

  Migrate to native `uuidv7()` when the project moves to Postgres 18 (D-52).
  """

  use Ecto.Migration

  # Run outside Ecto's transaction so that a CREATE EXTENSION failure
  # doesn't abort the migration; we detect availability via pg_available_extensions
  # *before* attempting DDL.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    if extension_available?() do
      repo().query!("CREATE EXTENSION IF NOT EXISTS pg_uuidv7")
    else
      install_sql_fallback()
    end

    # Post-condition: uuid_generate_v7() must be callable. If neither the
    # extension nor the fallback succeeded, surface a loud error now
    # rather than failing on migration 3's INSERT default.
    repo().query!("SELECT uuid_generate_v7()")
  end

  def down do
    # Drop both, tolerating whichever was not installed.
    execute("DROP EXTENSION IF EXISTS pg_uuidv7")
    execute("DROP FUNCTION IF EXISTS uuid_generate_v7()")
  end

  defp extension_available? do
    %{rows: [[count]]} =
      repo().query!("SELECT count(*) FROM pg_available_extensions WHERE name = 'pg_uuidv7'")

    count > 0
  end

  # kjmph pure-SQL UUID v7 (CONTEXT.md canonical refs). Generates a
  # time-sortable UUID using `clock_timestamp()` for the 48-bit unix_ts_ms
  # prefix + 74 bits of randomness; matches the `uuid_generate_v7()` name
  # used by migration 3 so downstream SQL doesn't have to branch.
  defp install_sql_fallback do
    repo().query!("""
    CREATE OR REPLACE FUNCTION uuid_generate_v7()
    RETURNS uuid
    AS $$
    BEGIN
      RETURN encode(
        set_bit(
          set_bit(
            overlay(
              uuid_send(gen_random_uuid())
              PLACING substring(int8send(floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint)
                                FROM 3)
              FROM 1 FOR 6
            ),
            52, 1
          ),
          53, 1
        ),
        'hex'
      )::uuid;
    END
    $$ LANGUAGE plpgsql VOLATILE;
    """)
  end
end
