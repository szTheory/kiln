defmodule Kiln.Repo.Migrations.GrantObanRuntimePrivileges do
  @moduledoc """
  Repairs runtime-role access to the Oban relations created by the pinned
  upstream migration.

  Historical repositories may already have `oban_jobs` and `oban_peers`
  created under the connecting user (for example `kiln`) because
  `20260418000005_install_oban.exs` delegated all DDL to `Oban.Migration`
  without re-applying Kiln's owner/grant policy afterward. Runtime boot uses
  `kiln_app`, and the default Oban peer writes to `oban_peers` while queue
  operation reads and mutates `oban_jobs`, so the missing grants can break app
  startup before `/health` goes green.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE oban_jobs OWNER TO kiln_owner")
    execute("ALTER TABLE oban_peers OWNER TO kiln_owner")
    execute("ALTER SEQUENCE oban_jobs_id_seq OWNER TO kiln_owner")

    execute("GRANT SELECT, INSERT, UPDATE, DELETE ON oban_jobs TO kiln_app")
    execute("GRANT USAGE, SELECT ON SEQUENCE oban_jobs_id_seq TO kiln_app")
    execute("GRANT SELECT, INSERT, UPDATE, DELETE ON oban_peers TO kiln_app")
  end

  def down do
    raise "Irreversible migration: historical Oban ownership/grant repair"
  end
end
