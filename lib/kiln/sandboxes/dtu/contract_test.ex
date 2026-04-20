defmodule Kiln.Sandboxes.DTU.ContractTest do
  @moduledoc """
  Weekly DTU contract drift check scaffold.

  Phase 3 only registers the worker surface on the `:dtu` queue. Phase 6
  will schedule it and compare the pinned contract against GitHub's live
  OpenAPI description.
  """

  use Kiln.Oban.BaseWorker, queue: :dtu, max_attempts: 1

  @impl Oban.Worker
  def perform(_job), do: :ok
end
