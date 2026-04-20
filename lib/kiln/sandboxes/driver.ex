defmodule Kiln.Sandboxes.Driver do
  @moduledoc """
  Behaviour for sandbox drivers (D-115).

  Phase 3 ships exactly one implementation:
  `Kiln.Sandboxes.DockerDriver`, which wraps `docker run` via MuonTrap.
  Future runtime backends can sit behind this behaviour without
  changing call sites.
  """

  alias Kiln.Sandboxes.ContainerSpec

  @type run_result :: %{
          required(:container_id) => String.t(),
          required(:exit_code) => integer(),
          optional(:oom_killed) => boolean(),
          optional(:started_at) => String.t() | nil,
          optional(:finished_at) => String.t() | nil
        }

  @callback run_stage(ContainerSpec.t()) :: {:ok, run_result()} | {:error, term()}
  @callback kill(container_id :: String.t()) :: :ok | {:error, term()}
  @callback list_orphans(boot_epoch :: integer()) :: [String.t()]
end
