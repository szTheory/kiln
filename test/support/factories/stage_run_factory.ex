defmodule Kiln.Factory.StageRun do
  @moduledoc """
  ex_machina factory for `Kiln.Stages.StageRun` rows (Plan 02-02).

  Replaces the SHELL factory shipped in Plan 02-00.

  Default attrs:
    * `run_id` — `nil`; CALLER MUST SUPPLY. Every stage_run has a
      non-nullable FK to `runs` with `on_delete: :restrict`. Build a
      parent run first and pass its id:

          run = insert(:run)
          insert(:stage_run, run_id: run.id)

      A default auto-insert of a parent run would hide the FK
      dependency and produce surprise orphans when tests use
      `build/1` without persisting.
    * `workflow_stage_id` — auto-sequenced (`stage_0`, `stage_1`, ...)
      for uniqueness per (run_id, workflow_stage_id, attempt)
    * `kind` — `:planning`
    * `agent_role` — `:planner`
    * `attempt` — 1
    * `state` — `:pending`
    * `timeout_seconds` — 300 (matches D-58 retry_policy defaults)
    * `sandbox` — `:readonly` (default for planning stage)
    * `tokens_used` — 0
    * `cost_usd` — `Decimal.new("0.0")`
  """

  use ExMachina.Ecto, repo: Kiln.Repo

  @doc """
  Build a `Kiln.Stages.StageRun` struct with sensible defaults. The
  `run_id` field is intentionally `nil` — callers MUST supply a valid
  parent run id (see moduledoc).
  """
  @spec stage_run_factory() :: Kiln.Stages.StageRun.t()
  def stage_run_factory do
    %Kiln.Stages.StageRun{
      # Caller MUST supply run_id (FK on_delete: :restrict). See moduledoc.
      run_id: nil,
      workflow_stage_id: sequence(:workflow_stage_id, &"stage_#{&1}"),
      kind: :planning,
      agent_role: :planner,
      attempt: 1,
      state: :pending,
      timeout_seconds: 300,
      sandbox: :readonly,
      tokens_used: 0,
      cost_usd: Decimal.new("0.0")
    }
  end
end
