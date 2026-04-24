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
  alias Kiln.Blockers.BlockedError
  alias Kiln.OperatorSetup
  alias Kiln.Runs.{Compare, Run}
  alias Kiln.Runs.RunDirector
  alias Kiln.Specs.Spec
  alias Kiln.Templates
  alias Kiln.Workflows
  alias Kiln.Workflows.CompiledGraph

  @type template_start_blocked :: %{
          reason: :factory_not_ready,
          blocker: OperatorSetup.checklist_item(),
          settings_target: String.t()
        }

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
  Inserts a **queued** run using the shipped workflow referenced by a built-in
  **`template_id`** (dispatcher path `priv/workflows/<workflow_id>.yaml`).

  The **`spec`** argument is reserved for future binding (intent enqueue);
  callers must still pass the spec that was promoted from the template.
  """
  @spec create_for_promoted_template(Spec.t(), String.t()) ::
          {:ok, Run.t()}
          | {:error, Ecto.Changeset.t() | :unknown_template | {:workflow_load_failed, term()}}
  def create_for_promoted_template(%Spec{} = spec, template_id)
      when is_binary(template_id) do
    _ = spec

    case Templates.fetch(template_id) do
      {:error, :unknown_template} = e ->
        e

      {:ok, entry} ->
        path = Templates.shipped_workflow_yaml_path(entry.workflow_id)

        case Workflows.load(path) do
          {:ok, %CompiledGraph{} = cg} ->
            attrs = %{
              workflow_id: cg.id,
              workflow_version: cg.version,
              workflow_checksum: Workflows.checksum(cg),
              correlation_id: Ecto.UUID.generate(),
              model_profile_snapshot: %{"profile" => cg.model_profile},
              caps_snapshot: caps_snapshot_from_compiled_graph(cg)
            }

            create(attrs)

          {:error, reason} ->
            {:error, {:workflow_load_failed, reason}}
        end
    end
  end

  @doc """
  Creates and starts a live run from a promoted template.

  Returns a typed blocked outcome when the operator setup is still missing a
  deterministic first blocker, and otherwise delegates final start authority to
  `RunDirector.start_run/1`.
  """
  @spec start_for_promoted_template(Spec.t(), String.t(), keyword()) ::
          {:ok, Run.t()}
          | {:blocked, template_start_blocked()}
          | {:error,
             Ecto.Changeset.t() | :unknown_template | :missing_api_key | {:workflow_load_failed, term()}}
  def start_for_promoted_template(%Spec{} = spec, template_id, opts \\ [])
      when is_binary(template_id) do
    case OperatorSetup.first_blocker() do
      nil ->
        do_start_for_promoted_template(spec, template_id, opts)

      blocker ->
        {:blocked, blocked_start(blocker, template_id, opts)}
    end
  end

  defp do_start_for_promoted_template(%Spec{} = spec, template_id, opts) do
    with {:ok, run} <- create_for_promoted_template(spec, template_id) do
      try do
        case RunDirector.start_run(run.id) do
          {:ok, started_run} ->
            {:ok, started_run}

          {:error, :factory_not_ready} ->
            _ = Repo.delete(run)

            blocker = OperatorSetup.first_blocker() || hd(OperatorSetup.summary().checklist)
            {:blocked, blocked_start(blocker, template_id, opts)}
        end
      rescue
        error in [BlockedError] ->
          case error do
            %BlockedError{reason: :missing_api_key} ->
              {:error, :missing_api_key}

            _ ->
              reraise error, __STACKTRACE__
          end
      end
    end
  end

  defp blocked_start(blocker, template_id, opts) do
    %{
      reason: :factory_not_ready,
      blocker: blocker,
      settings_target:
        OperatorSetup.settings_target(blocker,
          return_to: Keyword.get(opts, :return_to),
          template_id: template_id
        )
    }
  end

  defp caps_snapshot_from_compiled_graph(%CompiledGraph{caps: caps}) when is_map(caps) do
    Jason.decode!(Jason.encode!(caps))
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
  All runs (active + terminal) for the operator board (UI-01).

  Rows are ordered by the canonical `Run.states/0` progression, then by
  `updated_at` descending within each state so cards stay stable when
  PubSub refreshes arrive.
  """
  @spec list_for_board() :: [Run.t()]
  def list_for_board do
    all =
      from(r in Run, where: r.state in ^Run.states())
      |> Repo.all()

    grouped = Enum.group_by(all, & &1.state)

    Enum.flat_map(Run.states(), fn state ->
      grouped
      |> Map.get(state, [])
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
    end)
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
  Two-run compare read model for `/runs/compare` (PARA-02).

  `baseline_id` / `candidate_id` are `Ecto.UUID.t()` binaries or canonical
  UUID strings.
  """
  @spec compare_snapshot(binary(), binary()) :: Compare.Snapshot.t()
  def compare_snapshot(baseline_id, candidate_id)
      when is_binary(baseline_id) and is_binary(candidate_id) do
    Compare.snapshot(baseline_id, candidate_id)
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
