defmodule Mix.Tasks.Kiln.Dtu.RegenContract do
  @moduledoc """
  Refresh the pinned DTU GitHub OpenAPI snapshot.

  Phase 3 ships the task surface and operator instructions. Phase 6
  fills in the download, bundle, and dereference pipeline.
  """

  use Mix.Task

  @shortdoc "Refresh priv/dtu/contracts/github pinned OpenAPI snapshot"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("kiln.dtu.regen_contract: Phase 3 stub")
    Mix.shell().info("Manual workflow:")
    Mix.shell().info("  1. Download github/rest-api-description")
    Mix.shell().info("  2. Bundle and dereference the OpenAPI document")
    Mix.shell().info("  3. Save it under priv/dtu/contracts/github/")
  end
end
