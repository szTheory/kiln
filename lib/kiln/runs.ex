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
  alias Kiln.Secrets
  alias Kiln.Specs.{Spec, SpecRevision}
  alias Kiln.Templates
  alias Kiln.Workflows
  alias Kiln.Workflows.CompiledGraph

  @type template_start_blocked :: %{
          reason: :factory_not_ready,
          blocker: OperatorSetup.checklist_item(),
          settings_target: String.t()
        }

  @type promoted_attached_request :: %{
          required(:spec) => Spec.t(),
          required(:revision) => SpecRevision.t()
        }

  @attached_request_workflow_id "elixir_phoenix_feature"

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
  Inserts a queued run for one promoted attached request, preserving explicit
  links back to the attached repo, spec, and promoted revision.
  """
  @spec create_for_attached_request(promoted_attached_request(), Ecto.UUID.t()) ::
          {:ok, Run.t()}
          | {:error,
             Ecto.Changeset.t() | :invalid_attached_request | {:workflow_load_failed, term()}}
  def create_for_attached_request(
        %{spec: %Spec{} = spec, revision: %SpecRevision{} = revision},
        attached_repo_id
      )
      when is_binary(attached_repo_id) do
    with :ok <- validate_attached_request(spec, revision, attached_repo_id),
         {:ok, %CompiledGraph{} = cg} <- load_attached_request_workflow(revision) do
      %{
        attached_repo_id: attached_repo_id,
        spec_id: spec.id,
        spec_revision_id: revision.id,
        workflow_id: cg.id,
        workflow_version: cg.version,
        workflow_checksum: Workflows.checksum(cg),
        correlation_id: Ecto.UUID.generate(),
        model_profile_snapshot: %{"profile" => cg.model_profile},
        caps_snapshot: caps_snapshot_from_compiled_graph(cg)
      }
      |> create()
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
             Ecto.Changeset.t()
             | :unknown_template
             | :missing_api_key
             | {:workflow_load_failed, term()}}
  def start_for_promoted_template(%Spec{} = spec, template_id, opts \\ [])
      when is_binary(template_id) do
    case OperatorSetup.first_blocker() do
      nil ->
        do_start_for_promoted_template(spec, template_id, opts)

      blocker ->
        {:blocked, blocked_start(blocker, template_id, opts)}
    end
  end

  @doc """
  Creates and starts a live run from one promoted attached request.

  Returns the same typed blocked outcome as template starts when operator setup
  is missing, while keeping attach identity on the run row.
  """
  @spec preflight_attached_request_start() ::
          :ok | {:blocked, template_start_blocked()} | {:error, :missing_api_key}
  def preflight_attached_request_start do
    case OperatorSetup.first_blocker() do
      nil ->
        case attached_request_missing_provider_keys() do
          [] ->
            :ok

          _missing ->
            {:error, :missing_api_key}
        end

      blocker ->
        {:blocked, blocked_start(blocker, nil, [])}
    end
  end

  @spec start_for_attached_request(promoted_attached_request(), Ecto.UUID.t(), keyword()) ::
          {:ok, Run.t()}
          | {:blocked, template_start_blocked()}
          | {:error,
             Ecto.Changeset.t()
             | :invalid_attached_request
             | :missing_api_key
             | {:workflow_load_failed, term()}}
  def start_for_attached_request(
        %{spec: %Spec{}, revision: %SpecRevision{}} = promoted_request,
        attached_repo_id,
        opts \\ []
      )
      when is_binary(attached_repo_id) do
    case OperatorSetup.first_blocker() do
      nil ->
        do_start_for_attached_request(promoted_request, attached_repo_id, opts)

      blocker ->
        {:blocked, blocked_start(blocker, nil, opts)}
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
              _ = Repo.delete(run)
              {:error, :missing_api_key}

            _ ->
              reraise error, __STACKTRACE__
          end
      end
    end
  end

  defp do_start_for_attached_request(promoted_request, attached_repo_id, opts) do
    with {:ok, run} <- create_for_attached_request(promoted_request, attached_repo_id) do
      try do
        case RunDirector.start_run(run.id) do
          {:ok, started_run} ->
            {:ok, started_run}

          {:error, :factory_not_ready} ->
            _ = Repo.delete(run)

            blocker = OperatorSetup.first_blocker() || hd(OperatorSetup.summary().checklist)
            {:blocked, blocked_start(blocker, nil, opts)}
        end
      rescue
        error in [BlockedError] ->
          case error do
            %BlockedError{reason: :missing_api_key} ->
              _ = Repo.delete(run)
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

  defp validate_attached_request(%Spec{id: spec_id}, %SpecRevision{} = revision, attached_repo_id) do
    cond do
      is_nil(spec_id) or is_nil(revision.id) ->
        {:error, :invalid_attached_request}

      revision.spec_id != spec_id ->
        {:error, :invalid_attached_request}

      revision.attached_repo_id != attached_repo_id ->
        {:error, :invalid_attached_request}

      true ->
        :ok
    end
  end

  defp load_attached_request_workflow(%SpecRevision{request_kind: _request_kind}) do
    @attached_request_workflow_id
    |> Templates.shipped_workflow_yaml_path()
    |> Workflows.load()
    |> case do
      {:ok, %CompiledGraph{} = cg} -> {:ok, cg}
      {:error, reason} -> {:error, {:workflow_load_failed, reason}}
    end
  end

  defp caps_snapshot_from_compiled_graph(%CompiledGraph{caps: caps}) when is_map(caps) do
    Jason.decode!(Jason.encode!(caps))
  end

  defp attached_request_missing_provider_keys do
    case load_attached_request_workflow(%SpecRevision{request_kind: :feature}) do
      {:ok, %CompiledGraph{} = cg} ->
        cg.model_profile
        |> required_provider_keys_for_profile()
        |> Enum.reject(&Secrets.present?/1)
        |> Enum.uniq()

      {:error, _reason} ->
        []
    end
  end

  defp required_provider_keys_for_profile(profile) when is_binary(profile) do
    roles =
      case Enum.find(Kiln.ModelRegistry.all_presets(), &(Atom.to_string(&1) == profile)) do
        nil -> %{}
        preset -> Kiln.ModelRegistry.resolve(preset)
      end

    roles
    |> Map.values()
    |> Enum.map(&model_id_from_role_spec/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&provider_key_for_model/1)
  end

  defp model_id_from_role_spec(model) when is_binary(model), do: model
  defp model_id_from_role_spec(%{model: model}) when is_binary(model), do: model
  defp model_id_from_role_spec(%{"model" => model}) when is_binary(model), do: model
  defp model_id_from_role_spec(_), do: nil

  defp provider_key_for_model("claude-" <> _), do: :anthropic_api_key
  defp provider_key_for_model("gpt-" <> _), do: :openai_api_key
  defp provider_key_for_model("gemini-" <> _), do: :google_api_key

  defp provider_key_for_model(model) when is_binary(model) do
    cond do
      String.contains?(model, "sonnet") or String.contains?(model, "haiku") or
          String.contains?(model, "opus") ->
        :anthropic_api_key

      String.contains?(model, "llama") or String.contains?(model, "ollama") ->
        :ollama_host

      true ->
        :anthropic_api_key
    end
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

  @spec get_for_attached_repo(Ecto.UUID.t(), Ecto.UUID.t()) :: Run.t() | nil
  def get_for_attached_repo(attached_repo_id, run_id)
      when is_binary(attached_repo_id) and is_binary(run_id) do
    from(r in Run,
      where: r.id == ^run_id and r.attached_repo_id == ^attached_repo_id,
      left_join: revision in SpecRevision,
      on: revision.id == r.spec_revision_id,
      left_join: spec in Spec,
      on: spec.id == r.spec_id,
      preload: [spec_revision: revision, spec: spec]
    )
    |> Repo.one()
  end

  @spec list_recent_for_attached_repo(Ecto.UUID.t(), keyword()) :: [Run.t()]
  def list_recent_for_attached_repo(attached_repo_id, opts \\ [])
      when is_binary(attached_repo_id) do
    limit = Keyword.get(opts, :limit, 5)

    from(r in Run,
      where: r.attached_repo_id == ^attached_repo_id,
      order_by: [desc: r.inserted_at],
      left_join: revision in SpecRevision,
      on: revision.id == r.spec_revision_id,
      left_join: spec in Spec,
      on: spec.id == r.spec_id,
      preload: [spec_revision: revision, spec: spec],
      limit: ^limit
    )
    |> Repo.all()
  end

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
