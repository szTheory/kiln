defmodule Kiln.Repo.Migrations.InstallPgUuidv7 do
  @moduledoc """
  Installs the `pg_uuidv7` Postgres extension (D-06, D-52).

  The `ghcr.io/fboulnois/pg_uuidv7:1.7.0` image (see `compose.yaml`) ships with
  the extension pre-built; this migration enables it in the current database so
  the `uuid_generate_v7()` function becomes available as the default PK
  generator for `audit_events` (and later `external_operations`).

  Migrate to native `uuidv7()` when the project moves to Postgres 18 (D-52).
  """

  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_uuidv7")
  end

  def down do
    execute("DROP EXTENSION IF EXISTS pg_uuidv7")
  end
end
