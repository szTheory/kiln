defmodule Kiln.Repo.Migrations.InstallOban do
  @moduledoc """
  Installs the Oban job-queue tables at a pinned migration version (D-49).

  Pinning a specific version instead of `Oban.Migration.up(version: :current)`
  means a future `mix deps.update oban` that ships a new migration step
  cannot silently change table shape on us — instead a deliberate follow-up
  migration (`UpgradeObanToVN`) is required, which is legible in git history
  and reviewable in code review.

  As of Oban 2.21.1 (pinned in `mix.exs`, verified via
  `deps/oban/lib/oban/migrations/postgres.ex` `@current_version 14`), the
  current migration version is **14**. Plan 01-01's SUMMARY cited `13`
  based on an early reading of `Oban.Migration`'s moduledoc example,
  but the actual `@current_version` in the shipped code is `14`
  (migrations v01..v14 present under
  `deps/oban/lib/oban/migrations/postgres/`).
  """

  use Ecto.Migration

  @oban_migration_version 14

  def up do
    Oban.Migration.up(version: @oban_migration_version)
  end

  def down do
    Oban.Migration.down(version: @oban_migration_version)
  end
end
