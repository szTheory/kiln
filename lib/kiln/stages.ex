defmodule Kiln.Stages do
  @moduledoc """
  Public API for the stages context. Owns the `stage_runs` table
  (Plan 02-02) and, via `Kiln.Stages.ContractRegistry` (Plan 02-01),
  the per-kind input-contract validation invoked by
  `Kiln.Stages.StageWorker` (Plan 08 / Phase 3) at stage-start
  (D-76).

  This module ships the narrow create + get + list-for-run query
  surface Wave 1 needs. Stage dispatch (Oban worker) ships in Plan 08;
  the `Kiln.Stages.ContractRegistry` input-contract validation runs
  inside the worker's `perform/1` before any agent is invoked.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Stages.StageRun

  @doc """
  Insert a new stage_run row. Caller MUST supply `run_id`
  (FK with `on_delete: :restrict`); unique `(run_id, workflow_stage_id,
  attempt)` is enforced by the `stage_runs_run_stage_attempt_idx`.

  Returns `{:ok, %StageRun{}}` on successful insert (uuidv7 id
  hydrated via `read_after_writes: true`), `{:error,
  %Ecto.Changeset{}}` on validation failure (missing required fields,
  unknown enum value, FK violation, unique violation).
  """
  @spec create_stage_run(map()) :: {:ok, StageRun.t()} | {:error, Ecto.Changeset.t()}
  def create_stage_run(attrs) when is_map(attrs) do
    %StageRun{}
    |> StageRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fetch a stage_run by id, raising on not-found.
  """
  @spec get_stage_run!(Ecto.UUID.t()) :: StageRun.t()
  def get_stage_run!(id), do: Repo.get!(StageRun, id)

  @doc """
  List every stage_run belonging to a given run, ordered by
  `inserted_at` ascending. The Phase 7 run-detail view's dominant
  query; backed by the `stage_runs_run_id_idx` index.
  """
  @spec list_for_run(Ecto.UUID.t()) :: [StageRun.t()]
  def list_for_run(run_id) do
    from(sr in StageRun,
      where: sr.run_id == ^run_id,
      order_by: [asc: sr.inserted_at]
    )
    |> Repo.all()
  end
end
