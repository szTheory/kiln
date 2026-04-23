defmodule Kiln.Runs.PostMortems do
  @moduledoc """
  Persistence for `run_postmortems` (Phase 19 materialization worker).
  """

  alias Kiln.Repo
  alias Kiln.Runs.PostMortem

  @doc false
  @spec get_by_run_id(Ecto.UUID.t()) :: PostMortem.t() | nil
  def get_by_run_id(run_id) when is_binary(run_id) do
    Repo.get(PostMortem, run_id)
  end

  @doc """
  Idempotent upsert keyed on `run_id`. Replaces snapshot columns on conflict.
  """
  @spec upsert_snapshot(Ecto.UUID.t(), map()) ::
          {:ok, PostMortem.t()} | {:error, Ecto.Changeset.t()}
  def upsert_snapshot(run_id, attrs) when is_binary(run_id) and is_map(attrs) do
    attrs = Map.put(attrs, :run_id, run_id)

    %PostMortem{}
    |> PostMortem.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:run_id, :inserted_at]},
      conflict_target: :run_id,
      returning: true
    )
  end
end
