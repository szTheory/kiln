defmodule Kiln.Runs.Compare do
  @moduledoc """
  Bounded read model for `/runs/compare` (PARA-02).

  `snapshot/2` accepts UUID **strings** or **16-byte** `Ecto.UUID.t()` binaries.
  Callers at the LiveView boundary validate first; string inputs are still
  cast defensively.

  ## Union ordering

  Union spine keys are **`workflow_stage_id`** strings (never index-only
  pairing). Ordering prefers `Kiln.Workflows.graph_for_run/1` on the
  **baseline** run when present; otherwise the **candidate** run. Keys
  absent from the graph list are appended in **alphabetical** order. When
  both runs are missing, keys sort alphabetically.

  ## Artifacts

  Only metadata columns from `artifacts` are selected. **No** CAS/blob
  reads — `Kiln.Artifacts.read!/1` is never invoked on this path.
  """

  import Ecto.Query

  alias Kiln.Artifacts.Artifact
  alias Kiln.Repo
  alias Kiln.Runs.Run
  alias Kiln.Stages.StageRun
  alias Kiln.Workflows

  defmodule Snapshot do
    @moduledoc false
    @type t :: %__MODULE__{
            baseline_run: Run.t() | nil,
            candidate_run: Run.t() | nil,
            union_stage_ids: [String.t()],
            rows: [map()],
            artifact_rows: [map()]
          }
    @enforce_keys [
      :baseline_run,
      :candidate_run,
      :union_stage_ids,
      :rows,
      :artifact_rows
    ]
    defstruct [
      :baseline_run,
      :candidate_run,
      :union_stage_ids,
      :rows,
      :artifact_rows
    ]
  end

  @spec snapshot(binary(), binary()) :: Snapshot.t()
  def snapshot(baseline_id, candidate_id)
      when is_binary(baseline_id) and is_binary(candidate_id) do
    baseline_uuid = normalize_uuid(baseline_id)
    candidate_uuid = normalize_uuid(candidate_id)

    baseline_run = if(baseline_uuid, do: Kiln.Runs.get(baseline_uuid), else: nil)
    candidate_run = if(candidate_uuid, do: Kiln.Runs.get(candidate_uuid), else: nil)

    baseline_latest =
      if(baseline_run, do: Workflows.latest_stage_runs_for(baseline_run.id), else: %{})

    candidate_latest =
      if(candidate_run, do: Workflows.latest_stage_runs_for(candidate_run.id), else: %{})

    union_keys =
      baseline_latest
      |> Map.keys()
      |> MapSet.new()
      |> MapSet.union(MapSet.new(Map.keys(candidate_latest)))
      |> MapSet.to_list()

    union_stage_ids = order_union_stage_ids(baseline_run, candidate_run, union_keys)

    rows =
      Enum.map(union_stage_ids, fn wid ->
        %{
          workflow_stage_id: wid,
          baseline_stage: Map.get(baseline_latest, wid),
          candidate_stage: Map.get(candidate_latest, wid)
        }
      end)

    artifact_rows =
      artifact_rows_for(baseline_run, candidate_run)

    %Snapshot{
      baseline_run: baseline_run,
      candidate_run: candidate_run,
      union_stage_ids: union_stage_ids,
      rows: rows,
      artifact_rows: artifact_rows
    }
  end

  defp normalize_uuid(<<_::128>> = raw), do: raw

  defp normalize_uuid(s) when is_binary(s) do
    case Ecto.UUID.cast(s) do
      {:ok, u} -> u
      :error -> nil
    end
  end

  defp order_union_stage_ids(nil, nil, keys), do: Enum.sort(keys)

  defp order_union_stage_ids(%Run{} = baseline, _candidate, keys) do
    order_with_graph(keys, Workflows.graph_for_run(baseline))
  end

  defp order_union_stage_ids(nil, %Run{} = candidate, keys) do
    order_with_graph(keys, Workflows.graph_for_run(candidate))
  end

  defp order_with_graph(keys, graph_ids) do
    key_set = MapSet.new(keys)
    graph_in = Enum.filter(graph_ids, &MapSet.member?(key_set, &1))

    rest =
      keys
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(graph_in))
      |> MapSet.to_list()
      |> Enum.sort()

    graph_in ++ rest
  end

  defp artifact_rows_for(baseline_run, candidate_run) do
    run_ids =
      [baseline_run && baseline_run.id, candidate_run && candidate_run.id]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if run_ids == [] do
      []
    else
      from(a in Artifact,
        join: sr in StageRun,
        on: sr.id == a.stage_run_id,
        where: a.run_id in ^run_ids,
        select: %{
          id: a.id,
          name: a.name,
          sha256: a.sha256,
          size_bytes: a.size_bytes,
          stage_run_id: a.stage_run_id,
          run_id: a.run_id,
          content_type: a.content_type,
          workflow_stage_id: sr.workflow_stage_id
        }
      )
      |> Repo.all()
      |> Enum.group_by(fn a -> "#{a.workflow_stage_id}::#{a.name}" end)
      |> Enum.map(fn {logical_key, metas} ->
        b_meta = Enum.find(metas, &(baseline_run && &1.run_id == baseline_run.id))
        c_meta = Enum.find(metas, &(candidate_run && &1.run_id == candidate_run.id))

        wid =
          cond do
            b_meta -> b_meta.workflow_stage_id
            c_meta -> c_meta.workflow_stage_id
            true -> nil
          end

        %{
          logical_key: logical_key,
          workflow_stage_id: wid,
          baseline_meta: b_meta,
          candidate_meta: c_meta,
          equality: digest_equality(b_meta, c_meta)
        }
      end)
      |> Enum.sort_by(& &1.logical_key)
    end
  end

  defp digest_equality(nil, nil), do: :unknown
  defp digest_equality(%{}, nil), do: :baseline_only
  defp digest_equality(nil, %{}), do: :candidate_only

  defp digest_equality(%{sha256: bs}, %{sha256: cs})
       when is_binary(bs) and is_binary(cs) do
    if bs == cs, do: :same, else: :different
  end

  defp digest_equality(_, _), do: :unknown
end
