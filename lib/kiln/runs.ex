defmodule Kiln.Runs do
  @moduledoc """
  Public API for the runs context. Owns the `runs` table (Plan 02-02) and,
  via `Kiln.Runs.Transitions` (Plan 06), the state-machine transitions.

  Every public function is a narrow, read-first query plus the single
  insert path (`create/1`); state mutation is reserved for
  `Kiln.Runs.Transitions` (Plan 06). `list_active/0` + `workflow_checksum/1`
  are consumed by `Kiln.Runs.RunDirector` (Plan 07) during boot-time
  rehydration (D-92) and the workflow-integrity assertion on resume
  (D-94).

  Run state drift between app (`Ecto.Enum`) and DB (CHECK constraint)
  surfaces here as `check_constraint/2` errors on the changeset — every
  consumer of `create/1` gets a clean `{:error, %Ecto.Changeset{}}` on
  invalid state instead of a raw `Postgrex.Error`.
  """

  import Ecto.Query
  import Ecto.Changeset, only: [change: 2]

  alias Kiln.Repo
  alias Kiln.Runs.Run

  @doc """
  Insert a new run. The `state` field defaults to `:queued`; callers
  MUST NOT bypass the transition machinery by passing a post-queued
  state to `create/1` — use `Kiln.Runs.Transitions.transition/3`
  (Plan 06) instead.

  Returns `{:ok, %Run{}}` on successful insert (uuidv7 id hydrated via
  `read_after_writes: true`), `{:error, %Ecto.Changeset{}}` on
  validation failure (missing required fields, malformed
  workflow_checksum, unknown state).
  """
  @spec create(map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) when is_map(attrs) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fetch a run by id, raising on not-found. Use `get/1` when the absence
  is a valid outcome; `get!/1` for paths where a missing row is an
  invariant violation.
  """
  @spec get!(Ecto.UUID.t()) :: Run.t()
  def get!(id), do: Repo.get!(Run, id)

  @doc """
  Fetch a run by id, returning `nil` on not-found.
  """
  @spec get(Ecto.UUID.t()) :: Run.t() | nil
  def get(id), do: Repo.get(Run, id)

  @doc """
  Returns every run whose state is NOT terminal (i.e. in the six
  active states `:queued`, `:planning`, `:coding`, `:testing`,
  `:verifying`, `:blocked`). Drives `Kiln.Runs.RunDirector`'s
  boot-time rehydration scan (D-92) and the 30-second defensive
  periodic scan. Ordered by `inserted_at` ascending so older runs
  resume first.

  The query is backed by the `runs_active_state_idx` partial index —
  Postgres uses it in preference to the full state index when the
  WHERE clause matches the partial predicate.
  """
  @spec list_active() :: [Run.t()]
  def list_active do
    active = Run.active_states()

    from(r in Run,
      where: r.state in ^active,
      order_by: [asc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Fetch just the `workflow_checksum` for a run. Called by
  `Kiln.Runs.RunDirector` (Plan 07) on rehydration to assert D-94: the
  current on-disk workflow YAML's compiled checksum must match the
  value recorded at run start, else the run is escalated with reason
  `:workflow_changed`.

  Returns `{:ok, <64-char hex>}` or `{:error, :not_found}`.
  """
  @spec workflow_checksum(Ecto.UUID.t()) :: {:ok, String.t()} | {:error, :not_found}
  def workflow_checksum(run_id) do
    case Repo.one(from(r in Run, where: r.id == ^run_id, select: r.workflow_checksum)) do
      nil -> {:error, :not_found}
      sha -> {:ok, sha}
    end
  end

  @doc """
  Merges `fragment` into `runs.github_delivery_snapshot` (internal caller — Promoter).

  Snapshot keys are string maps suitable for JSONB (`"pr"`, `"checks"`,
  `"predicate_pass"`, `"updated_at"`).
  """
  @spec promote_github_snapshot(Ecto.UUID.t(), map()) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def promote_github_snapshot(run_id, fragment) when is_map(fragment) do
    case Repo.get(Run, run_id) do
      nil ->
        {:error, :not_found}

      run ->
        merged = Map.merge(run.github_delivery_snapshot || %{}, fragment)

        run
        |> change(github_delivery_snapshot: merged)
        |> Repo.update()
    end
  end
end
