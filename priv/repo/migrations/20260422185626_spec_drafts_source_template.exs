defmodule Kiln.Repo.Migrations.SpecDraftsSourceTemplate do
  @moduledoc """
  Phase 17 — add `template` to `spec_drafts.source` for built-in template inbox rows.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (source IN ('freeform', 'markdown_import', 'github_issue', 'run_follow_up', 'template'))
    """)
  end

  def down do
    execute("ALTER TABLE spec_drafts DROP CONSTRAINT IF EXISTS spec_drafts_source_values")

    execute("""
    ALTER TABLE spec_drafts
      ADD CONSTRAINT spec_drafts_source_values
      CHECK (source IN ('freeform', 'markdown_import', 'github_issue', 'run_follow_up'))
    """)
  end
end
