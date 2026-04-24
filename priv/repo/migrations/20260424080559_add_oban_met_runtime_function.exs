defmodule Kiln.Repo.Migrations.AddObanMetRuntimeFunction do
  @moduledoc """
  Pre-creates Oban Met's estimate helper so the restricted runtime role
  doesn't need to auto-migrate database functions at boot.
  """

  use Ecto.Migration

  def up do
    # Historical databases may already have this function owned by the
    # connecting role (`kiln`) from Oban Met's runtime auto-migration.
    # Resetting the session role lets that owner replace the function once,
    # after which ownership is transferred back to kiln_owner.
    execute("RESET ROLE")
    Oban.Met.Migration.up()
    execute("ALTER FUNCTION public.oban_count_estimate(text, text) OWNER TO kiln_owner")
    execute("GRANT EXECUTE ON FUNCTION public.oban_count_estimate(text, text) TO kiln_app")
  end

  def down do
    execute("REVOKE EXECUTE ON FUNCTION public.oban_count_estimate(text, text) FROM kiln_app")
    execute("RESET ROLE")
    Oban.Met.Migration.down()
  end
end
