defmodule Kiln.Workflows do
  @moduledoc """
  Public API for the Workflows bounded context.

  Wraps the loader + compiler + checksum so callers don't reach into
  `Kiln.Workflows.Loader`, `Kiln.Workflows.Compiler`, or
  `Kiln.Workflows.Graph` directly:

    * `load/1` — path → `{:ok, %CompiledGraph{}}` or typed error
    * `load!/1` — path → `%CompiledGraph{}`; raises on error
    * `compile/1` — JSV-validated map → `{:ok, %CompiledGraph{}}` or
      typed error; exposed for unit tests that bypass the YAML layer
    * `checksum/1` — `%CompiledGraph{}` → sha256 hex (driven by D-94
      rehydration integrity assertion in Plan 02-07)

  See the module docs on `Kiln.Workflows.Loader` + `Kiln.Workflows.Compiler`
  for error-shape taxonomy and the 6 D-62 validators.
  """

  import Ecto.Query

  alias Kiln.Repo
  alias Kiln.Runs.Run
  alias Kiln.Stages
  alias Kiln.Stages.StageRun
  alias Kiln.Workflows.{CompiledGraph, Compiler, Loader, WorkflowDefinitionSnapshot}

  require Logger

  @spec load(Path.t()) ::
          {:ok, CompiledGraph.t()}
          | {:error, term()}
  def load(path) do
    case Loader.load(path) do
      {:ok, cg} = ok ->
        _ = persist_snapshot_from_disk(path, cg)
        ok

      other ->
        other
    end
  end

  @spec load!(Path.t()) :: CompiledGraph.t()
  def load!(path) do
    case load(path) do
      {:ok, cg} ->
        cg

      {:error, reason} ->
        raise "Kiln.Workflows.load!/1 failed for #{inspect(path)}: #{inspect(reason)}"
    end
  end

  @spec compile(map()) ::
          {:ok, CompiledGraph.t()}
          | {:error, term()}
  defdelegate compile(raw), to: Compiler

  @doc """
  Returns the compiled graph's sha256 hex checksum (D-94). The
  checksum is computed by `Kiln.Workflows.Compiler.compile/1` over the
  shape-significant fields via `:erlang.term_to_binary(_, :deterministic)`
  + `:crypto.hash(:sha256, _)`.
  """
  @spec checksum(CompiledGraph.t()) :: String.t()
  def checksum(%CompiledGraph{checksum: sha}) when is_binary(sha), do: sha

  @doc """
  Returns workflow stage ids for graph rendering on the run detail page.

  When `priv/workflows/<workflow_id>.yaml` loads and its compiled checksum
  matches `run.workflow_checksum`, returns compiler order from
  `%CompiledGraph{}.stages`. Otherwise falls back to the distinct
  `workflow_stage_id` values from persisted `stage_runs`, preserving first
  occurrence order by `inserted_at` (UI-02 v1 linear graph).
  """
  @spec graph_for_run(Run.t()) :: [String.t()]
  def graph_for_run(%Run{} = run) do
    path = Application.app_dir(:kiln, "priv/workflows/#{run.workflow_id}.yaml")

    case load(path) do
      {:ok, %CompiledGraph{checksum: sha, stages: stages}} when sha == run.workflow_checksum ->
        Enum.map(stages, & &1.id)

      _ ->
        run.id
        |> Stages.list_for_run()
        |> Enum.map(& &1.workflow_stage_id)
        |> Enum.uniq()
    end
  end

  @doc """
  Fetch the latest `stage_run` row per `workflow_stage_id` for a run.
  """
  @spec latest_stage_runs_for(Ecto.UUID.t()) :: %{String.t() => StageRun.t()}
  def latest_stage_runs_for(run_id) do
    run_id
    |> Stages.list_for_run()
    |> Enum.group_by(& &1.workflow_stage_id)
    |> Map.new(fn {wid, rows} -> {wid, Enum.max_by(rows, & &1.attempt)} end)
  end

  @doc """
  Persist a workflow YAML snapshot after a successful compile (UI-03).

  When `byte_size(yaml) > 262_144`, `yaml_body` is stored as `NULL` and
  `truncated` is set `true` while checksum + version remain authoritative.
  """
  @spec record_snapshot(%{
          required(:workflow_id) => String.t(),
          required(:version) => pos_integer(),
          required(:compiled_checksum) => String.t(),
          required(:yaml) => String.t()
        }) :: {:ok, WorkflowDefinitionSnapshot.t()} | {:error, Ecto.Changeset.t()}
  def record_snapshot(%{workflow_id: wid, version: v, compiled_checksum: sha, yaml: yaml}) do
    over? = byte_size(yaml) > 262_144

    %WorkflowDefinitionSnapshot{}
    |> WorkflowDefinitionSnapshot.changeset(%{
      workflow_id: wid,
      version: v,
      compiled_checksum: sha,
      yaml_body: if(over?, do: nil, else: yaml),
      truncated: over?
    })
    |> Repo.insert()
  end

  @doc """
  Recent snapshots across all workflows (newest first), capped for index UI.
  """
  @spec list_recent_snapshots(keyword()) :: [WorkflowDefinitionSnapshot.t()]
  def list_recent_snapshots(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(s in WorkflowDefinitionSnapshot,
      order_by: [desc: s.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Snapshots for a single `workflow_id` (newest first).
  """
  @spec list_snapshots_for(String.t(), keyword()) :: [WorkflowDefinitionSnapshot.t()]
  def list_snapshots_for(workflow_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    from(s in WorkflowDefinitionSnapshot,
      where: s.workflow_id == ^workflow_id,
      order_by: [desc: s.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp persist_snapshot_from_disk(path, %CompiledGraph{} = cg) do
    # Loader unit tests invoke `Kiln.Workflows.load/1` without a SQL Sandbox
    # checkout — skip DB writes there (snapshots are covered by LiveView tests).
    if Application.get_env(:kiln, :skip_workflow_snapshot_persist, false) do
      :ok
    else
      do_persist_snapshot_from_disk(path, cg)
    end
  end

  defp do_persist_snapshot_from_disk(path, %CompiledGraph{} = cg) do
    with {:ok, yaml} <- File.read(path),
         {:ok, _} <-
           record_snapshot(%{
             workflow_id: cg.id,
             version: cg.version,
             compiled_checksum: cg.checksum,
             yaml: yaml
           }) do
      :ok
    else
      {:error, %Ecto.Changeset{} = cs} ->
        Logger.warning("workflow snapshot insert failed: #{inspect(cs.errors)}")
        :error

      {:error, reason} ->
        Logger.warning("workflow snapshot skipped: #{inspect(reason)}")
        :error

      other ->
        Logger.warning("workflow snapshot unexpected: #{inspect(other)}")
        :error
    end
  end
end
